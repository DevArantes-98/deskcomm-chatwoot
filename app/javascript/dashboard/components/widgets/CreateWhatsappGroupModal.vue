<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import WhatsappGroupsAPI from 'dashboard/api/whatsappGroups';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ContactPicker from './ContactPicker.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['update:show']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const inboxes = useMapGetter('inboxes/getInboxes');
const groupInboxes = computed(() =>
  inboxes.value.filter(inbox => inbox.evolution_go_enabled)
);

const name = ref('');
const inboxId = ref(null);
const selected = ref([]);
const isCreating = ref(false);

const canCreate = computed(
  () =>
    !isCreating.value &&
    name.value.trim() !== '' &&
    !!inboxId.value &&
    selected.value.length > 0
);

watch(
  () => props.show,
  visible => {
    if (!visible) return;
    name.value = '';
    selected.value = [];
    inboxId.value = groupInboxes.value[0]?.id ?? null;
  }
);

const close = () => emit('update:show', false);

const errorMessage = error => {
  const code = error?.response?.data?.code;
  return code
    ? t(`CONVERSATION.WHATSAPP_GROUP.ERRORS.${code}`)
    : t('CONVERSATION.WHATSAPP_GROUP.ERRORS.generic');
};

const create = async () => {
  if (!canCreate.value) return;
  isCreating.value = true;
  try {
    const { data } = await WhatsappGroupsAPI.create({
      inboxId: inboxId.value,
      name: name.value.trim(),
      contactIds: selected.value.map(contact => contact.id),
    });
    if (data.failed?.length) {
      useAlert(
        t('CONVERSATION.WHATSAPP_GROUP.CREATE_PARTIAL', {
          count: data.failed.length,
        })
      );
    } else {
      useAlert(t('CONVERSATION.WHATSAPP_GROUP.CREATE_SUCCESS'));
    }
    close();
    router.push({
      name: 'inbox_conversation',
      params: {
        accountId: route.params.accountId,
        conversation_id: data.conversation_id,
      },
    });
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isCreating.value = false;
  }
};
</script>

<template>
  <Modal
    :show="show"
    :on-close="close"
    @update:show="emit('update:show', $event)"
  >
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('CONVERSATION.WHATSAPP_GROUP.CREATE_TITLE')"
        :header-content="t('CONVERSATION.WHATSAPP_GROUP.CREATE_DESCRIPTION')"
      />
      <div class="flex flex-col w-full gap-3 px-8 pb-4">
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('CONVERSATION.WHATSAPP_GROUP.NAME_LABEL') }}
          <input
            v-model="name"
            type="text"
            class="w-full !mb-0"
            :placeholder="t('CONVERSATION.WHATSAPP_GROUP.NAME_PLACEHOLDER')"
          />
        </label>
        <label
          v-if="groupInboxes.length > 1"
          class="flex flex-col gap-1 text-sm text-n-slate-12"
        >
          {{ t('CONVERSATION.WHATSAPP_GROUP.INBOX_LABEL') }}
          <select v-model="inboxId" class="w-full !mb-0">
            <option
              v-for="inbox in groupInboxes"
              :key="inbox.id"
              :value="inbox.id"
            >
              {{ inbox.name }}
            </option>
          </select>
        </label>
        <div class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('CONVERSATION.WHATSAPP_GROUP.PARTICIPANTS_LABEL') }}
          <ContactPicker v-model="selected" multiple />
        </div>
        <div class="flex flex-row justify-end w-full gap-2 pt-2">
          <NextButton
            faded
            slate
            :label="t('CONVERSATION.WHATSAPP_GROUP.CANCEL')"
            @click="close"
          />
          <NextButton
            :label="t('CONVERSATION.WHATSAPP_GROUP.CREATE_CONFIRM')"
            :is-loading="isCreating"
            :disabled="!canCreate"
            @click="create"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
