module ConversationLinksConcern
  # URLs shared in message text, e.g. for a conversation-level "Links" panel.
  # There's no separate Link record, so Conversation#messages_with_links
  # filters at the DB level and the view extracts the actual URL(s) per
  # message (see Message.extract_urls).
  def links
    @links_count = @conversation.messages_with_links.count
    @messages = @conversation.messages_with_links
                             .includes(:inbox, sender: { avatar_attachment: :blob })
                             .order(created_at: :desc)
                             .page(attachment_params[:page])
                             .per(ATTACHMENT_RESULTS_PER_PAGE)
  end
end
