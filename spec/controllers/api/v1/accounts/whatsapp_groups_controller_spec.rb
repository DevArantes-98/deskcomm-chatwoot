require 'rails_helper'

RSpec.describe 'WhatsApp groups API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_api, account: account, additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test', 'token' => 'tok' } })
  end
  let(:inbox) { channel.inbox }
  let(:path) { "/api/v1/accounts/#{account.id}/whatsapp_groups" }
  let(:member) { create(:contact, account: account, name: 'Fulano de Tal', phone_number: '+5511988887777') }
  let(:group_jid) { '120363111111111111@g.us' }

  def stub_create(status: 200, body: { data: { 'jid' => group_jid, 'name' => 'Vendas', 'failed' => [] } })
    stub_request(:post, 'https://evo.test/group/create')
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'POST /api/v1/accounts/{account.id}/whatsapp_groups' do
    it 'returns unauthorized without a session' do
      post path, params: { inbox_id: inbox.id, name: 'Vendas', contact_ids: [member.id] }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the group on WhatsApp and opens a group contact and conversation' do
      request = stub_create

      post path, headers: agent.create_new_auth_token, params: { inbox_id: inbox.id, name: 'Vendas', contact_ids: [member.id] }, as: :json

      expect(response).to have_http_status(:success)
      expect(request.with(body: { groupName: 'Vendas', participants: ['5511988887777'] }.to_json)).to have_been_requested
      group_contact = account.contacts.find_by!(identifier: group_jid)
      conversation = account.conversations.find_by!(display_id: response.parsed_body['conversation_id'])
      expect(group_contact.name).to eq('Vendas')
      expect(conversation).to have_attributes(contact: group_contact, inbox: inbox)
      expect(response.parsed_body).to include('jid' => group_jid, 'name' => 'Vendas', 'failed' => [])
    end

    it 'reuses the group contact and conversation when they already exist' do
      stub_create
      existing = create(:contact, account: account, name: 'Vendas', identifier: group_jid)
      conversation = create(:conversation, account: account, inbox: inbox, contact: existing)

      post path, headers: agent.create_new_auth_token, params: { inbox_id: inbox.id, name: 'Vendas', contact_ids: [member.id] }, as: :json

      expect(response.parsed_body['conversation_id']).to eq(conversation.display_id)
      expect(account.contacts.where(identifier: group_jid).count).to eq(1)
    end

    it 'does not create anything when WhatsApp refuses' do
      stub_create(status: 500, body: { error: 'not connected' })

      post path, headers: agent.create_new_auth_token, params: { inbox_id: inbox.id, name: 'Vendas', contact_ids: [member.id] }, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(account.contacts.where("identifier LIKE '%@g.us'")).to be_empty
    end

    it 'validates the name and the participants' do
      post path, headers: agent.create_new_auth_token, params: { inbox_id: inbox.id, name: ' ', contact_ids: [member.id] }, as: :json
      expect(response.parsed_body['code']).to eq('blank_name')

      post path, headers: agent.create_new_auth_token, params: { inbox_id: inbox.id, name: 'Vendas', contact_ids: [] }, as: :json
      expect(response.parsed_body['code']).to eq('no_participants')
    end

    it 'is not available for inboxes the agent is not a member of' do
      other_inbox = create(:channel_api, account: account,
                                         additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test', 'token' => 'tok' } }).inbox

      post path, headers: agent.create_new_auth_token, params: { inbox_id: other_inbox.id, name: 'Vendas', contact_ids: [member.id] }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
