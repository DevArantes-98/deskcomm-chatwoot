class Api::V1::Accounts::WhatsappGroupsController < Api::V1::Accounts::BaseController
  include EvolutionGoErrorHandling

  def create
    inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize inbox, :show?
    contacts = Current.account.contacts.where(id: params[:contact_ids])
    group = EvolutionGo::Groups.new(inbox: inbox).create(name: params[:name], phones: EvolutionGo::Groups.phones_of(contacts))
    conversation = EvolutionGo::GroupConversation.new(inbox: inbox, jid: group[:jid], name: group[:name]).find_or_create
    render json: group.merge(conversation_id: conversation.display_id)
  end
end
