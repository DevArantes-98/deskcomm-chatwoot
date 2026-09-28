# Applies to a Chatwoot message the edit a customer made on WhatsApp, given the raw pieces a bridge
# has at hand: the `messages.upsert` event carrying the encrypted edit (`edit`) and the stored copy
# of the original message (`original`, Evolution's /chat/findMessages record), which holds the
# secret needed to decrypt it.
class Messages::ApplyEncryptedEditService
  API_CHANNEL = 'Channel::Api'.freeze
  USER_JID = /@(s\.whatsapp\.net|lid|hosted|hosted\.lid)\z/
  KEY_JID_FIELDS = %w[participant participantAlt remoteJid remoteJidAlt].freeze

  pattr_initialize [:account!, :user!, { edit: {}, original: {} }]

  def perform
    envelope = edit_data.dig('message', 'secretEncryptedMessage')
    raise EvolutionGo::Refused, :not_an_edit unless message_edit?(envelope)

    target = find_message(envelope.dig('targetMessageKey', 'id'))
    Messages::ApplyEditService.new(message: target, **decrypt(envelope)).perform
  end

  private

  # Bridges may hand over the whole webhook body / findMessages response instead of the inner object.
  def edit_data
    @edit_data ||= edit['key'].blank? && edit['data'].is_a?(Hash) ? edit['data'] : edit
  end

  def original_data
    @original_data ||= original.dig('messages', 'records', 0) || original
  end

  def message_edit?(envelope)
    return false unless envelope.is_a?(Hash) && envelope.dig('targetMessageKey', 'id').present?

    [nil, 2, 'MESSAGE_EDIT'].include?(envelope['secretEncType'])
  end

  def find_message(whatsapp_id)
    account.messages.joins(:inbox).where(inboxes: { channel_type: API_CHANNEL })
           .where(inbox_id: user.assigned_inboxes.select(:id))
           .where(source_id: [whatsapp_id, EvolutionGo::WhatsappId.to_source_id(whatsapp_id)])
           .reorder(:id).first!
  end

  def decrypt(envelope)
    editors = jids(edit_data['key'])
    Messages::EncryptedEditDecryptor.new(
      enc_payload: envelope['encPayload'], enc_iv: envelope['encIv'],
      message_secret: original_data.dig('message', 'messageContextInfo', 'messageSecret'),
      original_id: envelope.dig('targetMessageKey', 'id'),
      sender_jids: (jids(envelope['targetMessageKey']) + jids(original_data['key']) + editors).uniq, editor_jids: editors
    ).perform
  end

  def jids(key)
    return [] unless key.is_a?(Hash)

    KEY_JID_FIELDS.filter_map { |field| normalize(key[field]) }.uniq
  end

  # Drops the device part ("5511999990000:12@s.whatsapp.net") and keeps only user JIDs, not groups.
  def normalize(jid)
    normalized = jid.to_s.sub(/:\d+@/, '@').sub('@c.us', '@s.whatsapp.net')
    normalized if normalized.match?(USER_JID)
  end
end
