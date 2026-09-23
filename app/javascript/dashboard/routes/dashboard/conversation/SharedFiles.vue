<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  MEDIA_TYPES,
  NON_FILE_TYPES,
} from 'dashboard/components-next/message/constants';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';
import Media from 'dashboard/components-next/SharedAttachments/Media.vue';
import Files from 'dashboard/components-next/SharedAttachments/Files.vue';
import Links from 'dashboard/components-next/SharedAttachments/Links.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const MEDIA_PEEK_LIMIT = 6;
const FILES_PEEK_LIMIT = 3;
const LINKS_PEEK_LIMIT = 3;

const { t } = useI18n();

const allAttachments = useMapGetter('getSelectedChatAttachments');
const attachmentsLoaded = useMapGetter('getSelectedChatAttachmentsLoaded');
const allLinks = useMapGetter('getSelectedChatLinks');
const linksLoaded = useMapGetter('getSelectedChatLinksLoaded');

const isLoaded = computed(() => attachmentsLoaded.value && linksLoaded.value);

const searchQuery = ref('');
const normalizedQuery = computed(() => searchQuery.value.trim().toLowerCase());

const fileNameFromUrl = url => {
  if (!url) return '';
  const name = url.split('/').pop();
  return name ? decodeURIComponent(name) : '';
};

// Media (images/audio/video) rarely has a meaningful searchable name, so the
// search only narrows Files (by filename) and Links (by URL) — it never
// hides Media results.
const filteredAttachments = computed(() => {
  if (!normalizedQuery.value) return allAttachments.value;
  return allAttachments.value.filter(
    a =>
      MEDIA_TYPES.includes(a.file_type) ||
      fileNameFromUrl(a.data_url).toLowerCase().includes(normalizedQuery.value)
  );
});

const filteredLinks = computed(() => {
  if (!normalizedQuery.value) return allLinks.value;
  return allLinks.value.filter(link =>
    link.url.toLowerCase().includes(normalizedQuery.value)
  );
});

const mediaAttachments = computed(() =>
  filteredAttachments.value
    .filter(a => MEDIA_TYPES.includes(a.file_type) && a.data_url)
    .sort((a, b) => (b.created_at || 0) - (a.created_at || 0))
);

const hasContent = computed(
  () =>
    allAttachments.value.some(
      a => a.data_url && !NON_FILE_TYPES.includes(a.file_type)
    ) || allLinks.value.length > 0
);

const hasFilteredContent = computed(
  () =>
    mediaAttachments.value.length > 0 ||
    filteredAttachments.value.some(
      a =>
        a.data_url &&
        !MEDIA_TYPES.includes(a.file_type) &&
        !NON_FILE_TYPES.includes(a.file_type)
    ) ||
    filteredLinks.value.length > 0
);

const showGallery = ref(false);
const selectedAttachment = ref(null);

const onMediaSelect = attachment => {
  selectedAttachment.value = attachment;
  showGallery.value = true;
};

const onFileSelect = attachment => {
  if (attachment.data_url) {
    window.open(attachment.data_url, '_blank', 'noopener,noreferrer');
  }
};
</script>

<template>
  <div class="p-2">
    <div v-if="!isLoaded" class="flex justify-center p-3">
      <Spinner class="size-5" />
    </div>
    <template v-else-if="!hasContent">
      <p class="p-3 text-sm text-center text-n-slate-11">
        {{ t('CONVERSATION_SIDEBAR.SHARED_FILES.EMPTY') }}
      </p>
    </template>
    <template v-else>
      <input
        v-model="searchQuery"
        type="text"
        class="w-full !mb-3"
        :placeholder="t('CONVERSATION_SIDEBAR.SHARED_FILES.SEARCH_PLACEHOLDER')"
      />
      <p
        v-if="normalizedQuery && !hasFilteredContent"
        class="p-3 text-sm text-center text-n-slate-11"
      >
        {{
          t('CONVERSATION_SIDEBAR.SHARED_FILES.SEARCH_EMPTY', {
            query: searchQuery,
          })
        }}
      </p>
      <div v-else class="flex flex-col gap-5">
        <Media
          :attachments="filteredAttachments"
          :peek-limit="MEDIA_PEEK_LIMIT"
          @select="onMediaSelect"
        />
        <Files
          :attachments="filteredAttachments"
          :peek-limit="FILES_PEEK_LIMIT"
          @select="onFileSelect"
        />
        <Links :links="filteredLinks" :peek-limit="LINKS_PEEK_LIMIT" />
      </div>
    </template>
    <GalleryView
      v-if="showGallery && selectedAttachment"
      v-model:show="showGallery"
      :attachment="selectedAttachment"
      :all-attachments="mediaAttachments"
      auto-play
      @close="showGallery = false"
    />
  </div>
</template>
