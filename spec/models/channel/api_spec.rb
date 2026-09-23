# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Api do
  # This validation happens in ApplicationRecord
  describe 'length validations' do
    let(:channel_api) { create(:channel_api) }

    context 'when it validates webhook_url length' do
      it 'valid when within limit' do
        channel_api.webhook_url = 'a' * Limits::URL_LENGTH_LIMIT
        expect(channel_api.valid?).to be true
      end

      it 'invalid when crossed the limit' do
        channel_api.webhook_url = 'a' * (Limits::URL_LENGTH_LIMIT + 1)
        channel_api.valid?
        expect(channel_api.errors[:webhook_url]).to include("is too long (maximum is #{Limits::URL_LENGTH_LIMIT} characters)")
      end
    end
  end

  describe 'Evolution Go link' do
    let(:config) { { 'url' => 'https://evo.test', 'token' => 'secret' } }
    let(:channel) { create(:channel_api, additional_attributes: { 'evolution_go' => config, 'theme' => 'dark' }) }

    it 'exposes the link only when both url and token are present' do
      expect(channel.evolution_go_config).to eq(config)

      channel.update!(additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test' } })
      expect(channel.evolution_go_config).to be_nil
    end

    it 'keeps the link out of the attributes that are shown to agents' do
      expect(channel.public_additional_attributes).to eq('theme' => 'dark')
    end

    it 'survives inbox settings updates that replace the additional attributes' do
      channel.update!(additional_attributes: { 'theme' => 'light' })

      expect(channel.reload.evolution_go_config).to eq(config)
      expect(channel.additional_attributes['theme']).to eq('light')
    end

    it 'can be removed explicitly' do
      channel.update!(additional_attributes: { 'evolution_go' => nil })

      expect(channel.reload.evolution_go_config).to be_nil
    end
  end
end
