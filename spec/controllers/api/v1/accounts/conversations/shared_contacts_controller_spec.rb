require 'rails_helper'

RSpec.describe 'Conversation shared contacts API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_api, account: account, additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test', 'token' => 'tok' } })
  end
  let(:inbox) { channel.inbox }
  let(:customer) { create(:contact, account: account, phone_number: '+5511999990001') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer) }
  let(:shared) { create(:contact, account: account, name: 'Fulano de Tal', phone_number: '+5511988887777') }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/shared_contacts" }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'POST /api/v1/accounts/{account.id}/conversations/{id}/shared_contacts' do
    it 'returns unauthorized without a session' do
      post path, params: { contact_id: shared.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'sends the contact on WhatsApp and returns the recorded message' do
      whatsapp = stub_request(:post, 'https://evo.test/send/contact')
                 .to_return(status: 200, body: { data: { 'Info' => { 'ID' => '3EB0SENT' } } }.to_json,
                            headers: { 'Content-Type' => 'application/json' })

      post path, headers: agent.create_new_auth_token, params: { contact_id: shared.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(whatsapp).to have_been_requested
      body = response.parsed_body
      expect(body).to include('source_id' => 'WAID:3EB0SENT', 'message_type' => 1)
      expect(body['attachments'].first).to include('file_type' => 'contact', 'fallback_title' => '5511988887777')
    end

    it 'explains why a contact could not be sent' do
      no_phone = create(:contact, account: account, name: 'Sem telefone', phone_number: nil, email: 'x@example.com')

      post path, headers: agent.create_new_auth_token, params: { contact_id: no_phone.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('contact_without_phone')
    end

    it 'reports WhatsApp failures as a bad gateway without recording a message' do
      stub_request(:post, 'https://evo.test/send/contact').to_return(status: 500, body: { error: 'not connected' }.to_json,
                                                                     headers: { 'Content-Type' => 'application/json' })

      post path, headers: agent.create_new_auth_token, params: { contact_id: shared.id }, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['code']).to eq('whatsapp_error')
      expect(conversation.messages.count).to eq(0)
    end

    it 'does not find contacts from other accounts' do
      foreign = create(:contact, account: create(:account), phone_number: '+5511977776666')

      post path, headers: agent.create_new_auth_token, params: { contact_id: foreign.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
