<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ContactPicker from './ContactPicker.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const { t } = useI18n();
const store = useStore();

const showModal = ref(false);
const selected = ref([]);
const isSending = ref(false);

const open = () => {
  selected.value = [];
  showModal.value = true;
};
const close = () => {
  showModal.value = false;
};

const errorMessage = error => {
  const code = error?.response?.data?.code;
  return code
    ? t(`CONVERSATION.SEND_CONTACT.ERRORS.${code}`)
    : t('CONVERSATION.SEND_CONTACT.ERRORS.generic');
};

const send = async () => {
  if (!selected.value.length || isSending.value) return;
  isSending.value = true;
  try {
    await store.dispatch('sendContactMessage', {
      conversationId: props.conversationId,
      contactId: selected.value[0].id,
    });
    useAlert(t('CONVERSATION.SEND_CONTACT.SUCCESS'));
    close();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSending.value = false;
  }
};
</script>

<template>
  <NextButton
    v-tooltip.top-end="t('CONVERSATION.SEND_CONTACT.TOOLTIP')"
    icon="i-ph-address-book"
    slate
    faded
    sm
    @click="open"
  />
  <Modal v-model:show="showModal" :on-close="close">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('CONVERSATION.SEND_CONTACT.TITLE')"
        :header-content="t('CONVERSATION.SEND_CONTACT.DESCRIPTION')"
      />
      <div class="flex flex-col w-full gap-3 px-8 pb-4">
        <ContactPicker v-model="selected" />
        <div class="flex flex-row justify-end w-full gap-2 pt-2">
          <NextButton
            faded
            slate
            :label="t('CONVERSATION.SEND_CONTACT.CANCEL')"
            @click="close"
          />
          <NextButton
            :label="t('CONVERSATION.SEND_CONTACT.SEND')"
            :is-loading="isSending"
            :disabled="!selected.length || isSending"
            @click="send"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
