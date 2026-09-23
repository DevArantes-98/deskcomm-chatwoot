<script setup>
import { useMapGetter } from 'dashboard/composables/store.js';

import SearchResultSection from './SearchResultSection.vue';
import SearchResultFileItem from './SearchResultFileItem.vue';

defineProps({
  files: {
    type: Array,
    default: () => [],
  },
  query: {
    type: String,
    default: '',
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
  showTitle: {
    type: Boolean,
    default: true,
  },
});

const accountId = useMapGetter('getCurrentAccountId');
</script>

<template>
  <SearchResultSection
    :title="$t('SEARCH.SECTION.FILES')"
    :empty="!files.length"
    :query="query"
    :show-title="showTitle"
    :is-fetching="isFetching"
  >
    <ul v-if="files.length" class="space-y-3 list-none">
      <li v-for="file in files" :key="file.id">
        <SearchResultFileItem
          :conversation-id="file.conversationId"
          :message-id="file.messageId"
          :account-id="accountId"
          :filename="file.filename"
          :file-type="file.fileType"
          :file-size="file.fileSize"
          :data-url="file.dataUrl"
          :contact-name="file.contactName"
          :created-at="file.createdAt"
        />
      </li>
    </ul>
  </SearchResultSection>
</template>
