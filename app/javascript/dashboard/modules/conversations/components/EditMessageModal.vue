<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  conversationId: { type: Number, required: true },
  messageId: { type: Number, required: true },
  content: { type: String, default: '' },
});

const emit = defineEmits(['update:show', 'close']);

const { t } = useI18n();
const store = useStore();

const newContent = ref(props.content);
const isSaving = ref(false);

const canSave = computed(
  () =>
    !isSaving.value &&
    newContent.value.trim() !== '' &&
    newContent.value.trim() !== props.content
);

const errorMessage = error => {
  const code = error?.response?.data?.code;
  return code
    ? t(`CONVERSATION.EDIT_MESSAGE.ERRORS.${code}`)
    : t('CONVERSATION.EDIT_MESSAGE.ERRORS.generic');
};

const onClose = () => emit('close');

const save = async () => {
  isSaving.value = true;
  try {
    await store.dispatch('editMessage', {
      conversationId: props.conversationId,
      messageId: props.messageId,
      content: newContent.value,
    });
    useAlert(t('CONVERSATION.EDIT_MESSAGE.SUCCESS'));
    onClose();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <Modal
    :show="show"
    :on-close="onClose"
    @update:show="emit('update:show', $event)"
  >
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('CONVERSATION.EDIT_MESSAGE.TITLE')"
        :header-content="t('CONVERSATION.EDIT_MESSAGE.DESCRIPTION')"
      />
      <form class="flex flex-col w-full" @submit.prevent="save">
        <textarea
          v-model="newContent"
          rows="6"
          class="w-full !mb-0"
          :placeholder="t('CONVERSATION.EDIT_MESSAGE.PLACEHOLDER')"
        />
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-4">
          <NextButton
            faded
            slate
            type="reset"
            :label="t('CONVERSATION.EDIT_MESSAGE.CANCEL')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="t('CONVERSATION.EDIT_MESSAGE.SAVE')"
            :is-loading="isSaving"
            :disabled="!canSave"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
