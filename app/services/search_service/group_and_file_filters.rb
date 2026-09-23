# Searches for WhatsApp groups and uploaded files, mixed into SearchService (it relies on the
# helpers defined there: accessable_inbox_ids, search_query and apply_time_filter).
module SearchService::GroupAndFileFilters
  private

  # WhatsApp groups are contacts identified by their group JID. Only groups that have a conversation in an
  # inbox the agent can access are returned, together with the most recent of those conversations.
  def filter_groups
    latest_conversation = current_account.conversations.where(inbox_id: accessable_inbox_ids)
                                         .where('conversations.contact_id = contacts.id')
                                         .reorder('conversations.last_activity_at DESC').select(:display_id).limit(1)
    groups_query = current_account.contacts.where("contacts.identifier LIKE '%@g.us'")
                                  .where('contacts.name ILIKE :search OR contacts.identifier ILIKE :search', search: "%#{search_query}%")
                                  .where("EXISTS (#{latest_conversation.to_sql})")
    groups_query = apply_time_filter(groups_query, 'contacts.last_activity_at') if current_account.feature_enabled?('advanced_search')

    @groups = groups_query.select("contacts.*, (#{latest_conversation.to_sql}) AS conversation_id")
                          .order_on_last_activity_at('desc').page(params[:page]).per(15)
  end

  def filter_files
    files_query = Attachment.where(account_id: current_account.id, file_type: %i[image audio video file])
                            .joins(:message, file_attachment: :blob)
                            .where(messages: { inbox_id: accessable_inbox_ids })
                            .where('active_storage_blobs.filename ILIKE :search', search: "%#{search_query}%")
    files_query = apply_time_filter(files_query, 'attachments.created_at') if current_account.feature_enabled?('advanced_search')

    @files = files_query.includes(:message, file_attachment: :blob).reorder('attachments.created_at DESC, attachments.id DESC')
                        .page(params[:page]).per(15)
  end
end
