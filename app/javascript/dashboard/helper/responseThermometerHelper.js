/**
 * "Response thermometer": buckets how long a conversation has gone without
 * an agent reply into a small set of severity levels, so agents can spot
 * neglected conversations in the list at a glance.
 *
 * A conversation is only "waiting" while `waiting_since` is set — Chatwoot
 * already clears that field the moment an agent (or bot) replies, or the
 * conversation is resolved, so this naturally only lights up for chats that
 * genuinely need attention.
 */

export const THERMOMETER_THRESHOLDS_MINUTES = {
  green: 5,
  yellow: 15,
  orange: 45,
};

export const THERMOMETER_LEVELS = ['green', 'yellow', 'orange', 'red'];

const levelForMinutes = minutes => {
  if (minutes < THERMOMETER_THRESHOLDS_MINUTES.green) return 'green';
  if (minutes < THERMOMETER_THRESHOLDS_MINUTES.yellow) return 'yellow';
  if (minutes < THERMOMETER_THRESHOLDS_MINUTES.orange) return 'orange';
  return 'red';
};

/**
 * @param {object} chat - a conversation object (snake_case or camelCase)
 * @param {number} [now] - current time in ms epoch, injectable for tests
 * @returns {{ level: 'green'|'yellow'|'orange'|'red', minutes: number } | null}
 *   null when the conversation isn't currently waiting on a reply.
 */
export const getResponseThermometerStatus = (chat, now = Date.now()) => {
  const waitingSince = chat?.waitingSince ?? chat?.waiting_since;
  if (!waitingSince) return null;

  const waitingSinceMs =
    typeof waitingSince === 'number'
      ? waitingSince * (waitingSince < 1e12 ? 1000 : 1) // seconds vs ms epoch
      : new Date(waitingSince).getTime();
  if (Number.isNaN(waitingSinceMs)) return null;

  const minutes = Math.max(0, (now - waitingSinceMs) / 60000);
  return { level: levelForMinutes(minutes), minutes };
};
