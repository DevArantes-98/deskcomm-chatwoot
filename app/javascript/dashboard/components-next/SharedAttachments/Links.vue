<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  links: { type: Array, default: () => [] },
  peekLimit: { type: Number, default: 0 },
});

const { t } = useI18n();

const sortedLinks = computed(() =>
  [...props.links].sort((a, b) => (b.created_at || 0) - (a.created_at || 0))
);

const showAll = ref(false);
const isPeekable = computed(() => props.peekLimit > 0);

const visibleLinks = computed(() => {
  if (!isPeekable.value || showAll.value) return sortedLinks.value;
  return sortedLinks.value.slice(0, props.peekLimit);
});

const domainFor = url => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
};

const displayTime = link => {
  if (!link.created_at) return '';
  return shortTimestamp(dynamicTime(link.created_at), true);
};

const onOpenLink = url => window.open(url, '_blank', 'noopener,noreferrer');

const onCopyLink = async url => {
  try {
    await copyTextToClipboard(url);
    useAlert(t('CONVERSATION_SIDEBAR.SHARED_FILES.LINK_COPIED'));
  } catch {
    useAlert(t('CONVERSATION_SIDEBAR.SHARED_FILES.COPY_LINK_ERROR'));
  }
};
</script>

<template>
  <section v-if="sortedLinks.length" class="flex flex-col gap-2.5">
    <header class="flex items-center justify-between px-0.5">
      <h4
        class="text-xs font-semibold tracking-wider uppercase text-n-slate-11"
      >
        {{ t('CONVERSATION_SIDEBAR.SHARED_FILES.LINKS_HEADING') }}
        <span
          class="ms-1 font-medium tracking-normal normal-case text-n-slate-10"
        >
          {{ sortedLinks.length }}
        </span>
      </h4>
      <NextButton
        v-if="isPeekable && sortedLinks.length > peekLimit"
        ghost
        slate
        xs
        trailing-icon
        :icon="showAll ? 'i-lucide-chevron-up' : 'i-lucide-chevron-right'"
        :label="
          showAll
            ? t('CONVERSATION_SIDEBAR.SHARED_FILES.SHOW_LESS')
            : t('CONVERSATION_SIDEBAR.SHARED_FILES.VIEW_ALL')
        "
        @click="showAll = !showAll"
      />
    </header>
    <ul class="flex flex-col gap-0.5">
      <li
        v-for="link in visibleLinks"
        :key="`${link.message_id}-${link.url}`"
        role="button"
        tabindex="0"
        class="flex items-center gap-3 px-2 py-2 transition-colors rounded-lg cursor-pointer hover:bg-n-slate-3 group focus:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-9"
        @click="onOpenLink(link.url)"
        @keydown.enter="onOpenLink(link.url)"
        @keydown.space.prevent="onOpenLink(link.url)"
      >
        <div
          class="flex items-center justify-center rounded-lg size-9 shrink-0 bg-gradient-to-br from-n-slate-3 to-n-slate-4 ring-1 ring-inset ring-n-slate-4/40"
        >
          <span class="i-lucide-link size-4 text-n-slate-11" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium truncate text-n-slate-12 mb-1">
            {{ domainFor(link.url) }}
          </p>
          <p class="text-xs truncate text-n-slate-11">
            {{ link.url }}
            <template v-if="displayTime(link)">
              · {{ displayTime(link) }}
            </template>
          </p>
        </div>
        <div class="flex items-center gap-1">
          <NextButton
            v-tooltip.top="{
              content: t('CONVERSATION_SIDEBAR.SHARED_FILES.COPY_LINK'),
              delay: { show: 500, hide: 0 },
            }"
            ghost
            slate
            sm
            icon="i-lucide-copy"
            class="opacity-0 group-hover:opacity-100"
            :aria-label="t('CONVERSATION_SIDEBAR.SHARED_FILES.COPY_LINK')"
            @click.stop="onCopyLink(link.url)"
            @keydown.enter.stop
            @keydown.space.stop
          />
        </div>
      </li>
    </ul>
  </section>
  <template v-else />
</template>
