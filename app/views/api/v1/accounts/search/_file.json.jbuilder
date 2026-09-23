conversation = attachment.message.conversation

json.id attachment.id
json.file_type attachment.file_type
json.filename attachment.file.filename.to_s
json.extension attachment.extension
json.file_size attachment.file.byte_size
json.content_type attachment.file.content_type
json.data_url attachment.file_url
json.message_id attachment.message_id
json.conversation_id conversation.display_id
json.inbox_id attachment.message.inbox_id
json.contact_name conversation.contact&.name
json.created_at attachment.created_at.to_i
