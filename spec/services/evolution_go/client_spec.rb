require 'rails_helper'

describe EvolutionGo::Client do
  subject(:client) { described_class.new(url: 'https://evo.test/', token: 'secret-token') }

  def stub_evolution(path, status: 200, body: { message: 'success' })
    stub_request(:post, "https://evo.test#{path}")
      .with(headers: { 'apikey' => 'secret-token', 'Content-Type' => 'application/json' })
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#edit_message' do
    it 'posts the new text for the message to /message/edit' do
      request = stub_evolution('/message/edit').with(
        body: { chat: '5511999990001@s.whatsapp.net', messageId: '3EB0ABC', message: 'novo texto' }.to_json
      )

      client.edit_message(chat: '5511999990001@s.whatsapp.net', message_id: '3EB0ABC', text: 'novo texto')

      expect(request).to have_been_requested
    end

    it 'raises with the status and the reason given by Evolution Go' do
      stub_evolution('/message/edit', status: 400, body: { error: 'message is too old to edit' })

      expect { client.edit_message(chat: 'x@s.whatsapp.net', message_id: '1', text: 'a') }
        .to raise_error(EvolutionGo::Error, 'Evolution Go responded 400: message is too old to edit')
    end

    it 'raises when the server cannot be reached' do
      stub_request(:post, 'https://evo.test/message/edit').to_timeout

      expect { client.edit_message(chat: 'x@s.whatsapp.net', message_id: '1', text: 'a') }.to raise_error(EvolutionGo::Error)
    end
  end

  describe '#send_contact' do
    it 'posts the vCard data and returns the WhatsApp id of the sent message' do
      request = stub_evolution('/send/contact', body: { message: 'success', data: { 'Info' => { 'ID' => '3EB0SENT' } } }).with(
        body: { number: '5511999990001@s.whatsapp.net',
                vcard: { fullName: 'Fulano', phone: '5511988887777', organization: 'ACME' } }.to_json
      )

      id = client.send_contact(number: '5511999990001@s.whatsapp.net', full_name: 'Fulano', phone: '5511988887777', organization: 'ACME')

      expect(request).to have_been_requested
      expect(id).to eq('3EB0SENT')
    end

    it 'accepts the lowercase id key and tolerates a response without one' do
      stub_evolution('/send/contact', body: { data: { 'info' => { 'id' => 'abc' } } })
      expect(client.send_contact(number: 'n', full_name: 'F', phone: '1')).to eq('abc')

      stub_evolution('/send/contact', body: { message: 'success' })
      expect(client.send_contact(number: 'n', full_name: 'F', phone: '1')).to be_nil
    end
  end

  describe 'group endpoints' do
    it 'fetches group info by group JID' do
      request = stub_evolution('/group/info', body: { data: { 'JID' => '1@g.us' } }).with(body: { groupJid: '1@g.us' }.to_json)

      expect(client.group_info(group_jid: '1@g.us')).to eq('JID' => '1@g.us')
      expect(request).to have_been_requested
    end

    it 'creates a group with participants' do
      request = stub_evolution('/group/create', body: { data: { 'jid' => '1@g.us' } })
                .with(body: { groupName: 'Vendas', participants: ['5511988887777'] }.to_json)

      expect(client.create_group(name: 'Vendas', participants: ['5511988887777'])).to eq('jid' => '1@g.us')
      expect(request).to have_been_requested
    end

    it 'updates participants with the given action' do
      request = stub_evolution('/group/participant')
                .with(body: { groupJid: '1@g.us', participants: ['5511988887777'], action: 'add' }.to_json)

      client.update_group_participants(group_jid: '1@g.us', participants: ['5511988887777'], action: 'add')

      expect(request).to have_been_requested
    end

    it 'returns the invite code without resetting the link' do
      request = stub_evolution('/group/invitelink', body: { data: 'AbCdEf' }).with(body: { groupJid: '1@g.us', reset: false }.to_json)

      expect(client.group_invite_link(group_jid: '1@g.us')).to eq('AbCdEf')
      expect(request).to have_been_requested
    end
  end
end
