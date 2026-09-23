require 'rails_helper'

describe Reports::CsDashboardService do
  subject(:result) do
    described_class.new(account: account, range_start: 10.days.ago, range_end: Time.current, **options).perform
  end

  let(:options) { {} }
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:gestor) { create(:user, account: account, name: 'Gestora A') }
  let!(:contact) { create(:contact, account: account, name: 'Cliente 1', phone_number: '+5511999990001') }
  let!(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: gestor,
                          custom_attributes: { 'motivo_fechamento' => 'Integração' }, created_at: 3.days.ago)
  end

  def event(name, value, at: 2.days.ago, target: conversation)
    create(:reporting_event, account: account, inbox: target.inbox, conversation: target, user: gestor, name: name, value: value, created_at: at)
  end

  describe 'response time' do
    before do
      event('reply_time', 120)
      event('reply_time', 240)
      event('first_response', 60)
    end

    it 'averages reply time and first response time' do
      expect(result[:response_time]).to include(reply_time_avg: 180, first_response_avg: 60)
    end

    it 'breaks the averages down by the conversation assignee' do
      expect(result[:response_time][:by_assignee]).to eq(
        [{ assignee_id: gestor.id, name: 'Gestora A', conversations: 1, reply_time_avg: 180, first_response_avg: 60 }]
      )
    end

    it 'ignores events outside the selected range' do
      event('reply_time', 9999, at: 20.days.ago)

      expect(result[:response_time][:reply_time_avg]).to eq(180)
    end

    it 'returns nil averages when there is no data' do
      ReportingEvent.delete_all

      expect(result[:response_time]).to include(reply_time_avg: nil, first_response_avg: nil, by_assignee: [])
    end
  end

  describe 'volume' do
    before { event('conversation_resolved', 3600) }

    it 'returns one bucket per day, zero filled, with created and resolved counts' do
      volume = result[:volume]

      expect(volume.length).to be_between(10, 12)
      expect(volume.sum { |row| row[:created] }).to eq(1)
      expect(volume.find { |row| row[:date] == 3.days.ago.to_date.iso8601 }[:created]).to eq(1)
      expect(volume.find { |row| row[:date] == 2.days.ago.to_date.iso8601 }[:resolved]).to eq(1)
    end

    it 'groups by week starting on monday' do
      dates = described_class.new(account: account, range_start: 30.days.ago, range_end: Time.current, group_by: 'week').perform[:volume]

      expect(dates.map { |row| Date.parse(row[:date]).wday }.uniq).to eq([1])
    end

    it 'falls back to days for an unknown grouping' do
      dates = described_class.new(account: account, range_start: 3.days.ago, range_end: Time.current, group_by: 'year').perform[:range]

      expect(dates[:group_by]).to eq('day')
    end

    it 'only counts the requested inbox' do
      other_inbox = create(:inbox, account: account)
      other = create(:conversation, account: account, inbox: other_inbox, contact: create(:contact, account: account), created_at: 3.days.ago)
      event('conversation_resolved', 100, target: other)

      filtered = described_class.new(account: account, range_start: 10.days.ago, range_end: Time.current, inbox_id: other_inbox.id).perform

      expect(filtered[:volume].sum { |row| row[:created] }).to eq(1)
      expect(filtered[:volume].sum { |row| row[:resolved] }).to eq(1)
    end
  end

  describe 'closing reasons' do
    it 'counts resolved conversations by motivo_fechamento, biggest first, with a nil reason when it was not filled' do
      event('conversation_resolved', 100)
      no_reason = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account))
      event('conversation_resolved', 100, target: no_reason)
      second = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account),
                                     custom_attributes: { 'motivo_fechamento' => 'Integração' })
      event('conversation_resolved', 100, target: second)

      expect(result[:closing_reasons]).to eq([{ reason: 'Integração', count: 2 }, { reason: nil, count: 1 }])
    end

    it 'ignores conversations that were not resolved in the range' do
      expect(result[:closing_reasons]).to eq([])
    end
  end

  describe 'dormant customers' do
    before { conversation.update!(last_activity_at: 20.days.ago) }

    it 'lists customers with no activity for more than 15 days with their latest conversation and manager' do
      dormant = result[:dormant]

      expect(dormant[:threshold_days]).to eq(15)
      expect(dormant[:total]).to eq(1)
      expect(dormant[:contacts].first).to include(
        id: contact.id, name: 'Cliente 1', phone_number: '+5511999990001', conversation_id: conversation.display_id,
        assignee_name: 'Gestora A', days_dormant: 20
      )
    end

    it 'does not list customers with recent activity' do
      conversation.update!(last_activity_at: 2.days.ago)

      expect(result[:dormant]).to include(total: 0, contacts: [])
    end

    it 'uses the most recent conversation of the customer' do
      create(:conversation, account: account, inbox: inbox, contact: contact, last_activity_at: 1.day.ago)

      expect(result[:dormant][:total]).to eq(0)
    end

    it 'leaves out WhatsApp groups and blocked contacts' do
      group = create(:contact, account: account, name: 'Grupo', identifier: '120363000000000001@g.us')
      blocked = create(:contact, account: account, name: 'Bloqueado', phone_number: '+5511999990002', blocked: true)
      [group, blocked].each do |silent|
        create(:conversation, account: account, inbox: inbox, contact: silent, last_activity_at: 30.days.ago)
      end

      expect(result[:dormant][:contacts].map { |row| row[:name] }).to eq(['Cliente 1'])
    end
  end
end
