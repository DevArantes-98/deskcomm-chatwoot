require 'rails_helper'

describe Messages::ApplyEditService do
  let(:account) { create(:account) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Reuniao as 10h')
  end

  def apply(content, **)
    described_class.new(message: message, content: content, **).perform
  end

  def refusal_reason
    yield
  rescue EvolutionGo::Refused => e
    e.reason
  end

  it 'saves the new text, marks the message as edited and keeps the original text' do
    apply('Reuniao as 11h', edited_at: Time.zone.at(1_800_000_000))

    expect(message.reload.content).to eq('Reuniao as 11h')
    expect(message.content_attributes).to include('edited' => true, 'edited_at' => 1_800_000_000, 'original_content' => 'Reuniao as 10h')
  end

  it 'uses the current time when the edit time is not given' do
    apply('Reuniao as 11h')

    expect(message.reload.content_attributes['edited_at']).to be_within(5).of(Time.current.to_i)
  end

  it 'keeps the very first text across several edits' do
    apply('Reuniao as 11h')
    apply('Reuniao as 12h')

    expect(message.reload.content).to eq('Reuniao as 12h')
    expect(message.content_attributes['original_content']).to eq('Reuniao as 10h')
  end

  it 'does nothing when the text did not change, so repeated edit events are harmless' do
    expect { apply('Reuniao as 10h') }.not_to(change { message.reload.updated_at })
    expect(message.content_attributes).not_to include('edited')
  end

  it 'works for outgoing messages and keeps other content attributes' do
    message.update!(message_type: :outgoing, content_attributes: { 'in_reply_to' => 5 })

    apply('Reuniao as 11h')

    expect(message.reload.content_attributes).to include('in_reply_to' => 5, 'edited' => true)
  end

  it 'allows editing the caption of a message with an attachment' do
    attachment = message.attachments.new(account: account, file_type: :file)
    attachment.file.attach(io: StringIO.new('content'), filename: 'a.pdf', content_type: 'application/pdf')
    attachment.save!

    apply('Legenda nova')

    expect(message.reload.content).to eq('Legenda nova')
  end

  it 'refuses a blank text' do
    expect(refusal_reason { apply('  ') }).to eq(:blank_content)
    expect(message.reload.content).to eq('Reuniao as 10h')
  end

  it 'refuses private notes, activity messages and deleted messages' do
    message.update!(private: true)
    expect(refusal_reason { apply('novo') }).to eq(:not_editable)

    message.update!(private: false, message_type: :activity)
    expect(refusal_reason { apply('novo') }).to eq(:not_editable)

    message.update!(message_type: :incoming, content_attributes: { 'deleted' => true })
    expect(refusal_reason { apply('novo') }).to eq(:not_editable)
  end
end
