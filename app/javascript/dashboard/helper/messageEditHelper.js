// Mirrors the checks in Messages::EditService (the backend is the source of truth;
// this only decides whether to *offer* the "Edit" action).
export const EDIT_WINDOW_SECONDS = 15 * 60; // WhatsApp only allows editing shortly after sending
export const WHATSAPP_ID_PREFIX = 'WAID:';

export const canEditMessage = ({
  isOutgoing,
  isPrivate,
  isText,
  hasAttachments,
  isDeleted,
  sourceId,
  createdAt,
  isOwnMessage,
  isAdmin,
  inboxSupportsEdit,
  now = Date.now() / 1000,
}) =>
  isOutgoing &&
  !isPrivate &&
  isText &&
  !hasAttachments &&
  !isDeleted &&
  inboxSupportsEdit &&
  (isOwnMessage || isAdmin) &&
  String(sourceId || '').startsWith(WHATSAPP_ID_PREFIX) &&
  now - createdAt <= EDIT_WINDOW_SECONDS;
