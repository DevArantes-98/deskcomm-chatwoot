json.id group.id
json.name group.name
json.identifier group.identifier
json.thumbnail group.avatar_url
json.conversation_id group.try(:conversation_id)
json.last_activity_at group.last_activity_at&.to_i
