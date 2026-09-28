# Builds the `secretEncryptedMessage` WhatsApp sends when a customer edits a message, the way the phone
# does, so specs exercise the real decryption instead of a stubbed result.
module WhatsappEncryptedEditHelper
  def protobuf_varint(number)
    bytes = []
    loop do
      byte = number & 0x7f
      number >>= 7
      bytes << (number.positive? ? byte | 0x80 : byte)
      break if number.zero?
    end
    bytes.pack('C*')
  end

  def protobuf_field(number, value)
    return protobuf_varint(number << 3) + protobuf_varint(value) if value.is_a?(Integer)

    bytes = value.to_s.b
    protobuf_varint((number << 3) | 2) + protobuf_varint(bytes.bytesize) + bytes
  end

  def whatsapp_text_message(text)
    protobuf_field(1, text)
  end

  # Message { protocolMessage { key { id }, type: MESSAGE_EDIT, editedMessage, timestampMs } }
  def whatsapp_edit_plaintext(original_id:, edited_message:, type: 14, timestamp_ms: 1_800_000_000_000)
    protocol = protobuf_field(1, protobuf_field(3, original_id)) + protobuf_field(2, type) +
               protobuf_field(14, edited_message) + protobuf_field(15, timestamp_ms)
    protobuf_field(12, protocol)
  end

  # A Uint8Array serialised by JSON.stringify, as Evolution's webhook and database keep it.
  def uint8_array_json(bytes)
    bytes.b.bytes.each_with_index.to_h { |byte, index| [index.to_s, byte] }
  end

  # `jid` is how WhatsApp addressed the customer when it encrypted the edit: the customer is both the
  # sender of the original message and the editor.
  def encrypt_whatsapp_edit(plaintext:, secret:, original_id:, jid:)
    iv = SecureRandom.random_bytes(12)
    extracted_key = OpenSSL::HMAC.digest('SHA256', "\x00".b * 32, secret)
    key = OpenSSL::HMAC.digest('SHA256', extracted_key, [original_id, jid, jid, 'Message Edit'].join.b + "\x01".b)
    cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_data = ''
    { 'encPayload' => uint8_array_json(cipher.update(plaintext) + cipher.final + cipher.auth_tag),
      'encIv' => uint8_array_json(iv), 'secretEncType' => 2 }
  end

  # What a bridge has at hand for one edit: Evolution's `messages.upsert` data for the encrypted edit and the
  # stored record of the original message (which keeps its secret).
  def whatsapp_edit_payloads(secret:, original_id:, new_text:, remote_jid:, **options)
    envelope = encrypt_whatsapp_edit(
      plaintext: whatsapp_edit_plaintext(original_id: original_id, edited_message: whatsapp_text_message(new_text)),
      secret: secret, original_id: original_id, jid: options.fetch(:encrypted_for, remote_jid)
    )
    key = { 'remoteJid' => remote_jid, 'remoteJidAlt' => options[:remote_jid_alt], 'fromMe' => false }.compact
    {
      edit: { 'key' => key.merge('id' => 'EDIT-EVENT-ID'), 'messageType' => 'secretEncryptedMessage',
              'message' => { 'secretEncryptedMessage' => envelope.merge('targetMessageKey' => key.merge('id' => original_id)) } },
      original: { 'key' => key.merge('id' => original_id), 'messageType' => 'conversation',
                  'message' => { 'conversation' => 'old text', 'messageContextInfo' => { 'messageSecret' => uint8_array_json(secret) } } }
    }
  end
end
