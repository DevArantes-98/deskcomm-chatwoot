# Raised when Chatwoot itself refuses to call Evolution Go (permission, missing data, expired
# window...). `reason` is a stable code the frontend maps to a translated message.
class EvolutionGo::Refused < StandardError
  attr_reader :reason

  def initialize(reason)
    @reason = reason
    super(reason.to_s)
  end
end
