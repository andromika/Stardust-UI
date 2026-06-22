<template lang="pug">
.st-searchable-select(
  ref="rootRef"
  :class="[rootClasses, attrs.class]"
  :style="rootStyle"
  v-bind="attrs"
)
  label.st-searchable-select__label(v-if="label" :for="triggerId") {{ label }}
  .st-searchable-select__trigger-wrap(
    ref="triggerRef"
    :class="{ 'st-searchable-select__trigger-wrap--open': open }"
  )
    template(v-if="!open")
      button.st-searchable-select__trigger(
        type="button"
        :id="triggerId"
        :disabled="disabled"
        :aria-haspopup="'listbox'"
        :aria-expanded="open"
        :aria-label="triggerAriaLabel"
        @click.stop="toggle"
      )
        template(v-if="selectedOption")
          slot(name="selected-option" :option="selectedOption")
            span.st-searchable-select__name {{ getOptionLabel(selectedOption) }}
        span.st-searchable-select__placeholder(v-else) {{ placeholder }}
        span.st-searchable-select__chevron(aria-hidden="true")
    template(v-else)
      .st-searchable-select__trigger.st-searchable-select__trigger--search(@click.stop)
        input.st-searchable-select__search(
          ref="searchInputRef"
          v-model="searchQuery"
          type="text"
          :placeholder="placeholder"
          @click.stop
          @keydown.down.prevent="focusNextOption"
          @keydown.up.prevent="focusPrevOption"
          @keydown.enter.prevent="selectFocused"
          @keydown.escape.prevent="handleEscape"
        )
        span.st-searchable-select__chevron(aria-hidden="true")
  Teleport(to="body")
    ul.st-searchable-select__list.st-searchable-select__list--floating(
      v-show="open"
      ref="listRef"
      role="listbox"
      :aria-labelledby="triggerId"
      :style="menuStyle"
      tabindex="-1"
    )
      li.st-searchable-select__list-header(v-if="$slots['list-header']")
        slot(name="list-header")
      li.st-searchable-select__option(
        v-for="(opt, idx) in filteredOptions"
        :key="String(getOptionValue(opt))"
        :ref="(el) => setFocusedRef(el, opt, idx)"
        role="option"
        :aria-selected="isSelected(opt)"
        :class="getOptionClasses(opt, idx)"
        @click="select(opt)"
        @mouseenter="focusedIndex = idx"
      )
        slot(name="option" :option="opt")
          span.st-searchable-select__name {{ getOptionLabel(opt) }}
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUnmounted, useAttrs } from 'vue';
import type { SelectOption } from './Select.vue';
import './SearchableSelect.scss';

defineOptions({ inheritAttrs: false });
const attrs = useAttrs();

const props = withDefaults(
  defineProps<{
    modelValue?: string | number;
    options?: SelectOption[];
    valueKey?: string;
    labelKey?: string;
    filter?: (opts: SelectOption[], query: string) => SelectOption[];
    placeholder?: string;
    label?: string;
    disabled?: boolean;
    variant?: 'solid' | 'ghost';
    size?: 'sm' | 'md';
    listMaxHeight?: string;
    columnLayout?: boolean;
    columns?: number;
    closeOnOutsideClick?: boolean;
    triggerAriaLabel?: string;
  }>(),
  {
    options: () => [],
    valueKey: 'value',
    labelKey: 'label',
    placeholder: 'Type to search...',
    variant: 'ghost',
    size: 'md',
    listMaxHeight: '40vh',
    columnLayout: false,
    columns: undefined,
    closeOnOutsideClick: true,
    triggerAriaLabel: 'Select option',
  }
);

const emit = defineEmits<{
  'update:modelValue': [value: string | number];
}>();

const triggerId = computed(() => `st-searchable-${Math.random().toString(36).slice(2, 9)}`);
const rootRef = ref<HTMLElement | null>(null);
const searchInputRef = ref<HTMLInputElement | null>(null);
const open = ref(false);
const searchQuery = ref('');
const focusedIndex = ref(0);
const triggerRef = ref<HTMLElement | null>(null);
const listRef = ref<HTMLElement | null>(null);
const menuStyle = ref<Record<string, string>>({});

const resolvedColumns = computed(() => {
  const raw = props.columns ?? (props.columnLayout ? 2 : 1);
  if (!Number.isFinite(raw)) return 1;
  return Math.max(1, Math.min(3, Math.floor(raw)));
});
const hasColumnLayout = computed(() => resolvedColumns.value > 1);

