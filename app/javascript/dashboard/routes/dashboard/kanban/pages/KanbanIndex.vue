<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const UNASSIGNED = '__unassigned__';

// The "account manager" for a client is the same person Chatwoot already
// tracks as the conversation's assignee, so the board is keyed off that
// instead of a separate custom attribute.
const agents = useMapGetter('agents/getVerifiedAgents');
const agentUiFlags = useMapGetter('agents/getUIFlags');

const conversations = ref([]);
const isLoadingConversations = ref(false);
const columns = ref({});

const isLoading = computed(
  () => agentUiFlags.value.isFetching || isLoadingConversations.value
);

const columnOrder = computed(() => [
  ...agents.value.map(agent => String(agent.id)),
  UNASSIGNED,
]);

const agentById = computed(() => {
  const map = {};
  agents.value.forEach(agent => {
    map[agent.id] = agent;
  });
  return map;
});

const columnLabel = key => {
  if (key === UNASSIGNED) return t('KANBAN.UNASSIGNED_COLUMN');
  return agentById.value[key]?.name || key;
};

const fetchAllConversations = async () => {
  isLoadingConversations.value = true;
  const all = [];
  let page = 1;
  let totalCount = Infinity;
  try {
    while (all.length < totalCount && page <= 100) {
      // eslint-disable-next-line no-await-in-loop
      const { data: { data } = {} } = await ConversationAPI.get({
        status: 'open',
        page,
      });
      const payload = data.payload || [];
      if (!payload.length) break;
      all.push(...payload);
      totalCount = data.meta?.all_count ?? all.length;
      page += 1;
    }
    conversations.value = all;
  } catch (error) {
    useAlert(t('KANBAN.FETCH_CONVERSATIONS_ERROR'));
  } finally {
    isLoadingConversations.value = false;
  }
};

const buildColumns = () => {
  const cols = {};
  columnOrder.value.forEach(key => {
    cols[key] = [];
  });
  conversations.value.forEach(conversation => {
    const assignee = conversation.meta?.assignee;
    const key =
      assignee && conversation.meta?.assignee_type === 'User'
        ? String(assignee.id)
        : UNASSIGNED;
    if (cols[key] === undefined) cols[key] = [];
    cols[key].push(conversation);
  });
  columns.value = cols;
};

const onColumnChange = async (event, columnKey) => {
  const moved = event.added;
  if (!moved) return;
  const conversation = moved.element;
  const agentId = columnKey === UNASSIGNED ? null : Number(columnKey);
  try {
    await store.dispatch('assignAgent', {
      conversationId: conversation.id,
      agentId,
      assigneeType: 'User',
    });
  } catch (error) {
    useAlert(t('KANBAN.UPDATE_ASSIGNEE_ERROR'));
    // Revert the optimistic UI move by refetching, since the card was
    // already moved locally before the API response came back.
    fetchAllConversations().then(buildColumns);
  }
};

const openConversation = conversation => {
  router.push({
    path: frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: conversation.id,
      })
    ),
  });
};

onMounted(async () => {
  await store.dispatch('agents/get');
  await fetchAllConversations();
  buildColumns();
});
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden">
    <div
      class="flex items-center justify-between gap-4 px-4 py-3 border-b border-n-weak"
    >
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ $t('KANBAN.TITLE') }}
      </h1>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner :size="32" />
    </div>

    <div
      v-else-if="!agents.length"
      class="flex flex-col items-center justify-center flex-1 gap-2 p-6 text-center"
    >
      <p class="text-n-slate-11">
        {{ $t('KANBAN.NO_AGENTS') }}
      </p>
      <router-link
        :to="{ name: 'agent_list' }"
        class="text-n-brand hover:underline"
      >
        {{ $t('KANBAN.GO_TO_SETTINGS') }}
      </router-link>
    </div>

    <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto">
      <div
        v-for="columnKey in columnOrder"
        :key="columnKey"
        class="flex flex-col w-72 min-w-[18rem] bg-n-solid-2 rounded-xl"
      >
        <div
          class="flex items-center gap-2 px-3 py-2 text-sm font-medium border-b border-n-weak text-n-slate-12"
        >
          <Avatar
            v-if="columnKey !== UNASSIGNED"
            :src="agentById[columnKey]?.thumbnail"
            :name="columnLabel(columnKey)"
            :size="20"
          />
          <span class="flex-1 truncate">{{ columnLabel(columnKey) }}</span>
          <span class="text-n-slate-10">{{
            (columns[columnKey] || []).length
          }}</span>
        </div>
        <Draggable
          :list="columns[columnKey]"
          class="flex flex-col flex-1 gap-2 p-2 overflow-y-auto min-h-[4rem]"
          group="kanban-conversations"
          item-key="id"
          :data-column="columnKey"
          @change="event => onColumnChange(event, columnKey)"
        >
          <template #item="{ element: conversation }">
            <button
              type="button"
              class="flex items-center w-full gap-2 p-2 text-left bg-n-solid-1 border rounded-lg shadow-sm cursor-grab border-n-weak hover:border-n-brand"
              @click="openConversation(conversation)"
            >
              <Avatar
                :src="conversation.meta?.sender?.thumbnail"
                :name="conversation.meta?.sender?.name"
                :size="24"
              />
              <div class="flex-1 min-w-0">
                <p class="text-sm truncate text-n-slate-12">
                  {{ conversation.meta?.sender?.name }}
                </p>
                <p
                  v-if="
                    conversation.meta?.sender?.email ||
                    conversation.meta?.sender?.phone_number
                  "
                  class="text-xs truncate text-n-slate-10"
                >
                  {{
                    conversation.meta?.sender?.email ||
                    conversation.meta?.sender?.phone_number
                  }}
                </p>
              </div>
            </button>
          </template>
        </Draggable>
      </div>
    </div>
  </div>
</template>
