<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useMapGetter } from 'dashboard/composables/store';
import CreateWhatsappGroupModal from 'dashboard/components/widgets/CreateWhatsappGroupModal.vue';

const emit = defineEmits(['add', 'import', 'export']);

const { t } = useI18n();
const { checkPermissions } = usePolicy();

const inboxes = useMapGetter('inboxes/getInboxes');
const canCreateGroup = computed(() =>
  inboxes.value.some(inbox => inbox.evolution_go_enabled)
);
const showCreateGroup = ref(false);

const contactMenuItems = computed(() => [
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.ADD_CONTACT'),
    action: 'add',
    value: 'add',
    icon: 'i-lucide-plus',
  },
  ...(canCreateGroup.value
    ? [
        {
          label: t('CONVERSATION.WHATSAPP_GROUP.MENU_CREATE'),
          action: 'createGroup',
          value: 'createGroup',
          icon: 'i-lucide-users',
        },
      ]
    : []),
  ...(checkPermissions(['administrator', 'contact_manage'])
    ? [
        {
          label: t(
            'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.EXPORT_CONTACT'
          ),
          action: 'export',
          value: 'export',
          icon: 'i-lucide-upload',
        },
      ]
    : []),
  ...(checkPermissions(['administrator', 'contact_manage'])
    ? [
        {
          label: t(
            'CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.IMPORT_CONTACT'
          ),
          action: 'import',
          value: 'import',
          icon: 'i-lucide-download',
        },
      ]
    : []),
]);
const showActionsDropdown = ref(false);

const handleContactAction = ({ action }) => {
  if (action === 'add') {
    emit('add');
  } else if (action === 'import') {
    emit('import');
  } else if (action === 'export') {
    emit('export');
  } else if (action === 'createGroup') {
    showActionsDropdown.value = false;
    showCreateGroup.value = true;
  }
};
</script>

<template>
  <div v-on-clickaway="() => (showActionsDropdown = false)" class="relative">
    <Button
      icon="i-lucide-ellipsis-vertical"
      color="slate"
      variant="ghost"
      size="sm"
      :class="showActionsDropdown ? 'bg-n-alpha-2' : ''"
      @click="showActionsDropdown = !showActionsDropdown"
    />
    <DropdownMenu
      v-if="showActionsDropdown"
      :menu-items="contactMenuItems"
      class="ltr:right-0 rtl:left-0 mt-1 w-64 top-full"
      @action="handleContactAction($event)"
    />
    <CreateWhatsappGroupModal v-model:show="showCreateGroup" />
  </div>
</template>
