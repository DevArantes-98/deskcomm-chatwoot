require 'rails_helper'

describe Messages::EncryptedEditDecryptor do
  include WhatsappEncryptedEditHelper

  let(:secret) { SecureRandom.random_bytes(32) }
  let(:original_id) { '3EB0C767D0F26E3F1B2A' }
  let(:customer) { '5511999990000@s.whatsapp.net' }
  let(:lid) { '184455901728990@lid' }
  let(:edited_message) { whatsapp_text_message('Reuniao as 11h') }
  let(:plaintext) { whatsapp_edit_plaintext(original_id: original_id, edited_message: edited_message) }
  let(:envelope) do
    encrypt_whatsapp_edit(plaintext: plaintext, secret: secret, original_id: original_id, jid: customer)
  end

  let(:attributes) do
    { enc_payload: envelope['encPayload'], enc_iv: envelope['encIv'], message_secret: uint8_array_json(secret), original_id: original_id,
      sender_jids: [customer], editor_jids: [customer] }
  end

  def decrypt(**overrides)
    described_class.new(**attributes, **overrides).perform
  end

  def refusal_reason
    yield
  rescue EvolutionGo::Refused => e
    e.reason
  end

  it 'returns the new text and the time of the edit' do
    expect(decrypt).to eq(content: 'Reuniao as 11h', edited_at: Time.zone.at(1_800_000_000))
  end

  it 'finds the right pair of JIDs among the candidates, phone number or LID' do
    envelope = encrypt_whatsapp_edit(plaintext: plaintext, secret: secret, original_id: original_id, jid: lid)

    result = decrypt(enc_payload: envelope['encPayload'], enc_iv: envelope['encIv'], sender_jids: [customer, lid], editor_jids: [customer, lid])

    expect(result[:content]).to eq('Reuniao as 11h')
  end

  it 'keeps accents and emojis' do
    edited_message = whatsapp_text_message('Reunião às 11h ✅')
    envelope = encrypt_whatsapp_edit(plaintext: whatsapp_edit_plaintext(original_id: original_id, edited_message: edited_message),
                                     secret: secret, original_id: original_id, jid: customer)

    expect(decrypt(enc_payload: envelope['encPayload'], enc_iv: envelope['encIv'])[:content]).to eq('Reunião às 11h ✅')
  end

  describe 'reading the bytes from JSON' do
    let(:payload_bytes) { described_class.to_bytes(envelope['encPayload']) }

    it 'accepts base64, a Node Buffer, a plain array and an index keyed object' do
      shapes = [Base64.strict_encode64(payload_bytes), { 'type' => 'Buffer', 'data' => payload_bytes.bytes }, payload_bytes.bytes,
                envelope['encPayload']]

      shapes.each do |shape|
        expect(decrypt(enc_payload: shape)[:content]).to eq('Reuniao as 11h')
      end
    end

    it 'accepts the message secret as base64 too' do
      expect(decrypt(message_secret: Base64.strict_encode64(secret))[:content]).to eq('Reuniao as 11h')
    end
  end

  describe 'the text of other kinds of message' do
    {
      'an extended text' => ->(helper, text) { helper.protobuf_field(6, helper.protobuf_field(1, text)) },
      'an image caption' => ->(helper, text) { helper.protobuf_field(3, helper.protobuf_field(3, text)) },
      'a video caption' => ->(helper, text) { helper.protobuf_field(9, helper.protobuf_field(7, text)) },
      'a document caption' => ->(helper, text) { helper.protobuf_field(7, helper.protobuf_field(20, text)) }
    }.each do |name, build|
      it "reads #{name}" do
        envelope = encrypt_whatsapp_edit(
          plaintext: whatsapp_edit_plaintext(original_id: original_id, edited_message: build.call(self, 'Legenda nova')),
          secret: secret, original_id: original_id, jid: customer
        )

        expect(decrypt(enc_payload: envelope['encPayload'], enc_iv: envelope['encIv'])[:content]).to eq('Legenda nova')
      end
    end

    it 'refuses an edit without any text' do
      envelope = encrypt_whatsapp_edit(
        plaintext: whatsapp_edit_plaintext(original_id: original_id, edited_message: protobuf_field(2, 'nothing we read')),
        secret: secret, original_id: original_id, jid: customer
      )

      expect(refusal_reason { decrypt(enc_payload: envelope['encPayload'], enc_iv: envelope['encIv']) }).to eq(:unsupported_content)
    end
  end

  describe 'refusing what cannot be trusted' do
    it 'refuses when none of the JIDs match, or the secret is wrong' do
      expect(refusal_reason { decrypt(sender_jids: [lid], editor_jids: [lid]) }).to eq(:decrypt_failed)
      expect(refusal_reason { decrypt(message_secret: uint8_array_json(SecureRandom.random_bytes(32))) }).to eq(:decrypt_failed)
    end

    it 'refuses a payload that was tampered with' do
      tampered = described_class.to_bytes(envelope['encPayload'])
      tampered.setbyte(0, tampered.getbyte(0) ^ 1)

      expect(refusal_reason { decrypt(enc_payload: tampered.bytes) }).to eq(:decrypt_failed)
    end

    it 'refuses a missing or short secret and a malformed envelope' do
      expect(refusal_reason { decrypt(message_secret: nil) }).to eq(:missing_secret)
      expect(refusal_reason { decrypt(message_secret: 'c2hvcnQ=') }).to eq(:missing_secret)
      expect(refusal_reason { decrypt(enc_iv: [1, 2, 3]) }).to eq(:invalid_edit)
      expect(refusal_reason { decrypt(enc_payload: []) }).to eq(:invalid_edit)
    end

    it 'refuses a message that is not an edit or edits another message' do
      revoke = whatsapp_edit_plaintext(original_id: original_id, edited_message: edited_message, type: 0)
      other = whatsapp_edit_plaintext(original_id: 'OTHER', edited_message: edited_message)

      [revoke, other].each do |unexpected|
        envelope = encrypt_whatsapp_edit(plaintext: unexpected, secret: secret, original_id: original_id, jid: customer)

        expect(refusal_reason { decrypt(enc_payload: envelope['encPayload'], enc_iv: envelope['encIv']) }).to eq(:invalid_edit)
      end
    end

    it 'refuses a decrypted content that is not valid protobuf' do
      envelope = encrypt_whatsapp_edit(plaintext: "\x0a\xff\xff".b, secret: secret, original_id: original_id, jid: customer)

      expect(refusal_reason { decrypt(enc_payload: envelope['encPayload'], enc_iv: envelope['encIv']) }).to eq(:invalid_edit)
    end
  end
end
