class Api::V1::Accounts::WhatsappEditsController < Api::V1::Accounts::BaseController
  include EvolutionGoErrorHandling

  # For bridges: WhatsApp delivers a customer's edit encrypted, so the bridge forwards the raw event
  # and the stored original message and Chatwoot decrypts it and updates the message.
  def create
    @message = Messages::ApplyEncryptedEditService.new(
      account: Current.account, user: Current.user,
      edit: params.require(:edit).to_unsafe_h, original: params.require(:original).to_unsafe_h
    ).perform
    render 'api/v1/accounts/conversations/messages/update'
  end
end
