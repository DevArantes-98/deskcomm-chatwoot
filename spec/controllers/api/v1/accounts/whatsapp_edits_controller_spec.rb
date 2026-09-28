require 'rails_helper'

RSpec.describe 'WhatsApp edits API', type: :request do
  include WhatsappEncryptedEditHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:secret) { SecureRandom.random_bytes(32) }
  let(:original_id) { '3EB0C767D0F26E3F1B2A' }
  let(:payloads) do
    whatsapp_edit_payloads(secret: secret, original_id: original_id, new_text: 'Reuniao as 11h', remote_jid: '5511999990000@s.whatsapp.net')
  end
  let(:path) { "/api/v1/accounts/#{account.id}/whatsapp_edits" }
  let!(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     content: 'Reuniao as 10h', source_id: "WAID:#{original_id}")
  end

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'POST /api/v1/accounts/{account.id}/whatsapp_edits' do
    it 'returns unauthorized without a session' do
      post path, params: payloads, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'decrypts the edit of the customer and updates the message' do
      post path, headers: agent.create_new_auth_token, params: payloads, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('id' => message.id, 'content' => 'Reuniao as 11h')
      expect(message.reload.content_attributes).to include('edited' => true, 'original_content' => 'Reuniao as 10h')
    end

    it 'returns not found for a message Chatwoot does not have' do
      message.update!(source_id: 'WAID:OTHER')

      post path, headers: agent.create_new_auth_token, params: payloads, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'explains why an edit was refused' do
      payloads[:original]['message'].delete('messageContextInfo')

      post path, headers: agent.create_new_auth_token, params: payloads, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('missing_secret')
    end
  end
end
