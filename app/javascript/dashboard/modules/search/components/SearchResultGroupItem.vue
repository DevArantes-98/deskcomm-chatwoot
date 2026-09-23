<script setup>
import { computed } from 'vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { dynamicTime } from 'shared/helpers/timeHelper';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  conversationId: {
    type: [String, Number],
    default: 0,
  },
  name: {
    type: String,
    default: '',
  },
  thumbnail: {
    type: String,
    default: '',
  },
  accountId: {
    type: [String, Number],
    default: 0,
  },
  updatedAt: {
    type: Number,
    default: 0,
  },
});

const navigateTo = computed(() =>
  frontendURL(
    `accounts/${props.accountId}/conversations/${props.conversationId}`
  )
);

const updatedAtTime = computed(() =>
  props.updatedAt ? dynamicTime(props.updatedAt) : ''
);
</script>

<template>
  <router-link :to="navigateTo">
    <CardLayout
      layout="row"
      class="[&>div]:justify-start [&>div]:px-4 [&>div]:py-3 [&>div]:items-center hover:bg-n-slate-2 dark:hover:bg-n-solid-3"
    >
      <Avatar
        :name="name"
        :src="thumbnail"
        :size="24"
        rounded-full
        class="flex-shrink-0"
      />
      <div class="flex items-center justify-between w-full min-w-0 gap-2">
        <h5 class="py-1 text-sm font-medium truncate text-n-slate-12">
          {{ name }}
        </h5>
        <span
          v-if="updatedAtTime"
          class="min-w-0 text-sm font-normal truncate text-n-slate-11"
        >
          {{ $t('SEARCH.UPDATED_AT', { time: updatedAtTime }) }}
        </span>
      </div>
    </CardLayout>
  </router-link>
</template>
