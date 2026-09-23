require 'rails_helper'

describe Messages::EditService do
  subject(:service) { described_class.new(message: message, content: content, user: agent) }

  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_api, account: account, additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test', 'token' => 'tok' } })
  end
  let(:inbox) { channel.inbox }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:customer) { create(:contact, account: account, phone_number: '+5511999990001') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer) }
  let(:content) { 'Reuniao as 11h' }
  let(:source_id) { 'WAID:3EB0ABC123' }
  let!(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent,
                     content: 'Reuniao as 10h', source_id: source_id)
  end
  let!(:whatsapp_request) do
    stub_request(:post, 'https://evo.test/message/edit')
      .to_return(status: 200, body: { message: 'success' }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def expect_refusal(reason, user: agent)
    expect { described_class.new(message: message, content: content, user: user).perform }
      .to raise_error(EvolutionGo::Refused) { |error| expect(error.reason).to eq(reason) }
    expect(whatsapp_request).not_to have_been_requested
  end

  after { Current.reset }

  describe '#perform' do
    it 'edits the message on WhatsApp using the id without the WAID prefix, then saves it here' do
      service.perform

      expect(a_request(:post, 'https://evo.test/message/edit').with(
               headers: { 'apikey' => 'tok' },
               body: { chat: '5511999990001@s.whatsapp.net', messageId: '3EB0ABC123', message: 'Reuniao as 11h' }.to_json
             )).to have_been_made.once
      expect(message.reload.content).to eq('Reuniao as 11h')
    end

    it 'marks the message as edited and keeps the very first text across several edits' do
      service.perform
      described_class.new(message: message.reload, content: 'Reuniao as 12h', user: agent).perform

      expect(message.reload.content_attributes).to include('edited' => true, 'original_content' => 'Reuniao as 10h')
      expect(message.content_attributes['edited_at']).to be_within(5).of(Time.current.to_i)
    end

    it 'accepts WhatsApp ids stored without the WAID prefix' do
      message.update!(source_id: '3EB0ABC123')

      service.perform

      expect(a_request(:post, 'https://evo.test/message/edit').with(body: hash_including('messageId' => '3EB0ABC123'))).to have_been_made
    end

    it 'trims the new text' do
      described_class.new(message: message, content: "  Reuniao as 11h \n", user: agent).perform

      expect(message.reload.content).to eq('Reuniao as 11h')
    end

    it 'lets administrators edit messages sent by other agents' do
      admin = create(:user, account: account, role: :administrator)
      Current.account_user = admin.account_users.find_by(account: account)

      described_class.new(message: message, content: content, user: admin).perform

      expect(message.reload.content).to eq('Reuniao as 11h')
    end

    it 'does not save anything when WhatsApp rejects the edit' do
      stub_request(:post, 'https://evo.test/message/edit').to_return(status: 400, body: { error: 'too old' }.to_json,
                                                                     headers: { 'Content-Type' => 'application/json' })

      expect { service.perform }.to raise_error(EvolutionGo::Error, /400/)
      expect(message.reload.content).to eq('Reuniao as 10h')
      expect(message.content_attributes).not_to include('edited')
    end
  end

  describe 'refusals (WhatsApp is never called)' do
    it 'refuses incoming messages' do
      message.update!(message_type: :incoming)

      expect_refusal(:not_outgoing)
    end

    it 'refuses private notes' do
      message.update!(private: true)

      expect_refusal(:private_note)
    end

    it 'refuses messages with attachments' do
      attachment = message.attachments.new(account: account, file_type: :file)
      attachment.file.attach(io: StringIO.new('content'), filename: 'a.pdf', content_type: 'application/pdf')
      attachment.save!

      expect_refusal(:not_text)
    end

    it 'refuses deleted messages' do
      message.update!(content_attributes: { 'deleted' => true })

      expect_refusal(:deleted)
    end

    it 'refuses agents who neither sent the message nor administer the account' do
      other_agent = create(:user, account: account, role: :agent)

      expect_refusal(:forbidden, user: other_agent)
    end

    it 'refuses inboxes that are not linked to Evolution Go' do
      channel.update!(additional_attributes: { 'evolution_go' => nil })

      expect_refusal(:inbox_not_supported)
    end

    context 'when the message has no WhatsApp id yet' do
      let(:source_id) { nil }

      it 'refuses it' do
        expect_refusal(:no_source_id)
      end
    end

    it 'refuses messages older than the 15 minute WhatsApp window' do
      message.update!(created_at: 16.minutes.ago)

      expect_refusal(:window_expired)
    end

    context 'with a blank new text' do
      let(:content) { '   ' }

      it 'refuses it' do
        expect_refusal(:blank_content)
      end
    end

    context 'with the same text' do
      let(:content) { 'Reuniao as 10h' }

      it 'refuses it' do
        expect_refusal(:unchanged)
      end
    end

    it 'refuses conversations whose customer has no WhatsApp chat' do
      customer.update!(phone_number: nil, email: 'cliente@example.com')

      expect_refusal(:no_chat_jid)
    end
  end
end
