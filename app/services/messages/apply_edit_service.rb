# Records a new text for a message that was edited: by an agent through Chatwoot (Messages::EditService)
# or by the customer / the phone on WhatsApp, reported by a bridge over the API.
#
# The first text is kept in `original_content` so agents can still see what was written before the edit.
class Messages::ApplyEditService
  pattr_initialize [:message!, :content!, { edited_at: nil }]

  def perform
    raise EvolutionGo::Refused, :blank_content if content.to_s.strip.blank?
    raise EvolutionGo::Refused, :not_editable unless editable?

    message.with_lock { apply unless content == message.content }
    message
  end

  private

  def editable?
    !message.private? && !message.activity? && !message.content_attributes.to_h['deleted']
  end

  def apply
    attributes = message.content_attributes.to_h
    message.update!(
      content: content,
      content_attributes: attributes.merge(
        'edited' => true,
        'edited_at' => (edited_at || Time.current).to_i,
        'original_content' => attributes['original_content'] || message.content
      )
    )
  end
end
