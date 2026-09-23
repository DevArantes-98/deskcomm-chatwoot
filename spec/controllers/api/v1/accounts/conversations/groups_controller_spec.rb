require 'rails_helper'

RSpec.describe 'Conversation WhatsApp group API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_api, account: account, additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test', 'token' => 'tok' } })
  end
  let(:inbox) { channel.inbox }
  let(:group_jid) { '120363111111111111@g.us' }
  let(:group) { create(:contact, account: account, name: 'Vendas', identifier: group_jid) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: group) }
  let(:base_path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/group" }
  let(:group_info) do
    { data: { 'JID' => group_jid, 'GroupName' => { 'Name' => 'Vendas' }, 'GroupTopic' => { 'Topic' => '' },
              'Participants' => [{ 'JID' => '5511988887777@s.whatsapp.net', 'IsAdmin' => false }] } }
  end

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    stub_request(:post, 'https://evo.test/group/info')
      .to_return(status: 200, body: group_info.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_participants
    stub_request(:post, 'https://evo.test/group/participant')
      .to_return(status: 200, body: { message: 'success' }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe 'GET /group' do
    it 'returns unauthorized without a session' do
      get base_path

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the group with its participants' do
      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('jid' => group_jid, 'name' => 'Vendas')
      expect(response.parsed_body['participants'].first).to include('phone' => '5511988887777', 'admin' => false)
    end

    it 'refuses conversations that are not WhatsApp groups' do
      customer = create(:contact, account: account, phone_number: '+5511999990001')
      other = create(:conversation, account: account, inbox: inbox, contact: customer)

      get "/api/v1/accounts/#{account.id}/conversations/#{other.display_id}/group", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('not_a_group')
    end

    it 'reports WhatsApp failures as a bad gateway' do
      stub_request(:post, 'https://evo.test/group/info').to_return(status: 500, body: { error: 'not connected' }.to_json,
                                                                   headers: { 'Content-Type' => 'application/json' })

      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe 'GET /group/invite_link' do
    it 'returns the invite URL' do
      stub_request(:post, 'https://evo.test/group/invitelink')
        .to_return(status: 200, body: { data: 'AbCdEf' }.to_json, headers: { 'Content-Type' => 'application/json' })

      get "#{base_path}/invite_link", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('url' => 'https://chat.whatsapp.com/AbCdEf')
    end
  end

  describe 'POST /group/add_participants' do
    it 'adds the phone numbers of the chosen contacts' do
      request = stub_participants
      contact = create(:contact, account: account, phone_number: '+5511977776666')

      post "#{base_path}/add_participants", headers: agent.create_new_auth_token, params: { contact_ids: [contact.id] }, as: :json

      expect(response).to have_http_status(:success)
      expect(request.with(body: { groupJid: group_jid, participants: ['5511977776666'], action: 'add' }.to_json)).to have_been_requested
    end

    it 'requires at least one contact with a phone number' do
      post "#{base_path}/add_participants", headers: agent.create_new_auth_token, params: { contact_ids: [] }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('no_participants')
    end
  end

  describe 'POST /group/remove_participants' do
    it 'removes the given participants' do
      request = stub_participants

      post "#{base_path}/remove_participants", headers: agent.create_new_auth_token,
                                               params: { participants: ['5511988887777@s.whatsapp.net'] }, as: :json

      expect(response).to have_http_status(:success)
      expect(request.with(body: { groupJid: group_jid, participants: ['5511988887777@s.whatsapp.net'], action: 'remove' }.to_json))
        .to have_been_requested
    end
  end
end
