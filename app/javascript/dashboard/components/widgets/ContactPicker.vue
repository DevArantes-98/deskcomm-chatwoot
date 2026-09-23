<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import ContactAPI from 'dashboard/api/contacts';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  multiple: { type: Boolean, default: false },
  // Phone numbers (digits only) that must not be offered again, e.g. people already in a group.
  excludePhones: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const MIN_QUERY_LENGTH = 2;

const { t } = useI18n();

const query = ref('');
const results = ref([]);
const isSearching = ref(false);
let searchToken = 0;

const digitsOf = contact =>
  String(contact.phone_number || '').replace(/\D/g, '');
const isSelected = contact => props.modelValue.some(c => c.id === contact.id);

const canSearch = computed(() => query.value.trim().length >= MIN_QUERY_LENGTH);
const emptyMessage = computed(() => {
  if (isSearching.value) return t('CONVERSATION.CONTACT_PICKER.SEARCHING');
  return canSearch.value
    ? t('CONVERSATION.CONTACT_PICKER.NO_RESULTS')
    : t('CONVERSATION.CONTACT_PICKER.SEARCH_HINT');
});

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
    if (token !== searchToken) return;
    results.value = (data.payload || []).filter(
      contact =>
        contact.phone_number && !props.excludePhones.includes(digitsOf(contact))
    );
  } catch (error) {
    if (token === searchToken) results.value = [];
  } finally {
    if (token === searchToken) isSearching.value = false;
  }
};
const onInput = useDebounceFn(search, 300);

const toggle = contact => {
  if (!props.multiple) {
    emit('update:modelValue', [contact]);
    return;
  }
  emit(
    'update:modelValue',
    isSelected(contact)
      ? props.modelValue.filter(c => c.id !== contact.id)
      : [...props.modelValue, contact]
  );
};
</script>

<template>
  <div class="flex flex-col w-full gap-3">
    <input
      v-model="query"
      type="search"
      class="w-full !mb-0"
      :placeholder="t('CONVERSATION.CONTACT_PICKER.SEARCH_PLACEHOLDER')"
      @input="onInput"
    />
    <div v-if="multiple && modelValue.length" class="flex flex-wrap gap-1">
      <button
        v-for="contact in modelValue"
        :key="contact.id"
        type="button"
        class="flex items-center gap-1 px-2 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-12"
        @click="toggle(contact)"
      >
        {{ contact.name }}
        <span class="i-lucide-x size-3" />
      </button>
    </div>
    <ul class="flex flex-col gap-1 p-0 m-0 overflow-y-auto list-none max-h-64">
      <li
        v-if="!results.length"
        class="py-6 text-sm text-center text-n-slate-11"
      >
        {{ emptyMessage }}
      </li>
      <li v-for="contact in results" :key="contact.id">
        <button
          type="button"
          class="flex items-center w-full gap-3 px-3 py-2 text-start rounded-lg hover:bg-n-alpha-2"
          :class="{
            'bg-n-alpha-2 outline outline-1 outline-n-brand':
              isSelected(contact),
          }"
          @click="toggle(contact)"
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
  </div>
</template>
