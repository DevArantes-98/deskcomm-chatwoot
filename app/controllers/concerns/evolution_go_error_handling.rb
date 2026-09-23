module EvolutionGoErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from EvolutionGo::Refused do |e|
      render json: { error: e.message, code: e.reason }, status: :unprocessable_entity
    end

    rescue_from EvolutionGo::Error do |e|
      render json: { error: e.message, code: :whatsapp_error }, status: :bad_gateway
    end
  end
end
