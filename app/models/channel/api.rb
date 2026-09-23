# == Schema Information
#
# Table name: channel_api
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  identifier            :string
#  secret                :string
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_channel_api_on_hmac_token  (hmac_token) UNIQUE
#  index_channel_api_on_identifier  (identifier) UNIQUE
#

class Channel::Api < ApplicationRecord
  include Channelable

  self.table_name = 'channel_api'
  EDITABLE_ATTRS = [:webhook_url, :hmac_mandatory, { additional_attributes: {} }].freeze

  has_secure_token :identifier
  has_secure_token :hmac_token
  include WebhookSecretable
  validate :ensure_valid_agent_reply_time_window
  validates :webhook_url, length: { maximum: Limits::URL_LENGTH_LIMIT }
  before_save :preserve_evolution_go_config

  def name
    'API'
  end

  # Optional link to an Evolution Go instance ({ 'url' =>, 'token' => }), used to push
  # actions like message edits straight to WhatsApp. Stored under additional_attributes.
  def evolution_go_config
    config = additional_attributes.to_h['evolution_go']
    config if config.is_a?(Hash) && config['url'].present? && config['token'].present?
  end

  # additional_attributes is serialized in the inbox API for every agent, so never include the token.
  def public_additional_attributes
    additional_attributes.to_h.except('evolution_go')
  end

  private

  # Inbox settings updates replace additional_attributes wholesale; don't let that silently drop the link.
  # Send `evolution_go: nil` explicitly to remove it.
  def preserve_evolution_go_config
    return unless additional_attributes_changed?

    previous = additional_attributes_was.to_h['evolution_go']
    additional_attributes['evolution_go'] = previous if previous.present? && !additional_attributes.key?('evolution_go')
  end

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end
end
