# Makes a freshly created WhatsApp group available in Chatwoot right away: the group is a contact
# identified by its JID (the same shape bridges use for groups) plus a conversation in the inbox.
class EvolutionGo::GroupConversation
  pattr_initialize [:inbox!, :jid!, :name!]

  def find_or_create
    contact_inbox = ContactInbox.find_by(contact: contact, inbox: inbox) || ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    contact_inbox.conversations.last || create_conversation(contact_inbox)
  end

  private

  def contact
    @contact ||= inbox.account.contacts.find_or_create_by!(identifier: jid) { |new_contact| new_contact.name = name }
  end

  def create_conversation(contact_inbox)
    Conversation.create!(account_id: inbox.account_id, inbox_id: inbox.id, contact_id: contact.id, contact_inbox_id: contact_inbox.id)
  end
end
