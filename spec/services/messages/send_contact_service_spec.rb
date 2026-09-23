require 'rails_helper'

describe Messages::SendContactService do
  subject(:service) { described_class.new(conversation: conversation, contact: shared, user: agent) }

  let(:account) { create(:account) }
  let(:evolution_config) { { 'url' => 'https://evo.test', 'token' => 'tok' } }
  let(:channel) { create(:channel_api, account: account, additional_attributes: { 'evolution_go' => evolution_config }) }
  let(:inbox) { channel.inbox }
  let(:customer) { create(:contact, account: account, name: 'Cliente', phone_number: '+5511999990001') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer) }
  let(:agent) { create(:user, account: account) }
  let(:shared) do
    create(:contact, account: account, name: 'Fulano de Tal', phone_number: '+5511988887777', additional_attributes: { 'company_name' => 'ACME' })
  end
  let!(:whatsapp_request) do
    stub_request(:post, 'https://evo.test/send/contact')
      .to_return(status: 200, body: { data: { 'Info' => { 'ID' => '3EB0SENT' } } }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def refusal_reason
    service.perform
  rescue EvolutionGo::Refused => e
    e.reason
  end

  describe '#perform' do
    it 'sends the vCard to the customer chat' do
      service.perform

      expect(a_request(:post, 'https://evo.test/send/contact').with(
               headers: { 'apikey' => 'tok' },
               body: { number: '5511999990001@s.whatsapp.net',
                       vcard: { fullName: 'Fulano de Tal', phone: '5511988887777', organization: 'ACME' } }.to_json
             )).to have_been_made.once
    end

    it 'records an outgoing message with a contact attachment, marked as already delivered' do
      message = service.perform

      expect(message).to be_persisted
      expect(message).to have_attributes(message_type: 'outgoing', sender: agent, source_id: 'WAID:3EB0SENT', conversation: conversation)
      expect(message.content_attributes).to include('delivered_by' => 'evolution_go')
      expect(message.attachments.first).to have_attributes(file_type: 'contact', fallback_title: '5511988887777',
                                                           meta: { 'firstName' => 'Fulano de Tal', 'lastName' => '' })
    end

    it 'sends to the group JID when the conversation is a WhatsApp group' do
      group = create(:contact, account: account, name: 'Vendas', identifier: '120363111111111111@g.us')
      group_conversation = create(:conversation, account: account, inbox: inbox, contact: group)

      described_class.new(conversation: group_conversation, contact: shared, user: agent).perform

      expect(a_request(:post, 'https://evo.test/send/contact').with(body: hash_including('number' => '120363111111111111@g.us'))).to have_been_made
    end

    it 'falls back to the WhatsApp identifier when the contact has no phone number' do
      no_phone = create(:contact, account: account, name: 'Sem telefone', phone_number: nil, identifier: '5511977776666@s.whatsapp.net')

      described_class.new(conversation: conversation, contact: no_phone, user: agent).perform

      expect(a_request(:post, 'https://evo.test/send/contact').with(body: hash_including('vcard' => hash_including('phone' => '5511977776666'))))
        .to have_been_made
    end

    it 'records the message without a source id when WhatsApp does not return one' do
      stub_request(:post, 'https://evo.test/send/contact').to_return(status: 200, body: { message: 'success' }.to_json,
                                                                     headers: { 'Content-Type' => 'application/json' })

      expect(service.perform.source_id).to be_nil
    end
  end

  describe 'refusals' do
    it 'refuses inboxes that are not linked to Evolution Go' do
      channel.update!(additional_attributes: { 'evolution_go' => nil })

      expect(refusal_reason).to eq(:inbox_not_supported)
      expect(whatsapp_request).not_to have_been_requested
    end

    it 'refuses contacts without a phone number' do
      no_phone = create(:contact, account: account, name: 'Sem telefone', phone_number: nil, email: 'x@example.com')

      reason = begin
        described_class.new(conversation: conversation, contact: no_phone, user: agent).perform
      rescue EvolutionGo::Refused => e
        e.reason
      end

      expect(reason).to eq(:contact_without_phone)
      expect(whatsapp_request).not_to have_been_requested
    end

    it 'refuses conversations whose customer has no WhatsApp chat' do
      conversation.contact.update!(phone_number: nil, email: 'cliente@example.com')

      expect(refusal_reason).to eq(:no_chat_jid)
    end
  end

  it 'does not record anything when WhatsApp rejects the contact' do
    stub_request(:post, 'https://evo.test/send/contact').to_return(status: 500, body: { error: 'not connected' }.to_json,
                                                                   headers: { 'Content-Type' => 'application/json' })

    before_count = conversation.messages.count

    expect { service.perform }.to raise_error(EvolutionGo::Error)
    expect(conversation.messages.count).to eq(before_count)
  end
end
