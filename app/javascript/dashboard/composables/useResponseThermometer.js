import { onMounted, onUnmounted, ref, toValue, watch } from 'vue';
import { getResponseThermometerStatus } from 'dashboard/helper/responseThermometerHelper';

// Coarser than the SLA composable's 60s: our buckets are only 5-15 minutes
// wide, so a chat should visibly change color reasonably soon after crossing
// a threshold while it's on screen.
const REFRESH_INTERVAL = 30000;

/**
 * Keeps a conversation's response-thermometer status (see
 * responseThermometerHelper) live-updated while the component is mounted,
 * without needing a fresh API response every time a threshold is crossed.
 */
export const useResponseThermometer = chat => {
  const timer = ref(null);
  const status = ref(null);

  const refresh = () => {
    status.value = getResponseThermometerStatus(toValue(chat));
  };

  const clearTimer = () => {
    if (timer.value) {
      clearTimeout(timer.value);
      timer.value = null;
    }
  };

  const scheduleNext = () => {
    clearTimer();
    if (!status.value) return;
    timer.value = setTimeout(() => {
      refresh();
      scheduleNext();
    }, REFRESH_INTERVAL);
  };

  const refreshAndReschedule = () => {
    refresh();
    scheduleNext();
  };

  onMounted(refreshAndReschedule);
  onUnmounted(clearTimer);
  watch(() => {
    const currentChat = toValue(chat) || {};
    return currentChat.waitingSince ?? currentChat.waiting_since;
  }, refreshAndReschedule);

  return { thermometerStatus: status };
};
