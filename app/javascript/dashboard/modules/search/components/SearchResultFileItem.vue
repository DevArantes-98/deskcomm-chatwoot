<script setup>
import { computed } from 'vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { formatBytes } from 'shared/helpers/FileHelper';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  conversationId: {
    type: [String, Number],
    default: 0,
  },
  messageId: {
    type: Number,
    default: 0,
  },
  accountId: {
    type: [String, Number],
    default: 0,
  },
  filename: {
    type: String,
    default: '',
  },
  fileType: {
    type: String,
    default: 'file',
  },
  fileSize: {
    type: Number,
    default: 0,
  },
  dataUrl: {
    type: String,
    default: '',
  },
  contactName: {
    type: String,
    default: '',
  },
  createdAt: {
    type: Number,
    default: 0,
  },
});

const ICONS = {
  image: 'i-lucide-image',
  video: 'i-lucide-video',
  audio: 'i-lucide-audio-lines',
  file: 'i-lucide-file-text',
};

const icon = computed(() => ICONS[props.fileType] || ICONS.file);

const navigateTo = computed(() =>
  frontendURL(
    `accounts/${props.accountId}/conversations/${props.conversationId}`,
    { messageId: props.messageId }
  )
);

const details = computed(() =>
  [
    props.contactName,
    props.fileSize ? formatBytes(props.fileSize, 1) : '',
    props.createdAt ? dynamicTime(props.createdAt) : '',
  ]
    .filter(Boolean)
    .join(' · ')
);
</script>

<template>
  <div class="relative">
    <router-link :to="navigateTo">
      <CardLayout
        layout="row"
        class="[&>div]:justify-start [&>div]:px-4 [&>div]:py-3 [&>div]:items-center hover:bg-n-slate-2 dark:hover:bg-n-solid-3"
      >
        <div
          class="flex items-center justify-center flex-shrink-0 rounded-lg bg-n-alpha-2 size-8"
        >
          <Icon :icon="icon" class="text-n-slate-11 size-4" />
        </div>
        <div class="flex flex-col min-w-0 gap-0.5 ltr:pr-10 rtl:pl-10">
          <h5 class="text-sm font-medium truncate text-n-slate-12">
            {{ filename }}
          </h5>
          <span class="text-sm truncate text-n-slate-11">{{ details }}</span>
        </div>
      </CardLayout>
    </router-link>
    <a
      v-if="dataUrl"
      :href="dataUrl"
      target="_blank"
      rel="noopener noreferrer"
      class="absolute -translate-y-1/2 top-1/2 ltr:right-4 rtl:left-4 text-n-slate-11 hover:text-n-slate-12"
      :title="$t('SEARCH.OPEN_FILE')"
      @click.stop
    >
      <Icon icon="i-lucide-external-link" class="size-4" />
    </a>
  </div>
</template>
