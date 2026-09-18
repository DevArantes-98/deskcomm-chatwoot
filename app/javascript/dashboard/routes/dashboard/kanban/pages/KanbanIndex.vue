<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ContactAPI from 'dashboard/api/contacts';

const { t } = useI18n();
const store = useStore();

const UNASSIGNED = '__unassigned__';

const contactAttributes = useMapGetter('attributes/getContactAttributes');
const attributeUiFlags = useMapGetter('attributes/getUIFlags');

const selectedAttributeKey = ref('');
const contacts = ref([]);
const isLoadingContacts = ref(false);
const columns = ref({});

const listAttributes = computed(() =>
  (contactAttributes.value || []).filter(
    attribute => attribute.attributeDisplayType === 'list'
  )
);

const selectedAttribute = computed(() =>
  listAttributes.value.find(
    attribute => attribute.attributeKey === selectedAttributeKey.value
  )
);

const isLoading = computed(
  () => attributeUiFlags.value.isFetching || isLoadingContacts.value
);

const columnOrder = computed(() => {
  const attr = selectedAttribute.value;
  if (!attr) return [];
  return [...(attr.attributeValues || []), UNASSIGNED];
});

const columnLabel = key => {
  if (key === UNASSIGNED) return t('KANBAN.UNASSIGNED_COLUMN');
  return key;
};

const fetchAllContacts = async () => {
  isLoadingContacts.value = true;
  const all = [];
  let page = 1;
  let totalCount = Infinity;
  try {
    while (all.length < totalCount && page <= 100) {
      // eslint-disable-next-line no-await-in-loop
      const { data } = await ContactAPI.get(page);
      const payload = data.payload || [];
      if (!payload.length) break;
      all.push(...payload);
      totalCount = data.meta?.count ?? all.length;
      page += 1;
    }
    contacts.value = all;
  } catch (error) {
    useAlert(t('KANBAN.FETCH_CONTACTS_ERROR'));
  } finally {
    isLoadingContacts.value = false;
  }
};

const buildColumns = () => {
  const attr = selectedAttribute.value;
  if (!attr) {
    columns.value = {};
    return;
  }
  const cols = {};
  (attr.attributeValues || []).forEach(value => {
    cols[value] = [];
  });
  cols[UNASSIGNED] = [];
  contacts.value.forEach(contact => {
    const value = contact.custom_attributes
      ? contact.custom_attributes[attr.attributeKey]
      : undefined;
    if (value && cols[value] !== undefined) {
      cols[value].push(contact);
    } else {
      cols[UNASSIGNED].push(contact);
    }
  });
  columns.value = cols;
};

const onColumnChange = async (event, columnKey) => {
  const moved = event.added;
  if (!moved) return;
  const contact = moved.element;
  const attr = selectedAttribute.value;
  if (!attr) return;
  try {
    if (columnKey === UNASSIGNED) {
      await ContactAPI.destroyCustomAttributes(contact.id, [
        attr.attributeKey,
      ]);
    } else {
      await ContactAPI.update(contact.id, {
        custom_attributes: { [attr.attributeKey]: columnKey },
      });
    }
  } catch (error) {
    useAlert(t('KANBAN.UPDATE_CONTACT_ERROR'));
    // Reverte a coluna local buscando os dados de novo, já que a UI já
    // moveu o card antes da resposta da API chegar.
    fetchAllContacts().then(buildColumns);
  }
};

watch(selectedAttributeKey, buildColumns);
watch(contacts, buildColumns);

onMounted(async () => {
  await store.dispatch('attributes/get');
  if (listAttributes.value.length) {
    selectedAttributeKey.value = listAttributes.value[0].attributeKey;
  }
  await fetchAllContacts();
  buildColumns();
});
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden">
    <div
      class="flex items-center justify-between gap-4 px-4 py-3 border-b border-n-weak"
    >
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ $t('KANBAN.TITLE') }}
      </h1>
      <select
        v-if="listAttributes.length"
        v-model="selectedAttributeKey"
        class="max-w-xs !mb-0"
      >
        <option
          v-for="attribute in listAttributes"
          :key="attribute.attributeKey"
          :value="attribute.attributeKey"
        >
          {{ attribute.attributeDisplayName }}
        </option>
      </select>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner size="large" />
    </div>

    <div
      v-else-if="!listAttributes.length"
      class="flex flex-col items-center justify-center flex-1 gap-2 p-6 text-center"
    >
      <p class="text-n-slate-11">
        {{ $t('KANBAN.NO_LIST_ATTRIBUTE') }}
      </p>
      <router-link
        :to="{ name: 'attributes_list' }"
        class="text-n-brand hover:underline"
      >
        {{ $t('KANBAN.GO_TO_SETTINGS') }}
      </router-link>
    </div>

    <div v-else class="flex flex-1 gap-4 p-4 overflow-x-auto">
      <div
        v-for="columnKey in columnOrder"
        :key="columnKey"
        class="flex flex-col w-72 min-w-[18rem] bg-n-solid-2 rounded-xl"
      >
        <div
          class="flex items-center justify-between px-3 py-2 text-sm font-medium border-b border-n-weak text-n-slate-12"
        >
          <span>{{ columnLabel(columnKey) }}</span>
          <span class="text-n-slate-10">{{
            (columns[columnKey] || []).length
          }}</span>
        </div>
        <Draggable
          :list="columns[columnKey]"
          class="flex flex-col flex-1 gap-2 p-2 overflow-y-auto min-h-[4rem]"
          group="kanban-contacts"
          item-key="id"
          :data-column="columnKey"
          @change="event => onColumnChange(event, columnKey)"
        >
          <template #item="{ element: contact }">
            <router-link
              :to="{
                name: 'contacts_edit',
                params: { contactId: contact.id },
              }"
              class="flex items-center gap-2 p-2 bg-n-solid-1 border rounded-lg shadow-sm cursor-grab border-n-weak hover:border-n-brand"
            >
              <Avatar :src="contact.thumbnail" :name="contact.name" :size="24" />
              <div class="flex-1 min-w-0">
                <p class="text-sm truncate text-n-slate-12">
                  {{ contact.name }}
                </p>
                <p
                  v-if="contact.email || contact.phone_number"
                  class="text-xs truncate text-n-slate-10"
                >
                  {{ contact.email || contact.phone_number }}
                </p>
              </div>
            </router-link>
          </template>
        </Draggable>
      </div>
    </div>
  </div>
</template>
