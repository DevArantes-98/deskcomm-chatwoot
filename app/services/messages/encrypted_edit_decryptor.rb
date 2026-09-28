require 'openssl'
require 'base64'

# WhatsApp no longer sends the edit of a customer's message in clear text: it arrives as a
# `secretEncryptedMessage` (type MESSAGE_EDIT) encrypted with the secret of the original message.
# Evolution API (Baileys) does not decrypt it yet (WhiskeySockets/Baileys#2743), so its Chatwoot
# integration never learns the new text. This mirrors Baileys' `decryptMessageEdit`.
class Messages::EncryptedEditDecryptor
  LABEL = 'Message Edit'.freeze
  SECRET_LENGTH = 32
  IV_LENGTH = 12
  TAG_LENGTH = 16
  PROTOCOL_MESSAGE_EDIT = 14

  # Field numbers of WhatsApp's protobuf schema (WAProto).
  MESSAGE_PROTOCOL = 12
  PROTOCOL_KEY = 1
  PROTOCOL_TYPE = 2
  PROTOCOL_EDITED_MESSAGE = 14
  PROTOCOL_TIMESTAMP_MS = 15
  KEY_ID = 3
  # Path to the text of each kind of message: conversation, extended text, image / video / document caption.
  TEXT_PATHS = [[1], [6, 1], [3, 3], [9, 7], [7, 20]].freeze

  class DecodeError < StandardError; end

  pattr_initialize [:enc_payload!, :enc_iv!, :message_secret!, :original_id!, :sender_jids!, :editor_jids!]

  # Accepts what Evolution's JSON contains for a `bytes` field: base64 text, a Node Buffer
  # (`{type: 'Buffer', data: [...]}`), a plain array, or a Uint8Array serialised as `{'0' => 12, '1' => 3, ...}`.
  def self.to_bytes(value)
    case value
    when String then Base64.decode64(value)
    when Array then value.pack('C*')
    when Hash then hash_to_bytes(value.with_indifferent_access)
    else ''.b
    end
  end

  def self.hash_to_bytes(hash)
    return hash[:data].pack('C*') if hash[:data].is_a?(Array)

    hash.sort_by { |index, _| index.to_i }.map { |_, byte| byte.to_i }.pack('C*')
  end

  def perform
    protocol = field_value(Protobuf.read_fields(decrypt), MESSAGE_PROTOCOL)
    raise EvolutionGo::Refused, :invalid_edit if protocol.blank?

    fields = Protobuf.read_fields(protocol)
    validate_protocol!(fields)
    text = text_of(field_value(fields, PROTOCOL_EDITED_MESSAGE))
    raise EvolutionGo::Refused, :unsupported_content if text.blank?

    { content: text, edited_at: edited_at(fields) }
  rescue DecodeError
    raise EvolutionGo::Refused, :invalid_edit
  end

  private

  def secret
    @secret ||= self.class.to_bytes(message_secret)
  end

  def payload
    @payload ||= self.class.to_bytes(enc_payload)
  end

  def iv
    @iv ||= self.class.to_bytes(enc_iv)
  end

  def decrypt
    raise EvolutionGo::Refused, :missing_secret unless secret.bytesize == SECRET_LENGTH
    raise EvolutionGo::Refused, :invalid_edit unless iv.bytesize == IV_LENGTH && payload.bytesize > TAG_LENGTH

    extracted_key = OpenSSL::HMAC.digest('SHA256', "\x00".b * SECRET_LENGTH, secret)
    sender_jids.product(editor_jids).each do |sender, editor|
      plaintext = decrypt_with(OpenSSL::HMAC.digest('SHA256', extracted_key, info(sender, editor)))
      return plaintext if plaintext
    end
    raise EvolutionGo::Refused, :decrypt_failed
  end

  # The JIDs are unknown to us in the exact form WhatsApp used (phone number or LID), so every
  # candidate is tried: the GCM authentication tag only validates for the right one.
  def info(sender, editor)
    [original_id, sender, editor, LABEL].join.b + "\x01".b
  end

  def decrypt_with(key)
    cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
    cipher.key = key
    cipher.iv = iv
    cipher.auth_tag = payload.byteslice(-TAG_LENGTH, TAG_LENGTH)
    cipher.auth_data = ''
    cipher.update(payload.byteslice(0, payload.bytesize - TAG_LENGTH)) + cipher.final
  rescue OpenSSL::Cipher::CipherError
    nil
  end

  def validate_protocol!(fields)
    raise EvolutionGo::Refused, :invalid_edit unless field_value(fields, PROTOCOL_TYPE) == PROTOCOL_MESSAGE_EDIT

    key = field_value(fields, PROTOCOL_KEY)
    target_id = key && field_value(Protobuf.read_fields(key), KEY_ID)
    raise EvolutionGo::Refused, :invalid_edit if target_id.present? && target_id.force_encoding(Encoding::UTF_8) != original_id
  end

  def text_of(message)
    return if message.blank?

    TEXT_PATHS.each do |path|
      text = path.reduce(message) { |bytes, number| bytes && field_value(Protobuf.read_fields(bytes), number) }
      return text.dup.force_encoding(Encoding::UTF_8).scrub if text.present?
    end
    nil
  end

  def edited_at(fields)
    milliseconds = field_value(fields, PROTOCOL_TIMESTAMP_MS)
    Time.zone.at(milliseconds / 1000) if milliseconds.is_a?(Integer) && milliseconds.positive?
  end

  def field_value(fields, number)
    fields.find { |field_number, _| field_number == number }&.last
  end

  # Minimal protobuf reader: enough to walk WhatsApp's messages without depending on their schema gem.
  module Protobuf
    module_function

    def read_fields(bytes)
      fields = []
      position = 0
      while position < bytes.bytesize
        tag, position = read_varint(bytes, position)
        value, position = read_value(bytes, tag & 7, position)
        fields << [tag >> 3, value]
      end
      fields
    end

    def read_value(bytes, wire_type, position)
      case wire_type
      when 0 then read_varint(bytes, position)
      when 1 then take(bytes, position, 8)
      when 2
        length, position = read_varint(bytes, position)
        take(bytes, position, length)
      when 5 then take(bytes, position, 4)
      else raise DecodeError, "unsupported wire type #{wire_type}"
      end
    end

    def read_varint(bytes, position)
      result = 0
      shift = 0
      loop do
        raise DecodeError, 'truncated varint' if position >= bytes.bytesize || shift > 63

        byte = bytes.getbyte(position)
        position += 1
        result |= (byte & 0x7f) << shift
        return [result, position] if byte < 0x80

        shift += 7
      end
    end

    def take(bytes, position, length)
      raise DecodeError, 'truncated field' if position + length > bytes.bytesize

      [bytes.byteslice(position, length), position + length]
    end
  end
end
