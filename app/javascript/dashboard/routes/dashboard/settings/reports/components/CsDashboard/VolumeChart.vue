<script setup>
import { computed } from 'vue';

const props = defineProps({
  data: { type: Array, default: () => [] },
  groupBy: { type: String, default: 'day' },
  createdLabel: { type: String, default: '' },
  resolvedLabel: { type: String, default: '' },
});

const WIDTH = 720;
const HEIGHT = 220;
const PAD = { left: 36, right: 8, top: 8, bottom: 24 };
const MAX_LABELS = 10;

const plotHeight = HEIGHT - PAD.top - PAD.bottom;
const slotWidth = computed(
  () => (WIDTH - PAD.left - PAD.right) / Math.max(1, props.data.length)
);
const barWidth = computed(() =>
  Math.max(2, Math.min(14, slotWidth.value * 0.4))
);

const axisMax = computed(() => {
  const highest = Math.max(
    1,
    ...props.data.flatMap(row => [row.created, row.resolved])
  );
  const magnitude = 10 ** Math.floor(Math.log10(highest));
  return Math.ceil(highest / magnitude) * magnitude;
});

const ticks = computed(() =>
  [0, 0.5, 1].map(fraction => Math.round(axisMax.value * fraction))
);

const yFor = value => PAD.top + plotHeight * (1 - value / axisMax.value);

const labelStep = computed(() =>
  Math.max(1, Math.ceil(props.data.length / MAX_LABELS))
);

const shortDate = iso => {
  const [year, month, day] = iso.split('-');
  return props.groupBy === 'month' ? `${month}/${year}` : `${day}/${month}`;
};

const bars = computed(() =>
  props.data.map((row, index) => {
    const center = PAD.left + slotWidth.value * (index + 0.5);
    return {
      key: row.date,
      label: shortDate(row.date),
      showLabel: index % labelStep.value === 0,
      center,
      created: {
        x: center - barWidth.value - 1,
        y: yFor(row.created),
        height: PAD.top + plotHeight - yFor(row.created),
        value: row.created,
      },
      resolved: {
        x: center + 1,
        y: yFor(row.resolved),
        height: PAD.top + plotHeight - yFor(row.resolved),
        value: row.resolved,
      },
    };
  })
);
</script>

<template>
  <svg :viewBox="`0 0 ${WIDTH} ${HEIGHT}`" class="w-full h-auto" role="img">
    <g v-for="tick in ticks" :key="tick">
      <line
        :x1="PAD.left"
        :x2="WIDTH - PAD.right"
        :y1="yFor(tick)"
        :y2="yFor(tick)"
        class="stroke-n-weak"
        stroke-width="1"
      />
      <text
        :x="PAD.left - 6"
        :y="yFor(tick) + 4"
        text-anchor="end"
        class="text-[10px] fill-n-slate-11"
      >
        {{ tick }}
      </text>
    </g>
    <g v-for="bar in bars" :key="bar.key">
      <rect
        :x="bar.created.x"
        :y="bar.created.y"
        :width="barWidth"
        :height="bar.created.height"
        rx="1.5"
        class="fill-n-blue-9"
      >
        <title>
          {{ `${bar.label} · ${createdLabel}: ${bar.created.value}` }}
        </title>
      </rect>
      <rect
        :x="bar.resolved.x"
        :y="bar.resolved.y"
        :width="barWidth"
        :height="bar.resolved.height"
        rx="1.5"
        class="fill-n-teal-9"
      >
        <title>
          {{ `${bar.label} · ${resolvedLabel}: ${bar.resolved.value}` }}
        </title>
      </rect>
      <text
        v-if="bar.showLabel"
        :x="bar.center"
        :y="HEIGHT - 6"
        text-anchor="middle"
        class="text-[10px] fill-n-slate-11"
      >
        {{ bar.label }}
      </text>
    </g>
  </svg>
</template>
