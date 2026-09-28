require 'rails_helper'

describe Messages::ApplyEncryptedEditService do
  include WhatsappEncryptedEditHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:secret) { SecureRandom.random_bytes(32) }
  let(:original_id) { '3EB0C767D0F26E3F1B2A' }
  let(:customer) { '5511999990000@s.whatsapp.net' }
  let(:payloads) { whatsapp_edit_payloads(secret: secret, original_id: original_id, new_text: 'Reuniao as 11h', remote_jid: customer) }
  let!(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     content: 'Reuniao as 10h', source_id: "WAID:#{original_id}")
  end

  before { Current.account = account }

  after { Current.reset }

  def apply(user: admin, edit: payloads[:edit], original: payloads[:original])
    described_class.new(account: account, user: user, edit: edit, original: original).perform
  end

  def refusal_reason
    yield
  rescue EvolutionGo::Refused => e
    e.reason
  end

  it 'decrypts the edit and shows it on the original message' do
    apply

    expect(message.reload.content).to eq('Reuniao as 11h')
    expect(message.content_attributes).to include('edited' => true, 'edited_at' => 1_800_000_000, 'original_content' => 'Reuniao as 10h')
  end

  it 'accepts the whole webhook body and the whole findMessages response' do
    apply(edit: { 'event' => 'messages.upsert', 'data' => payloads[:edit] }, original: { 'messages' => { 'records' => [payloads[:original]] } })

    expect(message.reload.content).to eq('Reuniao as 11h')
  end

  it 'finds a message whose source id has no WAID prefix' do
    message.update!(source_id: original_id)

    expect(apply.content).to eq('Reuniao as 11h')
  end

  it 'decrypts an edit addressed with the LID of the customer' do
    lid = '184455901728990@lid'
    payloads = whatsapp_edit_payloads(secret: secret, original_id: original_id, new_text: 'Reuniao as 11h',
                                      remote_jid: lid, remote_jid_alt: customer, encrypted_for: lid)

    expect(apply(edit: payloads[:edit], original: payloads[:original]).content).to eq('Reuniao as 11h')
  end

  it 'keeps the very first text when the customer edits again' do
    apply
    second = whatsapp_edit_payloads(secret: secret, original_id: original_id, new_text: 'Reuniao as 12h', remote_jid: customer)
    apply(edit: second[:edit], original: second[:original])

    expect(message.reload.content).to eq('Reuniao as 12h')
    expect(message.content_attributes['original_content']).to eq('Reuniao as 10h')
  end

  describe 'who can apply it' do
    it 'lets an agent of the inbox do it, but not an agent outside of it' do
      agent = create(:user, account: account, role: :agent)
      outsider = create(:user, account: account, role: :agent)
      create(:inbox_member, user: agent, inbox: inbox)

      expect { apply(user: outsider) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(apply(user: agent).content).to eq('Reuniao as 11h')
    end

    it 'only edits messages of API inboxes' do
      message.update!(inbox: create(:inbox, account: account))

      expect { apply }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'does not find a message of another account' do
      other = create(:account)
      message.update_columns(account_id: other.id) # rubocop:disable Rails/SkipsModelValidations

      expect { apply }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises not found for a WhatsApp message Chatwoot never saw' do
      message.update!(source_id: 'WAID:SOMETHING-ELSE')

      expect { apply }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'refusing what is not a valid edit' do
    it 'refuses events that are not an encrypted edit' do
      not_encrypted = { 'key' => { 'remoteJid' => customer, 'id' => 'X' }, 'message' => { 'conversation' => 'oi' } }
      other_type = payloads[:edit].deep_dup.tap { |edit| edit['message']['secretEncryptedMessage']['secretEncType'] = 1 }

      expect(refusal_reason { apply(edit: not_encrypted) }).to eq(:not_an_edit)
      expect(refusal_reason { apply(edit: other_type) }).to eq(:not_an_edit)
    end

    it 'leaves the message alone when it cannot be decrypted' do
      original = payloads[:original].deep_dup
      original['message']['messageContextInfo']['messageSecret'] = uint8_array_json(SecureRandom.random_bytes(32))

      expect(refusal_reason { apply(original: original) }).to eq(:decrypt_failed)
      expect(message.reload.content).to eq('Reuniao as 10h')
    end

    it 'asks for the secret when the stored original does not have one' do
      original = payloads[:original].deep_dup.tap { |data| data['message'].delete('messageContextInfo') }

      expect(refusal_reason { apply(original: original) }).to eq(:missing_secret)
    end
  end
end
