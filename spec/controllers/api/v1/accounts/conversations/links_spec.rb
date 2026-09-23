require 'rails_helper'

RSpec.describe 'Conversation links API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/links" }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'GET /api/v1/accounts/{account.id}/conversations/{id}/links' do
    it 'returns unauthorized without a session' do
      get path

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists every URL shared in the conversation, newest message first' do
      create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Sem link aqui')
      older = create(:message, conversation: conversation, account: account, inbox: inbox, created_at: 2.days.ago,
                               content: 'Veja https://exemplo.com/a e https://exemplo.com/b')
      newer = create(:message, conversation: conversation, account: account, inbox: inbox, created_at: 1.day.ago,
                               content: 'Doc: https://exemplo.com/c')

      get path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['meta']['total_count']).to eq(2)
      expect(body['payload'].pluck('url')).to eq(['https://exemplo.com/c', 'https://exemplo.com/a', 'https://exemplo.com/b'])
      expect(body['payload'].first).to include('message_id' => newer.id, 'conversation_id' => conversation.display_id)
      expect(body['payload'].last['message_id']).to eq(older.id)
    end

    it 'is empty when nobody shared a link' do
      create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Oi')

      get path, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('payload' => [], 'meta' => { 'total_count' => 0 })
    end
  end
end
