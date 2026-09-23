# Numbers behind the customer-success dashboard: response times, conversation volume, closing reasons
# and dormant customers. Everything is derived from data Chatwoot already records (reporting events,
# conversations and the `motivo_fechamento` conversation attribute).
class Reports::CsDashboardService
  DORMANT_DAYS = 15
  DORMANT_LIST_LIMIT = 50
  REASON_ATTRIBUTE = 'motivo_fechamento'.freeze
  GROUPINGS = %w[day week month].freeze

  pattr_initialize [:account!, :range_start!, :range_end!, { group_by: 'day', timezone_offset: 0, inbox_id: nil }]

  def perform
    {
      range: { since: range_start.to_i, until: range_end.to_i, group_by: grouping },
      response_time: response_time,
      volume: volume,
      closing_reasons: closing_reasons,
      dormant: dormant
    }
  end

  private

  def grouping
    GROUPINGS.include?(group_by.to_s) ? group_by.to_s : 'day'
  end

  def offset_hours
    timezone_offset.to_f
  end

  def conversations
    scope = account.conversations
    inbox_id.present? ? scope.where(inbox_id: inbox_id) : scope
  end

  def events(name)
    scope = ReportingEvent.where(account_id: account.id, name: name, created_at: range_start..range_end)
    inbox_id.present? ? scope.where(inbox_id: inbox_id) : scope
  end

  def seconds(value)
    value&.to_f&.round
  end

  def response_time
    {
      reply_time_avg: seconds(events('reply_time').average(:value)),
      first_response_avg: seconds(events('first_response').average(:value)),
      by_assignee: response_time_by_assignee
    }
  end

  def response_events
    events(%w[reply_time first_response])
  end

  def response_time_by_assignee
    counts = conversations.where(id: response_events.select(:conversation_id)).group(:assignee_id).count
    averages = response_events.joins(:conversation).group('conversations.assignee_id', 'reporting_events.name')
                              .average('reporting_events.value')
    names = account.users.where(id: counts.keys.compact).pluck(:id, :name).to_h

    rows = counts.map { |assignee_id, total| assignee_row(assignee_id, total, averages, names) }
    rows.sort_by { |row| row[:reply_time_avg] || Float::INFINITY }
  end

  def assignee_row(assignee_id, total, averages, names)
    {
      assignee_id: assignee_id, name: names[assignee_id], conversations: total,
      reply_time_avg: seconds(averages[[assignee_id, 'reply_time']]),
      first_response_avg: seconds(averages[[assignee_id, 'first_response']])
    }
  end

  def volume
    created = bucket_counts(conversations.where(created_at: range_start..range_end), 'conversations.created_at')
    resolved = bucket_counts(events('conversation_resolved'), 'reporting_events.created_at')
    buckets.map { |date| { date: date.iso8601, created: created[date] || 0, resolved: resolved[date] || 0 } }
  end

  def bucket_counts(scope, column)
    scope.group(Arel.sql("date_trunc('#{grouping}', #{column} + interval '#{offset_hours} hours')"))
         .count.transform_keys(&:to_date)
  end

  def buckets
    start = bucket_start(local_date(range_start))
    finish = bucket_start(local_date(range_end))
    dates = [start]
    dates << next_bucket(dates.last) while dates.last < finish
    dates
  end

  def local_date(time)
    (time + offset_hours.hours).to_date
  end

  def bucket_start(date)
    case grouping
    when 'week' then date.beginning_of_week(:monday)
    when 'month' then date.beginning_of_month
    else date
    end
  end

  def next_bucket(date)
    case grouping
    when 'week' then date + 1.week
    when 'month' then date.next_month
    else date + 1.day
    end
  end

  def closing_reasons
    resolved_ids = events('conversation_resolved').select(:conversation_id)
    conversations.where(id: resolved_ids)
                 .group(Arel.sql("conversations.custom_attributes ->> '#{REASON_ATTRIBUTE}'")).count
                 .map { |reason, count| { reason: reason.presence, count: count } }
                 .sort_by { |row| -row[:count] }
  end

  def dormant
    cutoff = DORMANT_DAYS.days.ago
    silent = conversations.joins(:contact)
                          .where(contacts: { blocked: false })
                          .where("contacts.identifier IS NULL OR contacts.identifier NOT LIKE '%@g.us'")
                          .group('contacts.id').having('MAX(conversations.last_activity_at) < ?', cutoff)
    {
      threshold_days: DORMANT_DAYS,
      total: silent.count.size,
      contacts: silent.select(dormant_columns).reorder('last_activity_at DESC').limit(DORMANT_LIST_LIMIT).map { |row| dormant_row(row) }
    }
  end

  def dormant_columns
    latest = 'SELECT %s FROM conversations c2 %s WHERE c2.contact_id = contacts.id ORDER BY c2.last_activity_at DESC LIMIT 1'
    <<~SQL.squish
      contacts.id, contacts.name, contacts.phone_number, MAX(conversations.last_activity_at) AS last_activity_at,
      (#{format(latest, 'c2.display_id', '')}) AS conversation_id,
      (#{format(latest, 'u.name', 'LEFT JOIN users u ON u.id = c2.assignee_id')}) AS assignee_name
    SQL
  end

  def dormant_row(row)
    {
      id: row.id, name: row.name, phone_number: row.phone_number, conversation_id: row.conversation_id,
      assignee_name: row.assignee_name, last_activity_at: row.last_activity_at.to_i,
      days_dormant: ((Time.current - row.last_activity_at) / 1.day).floor
    }
  end
end
