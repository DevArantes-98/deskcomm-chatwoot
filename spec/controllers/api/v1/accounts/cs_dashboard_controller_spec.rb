require 'rails_helper'

RSpec.describe 'CS dashboard API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/cs_dashboard' do
    it 'returns unauthorized without a session' do
      get "/api/v1/accounts/#{account.id}/cs_dashboard"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'is not available to agents' do
      get "/api/v1/accounts/#{account.id}/cs_dashboard", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns every section for administrators, defaulting to the last 30 days' do
      get "/api/v1/accounts/#{account.id}/cs_dashboard", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      data = response.parsed_body
      expect(data.keys).to contain_exactly('range', 'response_time', 'volume', 'closing_reasons', 'dormant')
      expect(data['range']).to include('group_by' => 'day')
      expect(data['range']['until'] - data['range']['since']).to be_within(5).of(30.days.to_i)
      expect(data['dormant']).to include('threshold_days' => 15)
    end

    it 'passes the range, grouping and inbox filter to the report' do
      inbox = create(:inbox, account: account)
      since = 60.days.ago.to_i
      until_time = 30.days.ago.to_i

      get "/api/v1/accounts/#{account.id}/cs_dashboard",
          headers: administrator.create_new_auth_token,
          params: { since: since, until: until_time, group_by: 'week', inbox_id: inbox.id },
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['range']).to eq('since' => since, 'until' => until_time, 'group_by' => 'week')
    end
  end
end
