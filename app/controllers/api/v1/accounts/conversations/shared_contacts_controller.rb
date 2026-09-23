class Api::V1::Accounts::Conversations::SharedContactsController < Api::V1::Accounts::Conversations::BaseController
  include EvolutionGoErrorHandling

  def create
    contact = Current.account.contacts.find(params[:contact_id])
    @message = Messages::SendContactService.new(conversation: @conversation, contact: contact, user: Current.user).perform
    render 'api/v1/accounts/conversations/messages/create'
  end
end
