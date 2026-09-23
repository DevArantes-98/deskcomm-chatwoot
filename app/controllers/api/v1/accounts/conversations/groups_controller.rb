class Api::V1::Accounts::Conversations::GroupsController < Api::V1::Accounts::Conversations::BaseController
  include EvolutionGoErrorHandling

  def show
    render json: groups.info(group_jid)
  end

  def invite_link
    render json: { url: groups.invite_link(group_jid) }
  end

  def add_participants
    groups.add_participants(group_jid, EvolutionGo::Groups.phones_of(Current.account.contacts.where(id: params[:contact_ids])))
    render json: groups.info(group_jid)
  end

  def remove_participants
    groups.remove_participants(group_jid, Array(params[:participants]))
    render json: groups.info(group_jid)
  end

  private

  def groups
    @groups ||= EvolutionGo::Groups.new(inbox: @conversation.inbox)
  end

  def group_jid
    @conversation.contact.identifier.to_s
  end
end
