<script setup>
import { useMapGetter } from 'dashboard/composables/store.js';

import SearchResultSection from './SearchResultSection.vue';
import SearchResultGroupItem from './SearchResultGroupItem.vue';

defineProps({
  groups: {
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
    :title="$t('SEARCH.SECTION.GROUPS')"
    :empty="!groups.length"
    :query="query"
    :show-title="showTitle"
    :is-fetching="isFetching"
  >
    <ul v-if="groups.length" class="space-y-3 list-none">
      <li v-for="group in groups" :key="group.id">
        <SearchResultGroupItem
          :conversation-id="group.conversationId"
          :name="group.name"
          :thumbnail="group.thumbnail"
          :account-id="accountId"
          :updated-at="group.lastActivityAt"
        />
      </li>
    </ul>
  </SearchResultSection>
</template>
