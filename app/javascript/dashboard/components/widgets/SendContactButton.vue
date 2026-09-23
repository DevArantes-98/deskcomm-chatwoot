<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const MIN_QUERY_LENGTH = 2;

const { t } = useI18n();
const store = useStore();

const showModal = ref(false);
const query = ref('');
const results = ref([]);
const selected = ref(null);
const isSearching = ref(false);
const isSending = ref(false);
let searchToken = 0;

const canSearch = computed(() => query.value.trim().length >= MIN_QUERY_LENGTH);
const emptyMessage = computed(() =>
  canSearch.value
    ? t('CONVERSATION.SEND_CONTACT.NO_RESULTS')
    : t('CONVERSATION.SEND_CONTACT.SEARCH_HINT')
);

const search = async () => {
  searchToken += 1;
  const token = searchToken;
  if (!canSearch.value) {
    results.value = [];
    isSearching.value = false;
    return;
  }
  isSearching.value = true;
  try {
    const { data } = await ContactAPI.search(query.value.trim());
    if (token === searchToken) {
      results.value = (data.payload || []).filter(
        contact => contact.phone_number
      );
    }
  } catch (error) {
    if (token === searchToken) results.value = [];
  } finally {
    if (token === searchToken) isSearching.value = false;
  }
};
const onInput = useDebounceFn(search, 300);

const open = () => {
  query.value = '';
  results.value = [];
  selected.value = null;
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
  if (!selected.value || isSending.value) return;
  isSending.value = true;
  try {
    await store.dispatch('sendContactMessage', {
      conversationId: props.conversationId,
      contactId: selected.value.id,
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
        <input
          v-model="query"
          type="search"
          class="w-full !mb-0"
          :placeholder="t('CONVERSATION.SEND_CONTACT.SEARCH_PLACEHOLDER')"
          @input="onInput"
        />
        <ul
          class="flex flex-col gap-1 p-0 m-0 overflow-y-auto list-none max-h-64"
        >
          <li
            v-if="!results.length"
            class="py-6 text-sm text-center text-n-slate-11"
          >
            {{
              isSearching
                ? t('CONVERSATION.SEND_CONTACT.SEARCHING')
                : emptyMessage
            }}
          </li>
          <li v-for="contact in results" :key="contact.id">
            <button
              type="button"
              class="flex items-center w-full gap-3 px-3 py-2 text-start rounded-lg hover:bg-n-alpha-2"
              :class="{
                'bg-n-alpha-2 outline outline-1 outline-n-brand':
                  selected?.id === contact.id,
              }"
              @click="selected = contact"
            >
              <Avatar
                :name="contact.name"
                :src="contact.thumbnail"
                :size="28"
                rounded-full
              />
              <span class="flex flex-col min-w-0">
                <span class="text-sm truncate text-n-slate-12">
                  {{ contact.name }}
                </span>
                <span class="text-xs truncate text-n-slate-11">
                  {{ contact.phone_number }}
                </span>
              </span>
            </button>
          </li>
        </ul>
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
            :disabled="!selected || isSending"
            @click="send"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
