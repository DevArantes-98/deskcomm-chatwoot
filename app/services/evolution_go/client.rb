# Thin client for an Evolution Go instance (https://github.com/evolution-foundation/evolution-go).
# Configured per API inbox via Channel::Api#evolution_go_config ({ 'url' =>, 'token' => }),
# where the token is the *instance* token sent in the `apikey` header.
class EvolutionGo::Client
  TIMEOUT_SECONDS = 10

  def initialize(url:, token:)
    @url = url.to_s.chomp('/')
    @token = token
  end

  # Only text messages sent by this instance can be edited, and only shortly after sending.
  def edit_message(chat:, message_id:, text:)
    post('/message/edit', chat: chat, messageId: message_id, message: text)
  end

  # `number` accepts a phone number or a full JID (contact `...@s.whatsapp.net`, group `...@g.us`).
  # Returns the WhatsApp id of the message that was sent.
  def send_contact(number:, full_name:, phone:, organization: nil)
    response = post('/send/contact', number: number, vcard: { fullName: full_name, phone: phone, organization: organization.to_s })
    sent_message_id(response)
  end

  private

  # Evolution Go serialises whatsmeow's MessageInfo as-is, so the id key is "ID" (older builds: "id").
  def sent_message_id(response)
    info = response.is_a?(Hash) ? response.dig('data', 'Info') || response.dig('data', 'info') : nil
    info.is_a?(Hash) ? (info['ID'] || info['id']) : nil
  end

  def post(path, body)
    response = HTTParty.post(
      "#{@url}#{path}",
      headers: { 'Content-Type' => 'application/json', 'apikey' => @token },
      body: body.to_json,
      timeout: TIMEOUT_SECONDS
    )
    raise EvolutionGo::Error, error_message(response) unless response.success?

    response.parsed_response
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    raise EvolutionGo::Error, e.message
  end

  def error_message(response)
    parsed = response.parsed_response
    detail = parsed.is_a?(Hash) ? (parsed['error'] || parsed['message']) : nil
    "Evolution Go responded #{response.code}#{": #{detail}" if detail.present?}"
  end
end
