<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import WhatsappGroupsAPI from 'dashboard/api/whatsappGroups';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ContactPicker from 'dashboard/components/widgets/ContactPicker.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const { t } = useI18n();

const group = ref(null);
const isLoading = ref(false);
const loadFailed = ref(false);
const filter = ref('');

const showAddModal = ref(false);
const toAdd = ref([]);
const isAdding = ref(false);

const removeDialog = ref(null);
const toRemove = ref(null);
const isRemoving = ref(false);

const participants = computed(() => group.value?.participants || []);
const memberPhones = computed(() =>
  participants.value.map(participant => participant.phone).filter(Boolean)
);

const label = participant =>
  participant.name || participant.phone || participant.jid.split('@')[0];

const filtered = computed(() => {
  const term = filter.value.trim().toLowerCase();
  if (!term) return participants.value;
  return participants.value.filter(participant =>
    `${label(participant)} ${participant.phone || ''}`
      .toLowerCase()
      .includes(term)
  );
});

const errorMessage = error => {
  const code = error?.response?.data?.code;
  return code
    ? t(`CONVERSATION.WHATSAPP_GROUP.ERRORS.${code}`)
    : t('CONVERSATION.WHATSAPP_GROUP.ERRORS.generic');
};

const load = async () => {
  isLoading.value = true;
  loadFailed.value = false;
  try {
    const { data } = await WhatsappGroupsAPI.show(props.conversationId);
    group.value = data;
  } catch (error) {
    group.value = null;
    loadFailed.value = true;
  } finally {
    isLoading.value = false;
  }
};

const copyInviteLink = async () => {
  try {
    const { data } = await WhatsappGroupsAPI.inviteLink(props.conversationId);
    await copyTextToClipboard(data.url);
    useAlert(t('CONVERSATION.WHATSAPP_GROUP.LINK_COPIED'));
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const openAdd = () => {
  toAdd.value = [];
  showAddModal.value = true;
};

const addParticipants = async () => {
  if (!toAdd.value.length || isAdding.value) return;
  isAdding.value = true;
  try {
    const { data } = await WhatsappGroupsAPI.addParticipants(
      props.conversationId,
      toAdd.value.map(contact => contact.id)
    );
    group.value = data;
    useAlert(t('CONVERSATION.WHATSAPP_GROUP.ADD_SUCCESS'));
    showAddModal.value = false;
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isAdding.value = false;
  }
};

const askRemove = participant => {
  toRemove.value = participant;
  removeDialog.value?.open();
};

const removeParticipant = async () => {
  if (!toRemove.value || isRemoving.value) return;
  isRemoving.value = true;
  try {
    const { data } = await WhatsappGroupsAPI.removeParticipants(
      props.conversationId,
      [toRemove.value.jid]
    );
    group.value = data;
    useAlert(t('CONVERSATION.WHATSAPP_GROUP.REMOVE_SUCCESS'));
    removeDialog.value?.close();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isRemoving.value = false;
  }
};

onMounted(load);
watch(() => props.conversationId, load);
</script>

<template>
  <div class="flex flex-col gap-3 px-1">
    <p v-if="isLoading && !group" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION.WHATSAPP_GROUP.LOADING') }}
    </p>
    <div v-else-if="loadFailed" class="flex flex-col gap-2">
      <p class="text-sm text-n-ruby-11">
        {{ t('CONVERSATION.WHATSAPP_GROUP.LOAD_ERROR') }}
      </p>
    </div>
    <template v-else-if="group">
      <p v-if="group.description" class="text-sm break-words text-n-slate-11">
        {{ group.description }}
      </p>
      <div class="flex flex-wrap gap-2">
        <NextButton
          sm
          faded
          slate
          icon="i-lucide-user-plus"
          :label="t('CONVERSATION.WHATSAPP_GROUP.ADD')"
          @click="openAdd"
        />
        <NextButton
          sm
          faded
          slate
          icon="i-lucide-link"
          :label="t('CONVERSATION.WHATSAPP_GROUP.COPY_LINK')"
          @click="copyInviteLink"
        />
      </div>
      <div class="flex items-center justify-between text-xs text-n-slate-11">
        <span>
          {{
            t('CONVERSATION.WHATSAPP_GROUP.PARTICIPANTS_COUNT', {
              count: participants.length,
            })
          }}
        </span>
      </div>
      <input
        v-model="filter"
        type="search"
        class="w-full !mb-0"
        :placeholder="t('CONVERSATION.WHATSAPP_GROUP.FILTER_PLACEHOLDER')"
      />
      <ul
        class="flex flex-col gap-1 p-0 m-0 overflow-y-auto list-none max-h-80"
      >
        <li
          v-if="!filtered.length"
          class="py-4 text-sm text-center text-n-slate-11"
        >
          {{ t('CONVERSATION.WHATSAPP_GROUP.NO_PARTICIPANTS') }}
        </li>
        <li
          v-for="participant in filtered"
          :key="participant.jid"
          class="flex items-center gap-2 px-1 py-1 rounded-lg"
        >
          <Avatar :name="label(participant)" :size="24" rounded-full />
          <span class="flex flex-col flex-1 min-w-0">
            <span class="text-sm truncate text-n-slate-12">
              {{ label(participant) }}
            </span>
            <span v-if="participant.phone" class="text-xs text-n-slate-11">
              {{ `+${participant.phone}` }}
            </span>
          </span>
          <span
            v-if="participant.admin"
            class="px-1.5 py-0.5 text-xs rounded bg-n-alpha-2 text-n-slate-11"
          >
            {{ t('CONVERSATION.WHATSAPP_GROUP.ADMIN') }}
          </span>
          <NextButton
            v-else
            v-tooltip.left="t('CONVERSATION.WHATSAPP_GROUP.REMOVE')"
            xs
            ghost
            slate
            icon="i-lucide-user-minus"
            @click="askRemove(participant)"
          />
        </li>
      </ul>
    </template>

    <Modal v-model:show="showAddModal" :on-close="() => (showAddModal = false)">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="t('CONVERSATION.WHATSAPP_GROUP.ADD_TITLE')"
          :header-content="t('CONVERSATION.WHATSAPP_GROUP.ADD_DESCRIPTION')"
        />
        <div class="flex flex-col w-full gap-3 px-8 pb-4">
          <ContactPicker
            v-model="toAdd"
            multiple
            :exclude-phones="memberPhones"
          />
          <div class="flex flex-row justify-end w-full gap-2 pt-2">
            <NextButton
              faded
              slate
              :label="t('CONVERSATION.WHATSAPP_GROUP.CANCEL')"
              @click="showAddModal = false"
            />
            <NextButton
              :label="t('CONVERSATION.WHATSAPP_GROUP.ADD_CONFIRM')"
              :is-loading="isAdding"
              :disabled="!toAdd.length || isAdding"
              @click="addParticipants"
            />
          </div>
        </div>
      </div>
    </Modal>

    <Dialog
      ref="removeDialog"
      type="alert"
      :title="t('CONVERSATION.WHATSAPP_GROUP.REMOVE_TITLE')"
      :description="
        t('CONVERSATION.WHATSAPP_GROUP.REMOVE_DESCRIPTION', {
          name: toRemove ? label(toRemove) : '',
        })
      "
      :confirm-button-label="t('CONVERSATION.WHATSAPP_GROUP.REMOVE_CONFIRM')"
      :cancel-button-label="t('CONVERSATION.WHATSAPP_GROUP.CANCEL')"
      :is-loading="isRemoving"
      @confirm="removeParticipant"
    />
  </div>
</template>
