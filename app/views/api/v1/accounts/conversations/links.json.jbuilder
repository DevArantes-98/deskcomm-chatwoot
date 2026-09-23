json.meta do
  json.total_count @links_count
end

json.payload @messages.flat_map { |message|
  Message.extract_urls(message.content).map { |url| { message: message, url: url } }
} do |link|
  json.url link[:url]
  json.message_id link[:message][:id]
  json.conversation_id link[:message].conversation.display_id
  json.created_at link[:message].created_at.to_i
  json.sender link[:message].sender&.push_event_data
end
