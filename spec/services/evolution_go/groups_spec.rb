require 'rails_helper'

describe EvolutionGo::Groups do
  subject(:groups) { described_class.new(inbox: inbox) }

  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_api, account: account, additional_attributes: { 'evolution_go' => { 'url' => 'https://evo.test', 'token' => 'tok' } })
  end
  let(:inbox) { channel.inbox }
  let(:group_jid) { '120363111111111111@g.us' }

  def stub_evolution(path, body)
    stub_request(:post, "https://evo.test#{path}").to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '.group_jid?' do
    it 'recognises WhatsApp group JIDs only' do
      expect(described_class.group_jid?(group_jid)).to be true
      expect(described_class.group_jid?('5511999990001@s.whatsapp.net')).to be false
      expect(described_class.group_jid?(nil)).to be false
    end
  end

  describe '#info' do
    let!(:known) { create(:contact, account: account, name: 'Fulano de Tal', phone_number: '+5511988887777') }

    before do
      stub_evolution('/group/info', data: {
                       'JID' => group_jid, 'GroupName' => { 'Name' => 'Vendas' }, 'GroupTopic' => { 'Topic' => 'Time comercial' },
                       'Participants' => [
                         { 'JID' => '5511000000000:12@s.whatsapp.net', 'IsAdmin' => true, 'IsSuperAdmin' => true, 'DisplayName' => 'Instancia' },
                         { 'JID' => '5511988887777@s.whatsapp.net', 'IsAdmin' => false },
                         { 'JID' => '98765432101234@lid', 'PhoneNumber' => '5511977776666@s.whatsapp.net', 'DisplayName' => 'Via LID' },
                         { 'JID' => '55555555555555@lid' }
                       ]
                     })
    end

    it 'normalises the group and matches participants to contacts by phone number' do
      info = groups.info(group_jid)

      expect(info).to include(jid: group_jid, name: 'Vendas', description: 'Time comercial')
      expect(info[:participants]).to contain_exactly(
        { jid: '5511000000000:12@s.whatsapp.net', phone: '5511000000000', admin: true, display_name: 'Instancia',
          contact_id: nil, name: 'Instancia' },
        { jid: '5511988887777@s.whatsapp.net', phone: '5511988887777', admin: false, display_name: nil,
          contact_id: known.id, name: 'Fulano de Tal' },
        { jid: '98765432101234@lid', phone: '5511977776666', admin: false, display_name: 'Via LID',
          contact_id: nil, name: 'Via LID' },
        { jid: '55555555555555@lid', phone: nil, admin: false, display_name: nil, contact_id: nil, name: nil }
      )
    end

    it 'refuses JIDs that are not groups without calling WhatsApp' do
      expect { groups.info('5511999990001@s.whatsapp.net') }.to raise_error(EvolutionGo::Refused) { |error| expect(error.reason).to eq(:not_a_group) }
    end
  end

  describe '#create' do
    it 'creates the group and returns its JID, name and the participants WhatsApp could not add' do
      request = stub_evolution('/group/create', data: { 'jid' => group_jid, 'name' => 'Vendas', 'failed' => ['5511000000001@s.whatsapp.net'] })

      result = groups.create(name: '  Vendas ', phones: ['5511988887777'])

      expect(result).to eq(jid: group_jid, name: 'Vendas', failed: ['5511000000001@s.whatsapp.net'])
      expect(request).to have_been_requested
    end

    it 'requires a name and at least one participant' do
      expect { groups.create(name: ' ', phones: ['1']) }.to raise_error(EvolutionGo::Refused) { |error| expect(error.reason).to eq(:blank_name) }
      expect { groups.create(name: 'Vendas', phones: []) }.to raise_error(EvolutionGo::Refused) { |error|
        expect(error.reason).to eq(:no_participants)
      }
    end
  end

  describe 'participants and invite link' do
    it 'adds and removes participants' do
      request = stub_evolution('/group/participant', message: 'success')

      groups.add_participants(group_jid, ['5511988887777'])
      groups.remove_participants(group_jid, ['5511988887777@s.whatsapp.net'])

      expect(request).to have_been_requested.twice
      expect(a_request(:post, 'https://evo.test/group/participant').with(body: hash_including('action' => 'add'))).to have_been_made
      expect(a_request(:post, 'https://evo.test/group/participant').with(body: hash_including('action' => 'remove'))).to have_been_made
    end

    it 'refuses to change participants without any' do
      expect { groups.add_participants(group_jid, []) }.to raise_error(EvolutionGo::Refused) { |error| expect(error.reason).to eq(:no_participants) }
    end

    it 'builds the invite URL from the code' do
      stub_evolution('/group/invitelink', data: 'AbCdEf')

      expect(groups.invite_link(group_jid)).to eq('https://chat.whatsapp.com/AbCdEf')
    end
  end

  context 'when the inbox is not linked to Evolution Go' do
    let(:channel) { create(:channel_api, account: account) }

    it 'refuses every operation' do
      expect { groups.info(group_jid) }.to raise_error(EvolutionGo::Refused) { |error| expect(error.reason).to eq(:inbox_not_supported) }
      expect { groups.create(name: 'Vendas', phones: ['1']) }.to raise_error(EvolutionGo::Refused) { |error|
        expect(error.reason).to eq(:inbox_not_supported)
      }
    end
  end

  describe '.phones_of' do
    it 'keeps only the digits of contacts that have a phone number' do
      with_phone = build(:contact, phone_number: '+55 (11) 98888-7777')
      without = build(:contact, phone_number: nil)

      expect(described_class.phones_of([with_phone, without])).to eq(['5511988887777'])
    end
  end
end