const rootClasses = computed(() => ({
  'st-searchable-select--open': open.value,
  'st-searchable-select--disabled': props.disabled,
  [`st-searchable-select--${props.variant}`]: true,
  [`st-searchable-select--${props.size}`]: true,
  'st-searchable-select--columns': hasColumnLayout.value,
}));
const rootStyle = computed(() => ({
  '--st-searchable-select-columns': String(resolvedColumns.value),
}));

function getOptionValue(opt: SelectOption): string | number {
  const k = props.valueKey;
  const raw = k && opt[k] !== undefined ? opt[k] : opt.value;
  if (typeof raw === 'string' || typeof raw === 'number') return raw;
  return '';
}
function getOptionLabel(opt: SelectOption): string {
  const k = props.labelKey;
  return (k && opt[k] !== undefined ? String(opt[k]) : opt.label) ?? '';
}

const currentValue = computed(() => props.modelValue);

function isSelected(opt: SelectOption): boolean {
  return String(getOptionValue(opt)).toLowerCase() === String(currentValue.value ?? '').toLowerCase();
}

function getOptionClasses(opt: SelectOption, idx: number) {
  return {
    'st-searchable-select__option--selected': isSelected(opt),
    'st-searchable-select__option--focused': focusedIndex.value === idx,
  };
}

const defaultFilter = (opts: SelectOption[], query: string) => {
  const q = query.trim().toLowerCase();
  if (!q) return opts;
  return opts.filter((o) =>
    [getOptionLabel(o), String(getOptionValue(o)), (o as Record<string, unknown>).tags, (o as Record<string, unknown>).rarity]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()
      .includes(q)
  );
};

const filteredOptions = computed(() => {
  const filterFn = props.filter || defaultFilter;
  return filterFn([...props.options], searchQuery.value);
});

const selectedOption = computed(() =>
  props.options.find((opt) => isSelected(opt))
);

function setFocusedRef(el: unknown, _opt: SelectOption, idx: number) {
  if (el && focusedIndex.value === idx) {
    (el as HTMLElement).scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }
}

// Close (instead of repositioning) once the trigger scrolls out of view or past
// any overflow boundary, so the teleported listbox never floats orphaned.
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

// Only one Select open at a time: opening one broadcasts its id; other open
// instances hear it and close.
function onOtherOpen(e: Event) {
  if ((e as CustomEvent).detail !== triggerId.value) open.value = false;
}

watch(open, (isOpen) => {
  if (isOpen) {
    window.dispatchEvent(new CustomEvent('st-select-open', { detail: triggerId.value }));
    searchQuery.value = '';
    focusedIndex.value = 0;
    nextTick(() => {
      updateMenuPosition();
      searchInputRef.value?.focus();
    });
    window.addEventListener('scroll', onViewportChange, true);
    window.addEventListener('resize', onViewportChange);
  } else {
    window.removeEventListener('scroll', onViewportChange, true);
    window.removeEventListener('resize', onViewportChange);
  }
});

watch(focusedIndex, (idx) => {
  if (idx < 0) focusedIndex.value = 0;
  if (idx >= filteredOptions.value.length) focusedIndex.value = filteredOptions.value.length - 1;
});

// Listbox is teleported to <body> so it is never clipped by an overflow
// ancestor; re-establish the border vars + column count inline and pin it to
// the trigger with fixed coords, re-synced on scroll/resize while open.
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
    '--st-searchable-select-columns': String(resolvedColumns.value),
  };
}

function toggle() {
  if (props.disabled) return;
  open.value = !open.value;
}

function select(opt: SelectOption) {
  emit('update:modelValue', getOptionValue(opt));
  open.value = false;
}

function focusNextOption() {
  focusedIndex.value++;
  if (focusedIndex.value >= filteredOptions.value.length) focusedIndex.value = filteredOptions.value.length - 1;
}

function focusPrevOption() {
  focusedIndex.value--;
  if (focusedIndex.value < 0) focusedIndex.value = 0;
}

function selectFocused() {
  const opts = filteredOptions.value;
  if (opts[focusedIndex.value]) select(opts[focusedIndex.value]);
}

function handleEscape() {
  if (!props.closeOnOutsideClick) return;
  open.value = false;
}

function onDocumentClick(e: MouseEvent) {
  if (!props.closeOnOutsideClick) return;
  const t = e.target as Node;
  if (rootRef.value && rootRef.value.contains(t)) return;
  if (listRef.value && listRef.value.contains(t)) return;
  open.value = false;
}

function onKeydown(e: KeyboardEvent) {
  if (!open.value) return;
  if (e.key === 'Escape') {
    if (!props.closeOnOutsideClick) return;
    open.value = false;
    (e.target as HTMLElement).blur();
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
