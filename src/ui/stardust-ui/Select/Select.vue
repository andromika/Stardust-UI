<template lang="pug">
.st-select(
  ref="rootRef"
  :class="[rootClasses, attrs.class]"
  v-bind="attrs"
)
  label.st-select__label(v-if="label" :for="triggerId") {{ label }}
  button.st-select__trigger(
    ref="triggerRef"
    type="button"
    :id="triggerId"
    :disabled="disabled"
    :aria-haspopup="'listbox'"
    :aria-expanded="open"
    :aria-label="triggerAriaLabel"
    @click.stop="toggle"
    @keydown.down.prevent="openAndFocusNext"
    @keydown.up.prevent="openAndFocusPrev"
    @keydown.enter.prevent="onEnter"
    @keydown.escape.prevent="close"
  )
    template(v-if="selectedOption")
      slot(name="selected-option" :option="selectedOption")
        span.st-select__name {{ selectedOption.label }}
    span.st-select__placeholder(v-else) {{ placeholder }}
    span.st-select__chevron(aria-hidden="true")
  Teleport(to="body")
    ul.st-select__list.st-select__list--floating(
      v-show="open"
      ref="listRef"
      role="listbox"
      :aria-labelledby="triggerId"
      :style="menuStyle"
      tabindex="-1"
    )
      li.st-select__option(
        v-for="(opt, idx) in options"
        :key="String(opt.value)"
        :ref="(el) => setOptionRef(el, idx)"
        role="option"
        :aria-selected="isSelected(opt)"
        :class="optionClasses(opt, idx)"
        @click="select(opt)"
        @mouseenter="focusedIndex = idx"
      )
        slot(name="option" :option="opt")
          span.st-select__name {{ opt.label }}
  .st-select__error(v-if="error" role="alert") {{ error }}
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUnmounted, useAttrs } from 'vue';
import './Select.scss';

defineOptions({ inheritAttrs: false });
const attrs = useAttrs();

export interface SelectOption {
  value: string | number;
  label: string;
  [key: string]: unknown;
}

const props = withDefaults(
  defineProps<{
    modelValue?: string | number;
    options?: SelectOption[];
    placeholder?: string;
    label?: string;
    disabled?: boolean;
    /** solid = accent border always · ghost = muted border, accent on focus/open */
    variant?: 'solid' | 'ghost';
    size?: 'sm' | 'md';
    error?: string;
    listMaxHeight?: string;
    triggerAriaLabel?: string;
  }>(),
  {
    options: () => [],
    placeholder: 'Select...',
    variant: 'solid',
    size: 'md',
    listMaxHeight: '40vh',
    triggerAriaLabel: 'Select option',
  }
);

const emit = defineEmits<{
  'update:modelValue': [value: string | number];
}>();

const triggerId = computed(() => `st-select-${Math.random().toString(36).slice(2, 9)}`);
const rootRef = ref<HTMLElement | null>(null);
const triggerRef = ref<HTMLElement | null>(null);
const listRef = ref<HTMLElement | null>(null);
const menuStyle = ref<Record<string, string>>({});
const open = ref(false);
const focusedIndex = ref(-1);

// The listbox is teleported to <body> so it can never be clipped by an
// ancestor's overflow:hidden / scroll container. Because it leaves the root, we
// re-establish the border CSS vars inline and pin it to the trigger with fixed
// coordinates, kept in sync on scroll/resize while open.
function updateMenuPosition() {
  const el = triggerRef.value;
  if (!el) return;
  const r = el.getBoundingClientRect();
  const bw = props.variant === 'ghost' ? 2 : 3;
  menuStyle.value = {
    position: 'fixed',
    left: `${r.left}px`,
    top: `${r.bottom - bw}px`,
    width: `${r.width}px`,
    minWidth: `${r.width}px`,
    maxWidth: `${r.width}px`,
    right: 'auto',
    maxHeight: props.listMaxHeight,
    zIndex: '2000',
    '--_bw': `${bw}px`,
    '--_bc': 'var(--color-primary, #f35)',
    '--_radius': props.size === 'sm' ? '6px' : '8px',
  };
}

