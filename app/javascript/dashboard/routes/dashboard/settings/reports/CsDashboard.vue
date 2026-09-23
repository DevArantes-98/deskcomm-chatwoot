<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatTime } from '@chatwoot/utils';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  levelForMinutes,
  THERMOMETER_DOT_CLASS,
} from 'dashboard/helper/responseThermometerHelper';
import CsDashboardAPI from 'dashboard/api/csDashboard';
import ReportHeader from './components/ReportHeader.vue';
import VolumeChart from './components/CsDashboard/VolumeChart.vue';
import DonutChart from './components/CsDashboard/DonutChart.vue';

const RANGES = [7, 30, 90];
const GROUPINGS = ['day', 'week', 'month'];
const REASON_COLORS = [
  '#3b82f6',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#ec4899',
  '#14b8a6',
  '#64748b',
];

const { t } = useI18n();
const { accountId } = useAccount();
const inboxes = useMapGetter('inboxes/getInboxes');

const rangeDays = ref(30);
const groupBy = ref('day');
const inboxId = ref('');
const data = ref(null);
const isLoading = ref(false);
const hasError = ref(false);

const load = async () => {
  isLoading.value = true;
  hasError.value = false;
  const until = Math.floor(Date.now() / 1000);
  try {
    const { data: payload } = await CsDashboardAPI.get({
      since: until - rangeDays.value * 24 * 60 * 60,
      until,
      groupBy: groupBy.value,
      timezoneOffset: -new Date().getTimezoneOffset() / 60,
      inboxId: inboxId.value || undefined,
    });
    data.value = payload;
  } catch (error) {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const selectRange = days => {
  rangeDays.value = days;
  load();
};

const durationLabel = seconds =>
  seconds === null || seconds === undefined ? '-' : formatTime(seconds);

const thermometerClass = seconds =>
  seconds === null || seconds === undefined
    ? ''
    : THERMOMETER_DOT_CLASS[levelForMinutes(seconds / 60)];

const volume = computed(() => data.value?.volume || []);
const totalCreated = computed(() =>
  volume.value.reduce((sum, row) => sum + row.created, 0)
);
const totalResolved = computed(() =>
  volume.value.reduce((sum, row) => sum + row.resolved, 0)
);

const reasonSegments = computed(() =>
  (data.value?.closing_reasons || []).map((row, index) => ({
    label: row.reason || t('CS_DASHBOARD.REASONS.NO_REASON'),
    value: row.count,
    color: REASON_COLORS[index % REASON_COLORS.length],
  }))
);
const reasonsTotal = computed(() =>
  reasonSegments.value.reduce((sum, segment) => sum + segment.value, 0)
);
const percentage = value =>
  reasonsTotal.value ? Math.round((value / reasonsTotal.value) * 100) : 0;

const kpis = computed(() => [
  {
    key: 'reply',
    label: t('CS_DASHBOARD.KPI.AVG_REPLY_TIME'),
    value: durationLabel(data.value?.response_time.reply_time_avg),
    dotClass: thermometerClass(data.value?.response_time.reply_time_avg),
  },
  {
    key: 'first',
    label: t('CS_DASHBOARD.KPI.FIRST_RESPONSE'),
    value: durationLabel(data.value?.response_time.first_response_avg),
    dotClass: thermometerClass(data.value?.response_time.first_response_avg),
  },
  {
    key: 'created',
    label: t('CS_DASHBOARD.KPI.CREATED'),
    value: totalCreated.value,
  },
  {
    key: 'resolved',
    label: t('CS_DASHBOARD.KPI.RESOLVED'),
    value: totalResolved.value,
  },
  {
    key: 'dormant',
    label: t('CS_DASHBOARD.KPI.DORMANT', {
      days: data.value?.dormant.threshold_days,
    }),
    value: data.value?.dormant.total ?? 0,
  },
]);

const conversationUrl = id =>
  frontendURL(`accounts/${accountId.value}/conversations/${id}`);

onMounted(load);
</script>

<template>
  <div>
    <ReportHeader
      :header-title="t('CS_DASHBOARD.TITLE')"
      :header-description="t('CS_DASHBOARD.DESCRIPTION')"
    >
      <div class="flex flex-wrap items-center justify-end gap-2">
        <div class="flex overflow-hidden border rounded-lg border-n-weak">
          <button
            v-for="days in RANGES"
            :key="days"
            type="button"
            class="px-3 py-1.5 text-sm"
            :class="
              rangeDays === days
                ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
                : 'text-n-slate-11 hover:bg-n-alpha-1'
            "
            @click="selectRange(days)"
          >
            {{ t('CS_DASHBOARD.RANGE', { days }) }}
          </button>
        </div>
        <select
          v-model="groupBy"
          class="!mb-0 !w-auto !py-1.5 text-sm"
          @change="load"
        >
          <option v-for="option in GROUPINGS" :key="option" :value="option">
            {{ t(`CS_DASHBOARD.GROUP_BY.${option.toUpperCase()}`) }}
          </option>
        </select>
        <select
          v-model="inboxId"
          class="!mb-0 !w-auto !py-1.5 text-sm"
          @change="load"
        >
          <option value="">{{ t('CS_DASHBOARD.ALL_INBOXES') }}</option>
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
      </div>
    </ReportHeader>

    <p v-if="hasError" class="text-sm text-n-ruby-11">
      {{ t('CS_DASHBOARD.ERROR') }}
    </p>
    <woot-loading-state
      v-else-if="!data"
      :message="t('CS_DASHBOARD.LOADING')"
    />

    <div
      v-else
      class="flex flex-col gap-6"
      :class="{ 'opacity-60': isLoading }"
    >
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-5">
        <div
          v-for="kpi in kpis"
          :key="kpi.key"
          class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak"
        >
          <span class="text-sm text-n-slate-11">{{ kpi.label }}</span>
          <span
            class="flex items-center gap-2 text-xl font-medium text-n-slate-12"
          >
            <span
              v-if="kpi.dotClass"
              class="rounded-full size-2.5"
              :class="kpi.dotClass"
            />
            {{ kpi.value }}
          </span>
        </div>
      </div>

      <section class="p-4 border rounded-xl border-n-weak">
        <div class="flex items-center justify-between gap-3 mb-3">
          <h3 class="m-0 text-base font-medium text-n-slate-12">
            {{ t('CS_DASHBOARD.VOLUME.TITLE') }}
          </h3>
          <div class="flex items-center gap-4 text-sm text-n-slate-11">
            <span class="flex items-center gap-1.5">
              <span class="rounded-sm size-2.5 bg-n-blue-9" />
              {{ t('CS_DASHBOARD.VOLUME.CREATED') }}
            </span>
            <span class="flex items-center gap-1.5">
              <span class="rounded-sm size-2.5 bg-n-teal-9" />
              {{ t('CS_DASHBOARD.VOLUME.RESOLVED') }}
            </span>
          </div>
        </div>
        <VolumeChart
          :data="volume"
          :group-by="data.range.group_by"
          :created-label="t('CS_DASHBOARD.VOLUME.CREATED')"
          :resolved-label="t('CS_DASHBOARD.VOLUME.RESOLVED')"
        />
      </section>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <section class="p-4 border rounded-xl border-n-weak">
          <h3 class="mt-0 mb-3 text-base font-medium text-n-slate-12">
            {{ t('CS_DASHBOARD.REASONS.TITLE') }}
          </h3>
          <p v-if="!reasonSegments.length" class="text-sm text-n-slate-11">
            {{ t('CS_DASHBOARD.REASONS.EMPTY') }}
          </p>
          <div v-else class="flex items-center gap-6">
            <div class="w-40 shrink-0">
              <DonutChart :segments="reasonSegments" />
            </div>
            <ul class="flex flex-col flex-1 min-w-0 gap-2 p-0 m-0 list-none">
              <li
                v-for="segment in reasonSegments"
                :key="segment.label"
                class="flex items-center gap-2 text-sm"
              >
                <span
                  class="rounded-sm size-2.5 shrink-0"
                  :style="{ backgroundColor: segment.color }"
                />
                <span class="flex-1 truncate text-n-slate-12">
                  {{ segment.label }}
                </span>
                <span class="text-n-slate-11">
                  {{ `${segment.value} (${percentage(segment.value)}%)` }}
                </span>
              </li>
            </ul>
          </div>
        </section>

        <section class="p-4 border rounded-xl border-n-weak">
          <h3 class="mt-0 mb-3 text-base font-medium text-n-slate-12">
            {{ t('CS_DASHBOARD.MANAGERS.TITLE') }}
          </h3>
          <p
            v-if="!data.response_time.by_assignee.length"
            class="text-sm text-n-slate-11"
          >
            {{ t('CS_DASHBOARD.MANAGERS.EMPTY') }}
          </p>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="text-start text-n-slate-11">
                <th class="py-1 font-normal text-start">
                  {{ t('CS_DASHBOARD.MANAGERS.MANAGER') }}
                </th>
                <th class="py-1 font-normal text-start">
                  {{ t('CS_DASHBOARD.MANAGERS.REPLY_TIME') }}
                </th>
                <th class="py-1 font-normal text-start">
                  {{ t('CS_DASHBOARD.MANAGERS.FIRST_RESPONSE') }}
                </th>
                <th class="py-1 font-normal text-end">
                  {{ t('CS_DASHBOARD.MANAGERS.CONVERSATIONS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in data.response_time.by_assignee"
                :key="row.assignee_id ?? 'none'"
                class="border-t border-n-weak"
              >
                <td class="py-2 text-n-slate-12">
                  {{ row.name || t('CS_DASHBOARD.MANAGERS.NO_MANAGER') }}
                </td>
                <td class="py-2 text-n-slate-12">
                  <span class="flex items-center gap-1.5">
                    <span
                      v-if="thermometerClass(row.reply_time_avg)"
                      class="rounded-full size-2 shrink-0"
                      :class="thermometerClass(row.reply_time_avg)"
                    />
                    {{ durationLabel(row.reply_time_avg) }}
                  </span>
                </td>
                <td class="py-2 text-n-slate-11">
                  {{ durationLabel(row.first_response_avg) }}
                </td>
                <td class="py-2 text-n-slate-11 text-end">
                  {{ row.conversations }}
                </td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>

      <section class="p-4 border rounded-xl border-n-weak">
        <h3 class="mt-0 mb-1 text-base font-medium text-n-slate-12">
          {{
            t('CS_DASHBOARD.DORMANT.TITLE', {
              days: data.dormant.threshold_days,
            })
          }}
        </h3>
        <p class="mt-0 mb-3 text-sm text-n-slate-11">
          {{
            t('CS_DASHBOARD.DORMANT.SHOWING', {
              shown: data.dormant.contacts.length,
              total: data.dormant.total,
            })
          }}
        </p>
        <p v-if="!data.dormant.contacts.length" class="text-sm text-n-slate-11">
          {{ t('CS_DASHBOARD.DORMANT.EMPTY') }}
        </p>
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="text-n-slate-11">
              <th class="py-1 font-normal text-start">
                {{ t('CS_DASHBOARD.DORMANT.CUSTOMER') }}
              </th>
              <th class="py-1 font-normal text-start">
                {{ t('CS_DASHBOARD.DORMANT.PHONE') }}
              </th>
              <th class="py-1 font-normal text-start">
                {{ t('CS_DASHBOARD.MANAGERS.MANAGER') }}
              </th>
              <th class="py-1 font-normal text-end">
                {{ t('CS_DASHBOARD.DORMANT.SILENT_FOR') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="contact in data.dormant.contacts"
              :key="contact.id"
              class="border-t border-n-weak"
            >
              <td class="py-2">
                <router-link
                  :to="conversationUrl(contact.conversation_id)"
                  class="text-n-slate-12 hover:underline"
                >
                  {{ contact.name }}
                </router-link>
              </td>
              <td class="py-2 text-n-slate-11">{{ contact.phone_number }}</td>
              <td class="py-2 text-n-slate-11">
                {{
                  contact.assignee_name || t('CS_DASHBOARD.MANAGERS.NO_MANAGER')
                }}
              </td>
              <td class="py-2 text-n-slate-11 text-end">
                {{
                  t('CS_DASHBOARD.DORMANT.DAYS', {
                    count: contact.days_dormant,
                  })
                }}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </div>
</template>
