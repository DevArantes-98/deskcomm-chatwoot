<script setup>
import { computed } from 'vue';

const props = defineProps({
  // [{ label, value, color }]
  segments: { type: Array, default: () => [] },
});

// r = 100 / (2 * PI) makes the circumference exactly 100, so dash lengths are plain percentages.
const RADIUS = 15.9155;

const total = computed(() =>
  props.segments.reduce((sum, segment) => sum + segment.value, 0)
);

const arcs = computed(() => {
  let consumed = 0;
  return props.segments.map(segment => {
    const percentage = total.value ? (segment.value / total.value) * 100 : 0;
    const arc = {
      ...segment,
      percentage,
      dash: `${percentage} ${100 - percentage}`,
      offset: 25 - consumed,
    };
    consumed += percentage;
    return arc;
  });
});
</script>

<template>
  <svg viewBox="0 0 42 42" class="w-full h-auto" role="img">
    <circle
      cx="21"
      cy="21"
      :r="RADIUS"
      fill="none"
      stroke-width="6"
      class="stroke-n-weak"
    />
    <circle
      v-for="arc in arcs"
      :key="arc.label"
      cx="21"
      cy="21"
      :r="RADIUS"
      fill="none"
      stroke-width="6"
      :stroke="arc.color"
      :stroke-dasharray="arc.dash"
      :stroke-dashoffset="arc.offset"
    >
      <title>{{ `${arc.label}: ${arc.value}` }}</title>
    </circle>
    <text
      x="21"
      y="23"
      text-anchor="middle"
      class="text-[7px] font-medium fill-n-slate-12"
    >
      {{ total }}
    </text>
  </svg>
</template>
