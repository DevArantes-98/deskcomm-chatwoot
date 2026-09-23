import { canEditMessage, EDIT_WINDOW_SECONDS } from '../messageEditHelper';

describe('messageEditHelper', () => {
  const now = 1_800_000_000;
  const editable = {
    isOutgoing: true,
    isPrivate: false,
    isText: true,
    hasAttachments: false,
    isDeleted: false,
    sourceId: 'WAID:3EB0ABC123',
    createdAt: now - 60,
    isOwnMessage: true,
    isAdmin: false,
    inboxSupportsEdit: true,
    now,
  };

  it('offers editing for a recent text message the agent sent on a linked inbox', () => {
    expect(canEditMessage(editable)).toBe(true);
  });

  it('accepts WhatsApp ids stored with or without the WAID prefix', () => {
    expect(canEditMessage({ ...editable, sourceId: '3EB0ABC123' })).toBe(true);
  });

  it.each([
    ['incoming', { isOutgoing: false }],
    ['private notes', { isPrivate: true }],
    ['non text', { isText: false }],
    ['with attachments', { hasAttachments: true }],
    ['deleted', { isDeleted: true }],
    ['without a WhatsApp id', { sourceId: '' }],
    ['on inboxes without Evolution Go', { inboxSupportsEdit: false }],
  ])('does not offer editing for %s messages', (_, override) => {
    expect(canEditMessage({ ...editable, ...override })).toBe(false);
  });

  it('only lets administrators edit messages sent by someone else', () => {
    const others = { ...editable, isOwnMessage: false };

    expect(canEditMessage(others)).toBe(false);
    expect(canEditMessage({ ...others, isAdmin: true })).toBe(true);
  });

  it('stops offering editing once the WhatsApp window has passed', () => {
    expect(
      canEditMessage({ ...editable, createdAt: now - EDIT_WINDOW_SECONDS })
    ).toBe(true);
    expect(
      canEditMessage({ ...editable, createdAt: now - EDIT_WINDOW_SECONDS - 1 })
    ).toBe(false);
  });
});