const rootClasses = computed(() => ({
  'st-select--open': open.value,
  'st-select--disabled': props.disabled,
  [`st-select--${props.variant}`]: true,
  [`st-select--${props.size}`]: true,
  'st-select--error': !!props.error,
}));

function isSelected(opt: SelectOption): boolean {
  return String(opt.value).toLowerCase() === String(props.modelValue ?? '').toLowerCase();
}

function optionClasses(opt: SelectOption, idx: number) {
  return {
    'st-select__option--selected': isSelected(opt),
    'st-select__option--focused': focusedIndex.value === idx,
  };
}

const selectedOption = computed(() =>
  props.options.find((opt) => isSelected(opt))
);

function setOptionRef(el: unknown, idx: number) {
  if (el && focusedIndex.value === idx) {
    nextTick(() => (el as HTMLElement).scrollIntoView({ block: 'nearest', behavior: 'smooth' }));
  }
}

// True if the trigger is still on-screen and not clipped away by any scrollable
// ancestor — once it scrolls out of view (incl. past an overflow boundary) the
// teleported listbox would float orphaned, so we close instead of repositioning.
function triggerVisible(): boolean {
  const el = triggerRef.value;
  if (!el) return false;
  const r = el.getBoundingClientRect();
  if (r.bottom <= 0 || r.top >= window.innerHeight || r.right <= 0 || r.left >= window.innerWidth) return false;
  let p = el.parentElement;
  while (p) {
    const s = getComputedStyle(p);
    if (/(auto|scroll|hidden|clip)/.test(s.overflowY + s.overflowX)) {
      const pr = p.getBoundingClientRect();
      if (r.bottom <= pr.top || r.top >= pr.bottom || r.right <= pr.left || r.left >= pr.right) return false;
    }
    p = p.parentElement;
  }
  return true;
}

function onViewportChange() {
  if (!triggerVisible()) { open.value = false; return; }
  updateMenuPosition();
}

// Only one Select open at a time: opening one broadcasts its id; every other
// open instance hears it and closes.
function onOtherOpen(e: Event) {
  if ((e as CustomEvent).detail !== triggerId.value) open.value = false;
}

watch(open, (isOpen) => {
  if (isOpen) {
    window.dispatchEvent(new CustomEvent('st-select-open', { detail: triggerId.value }));
    const selIdx = props.options.findIndex((opt) => isSelected(opt));
    focusedIndex.value = selIdx >= 0 ? selIdx : 0;
    nextTick(updateMenuPosition);
    window.addEventListener('scroll', onViewportChange, true);
    window.addEventListener('resize', onViewportChange);
  } else {
    window.removeEventListener('scroll', onViewportChange, true);
    window.removeEventListener('resize', onViewportChange);
  }
});

function toggle() {
  if (props.disabled) return;
  open.value = !open.value;
}

function close() {
  open.value = false;
}

function select(opt: SelectOption) {
  emit('update:modelValue', opt.value);
  open.value = false;
}

function openAndFocusNext() {
  if (!open.value) { open.value = true; return; }
  focusedIndex.value = Math.min(focusedIndex.value + 1, props.options.length - 1);
}

function openAndFocusPrev() {
  if (!open.value) { open.value = true; return; }
  focusedIndex.value = Math.max(focusedIndex.value - 1, 0);
}

function onEnter() {
  if (!open.value) { open.value = true; return; }
  const opt = props.options[focusedIndex.value];
  if (opt) select(opt);
}

function onDocumentClick(e: MouseEvent) {
  const t = e.target as Node;
  if (rootRef.value && rootRef.value.contains(t)) return;
  if (listRef.value && listRef.value.contains(t)) return;
  open.value = false;
}

function onKeydown(e: KeyboardEvent) {
  if (!open.value) return;
  if (e.key === 'Escape') {
    open.value = false;
  }
}

onMounted(() => {
  document.addEventListener('click', onDocumentClick);
  document.addEventListener('keydown', onKeydown);
  window.addEventListener('st-select-open', onOtherOpen);
});
onUnmounted(() => {
  document.removeEventListener('click', onDocumentClick);
  document.removeEventListener('keydown', onKeydown);
  window.removeEventListener('st-select-open', onOtherOpen);
  window.removeEventListener('scroll', onViewportChange, true);
  window.removeEventListener('resize', onViewportChange);
});
</script>
