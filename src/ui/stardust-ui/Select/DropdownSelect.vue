<template lang="pug">
.st-dropdown-select(
  ref="rootRef"
  :class="[rootClasses, attrs.class]"
  v-bind="attrs"
)
  label.st-dropdown-select__label(v-if="label" :for="triggerId") {{ label }}
  button.st-dropdown-select__trigger(
    ref="triggerRef"
    type="button"
    :id="triggerId"
    :disabled="disabled"
    :aria-haspopup="'listbox'"
    :aria-expanded="open"
    :aria-label="triggerAriaLabel"
    @click="toggle"
  )
    template(v-if="selectedOption")
      img.st-dropdown-select__image(
        v-if="selectedOption.imageUrl"
        :src="selectedOption.imageUrl"
        :alt="''"
        :width="size === 'lg' ? 50 : 32"
        :height="size === 'lg' ? 42 : 24"
      )
      span.st-dropdown-select__text
        span.st-dropdown-select__name {{ selectedOption.label }}
        small.st-dropdown-select__desc(v-if="selectedOption.description") {{ selectedOption.description }}
    span.st-dropdown-select__placeholder(v-else) {{ placeholder }}
    span.st-dropdown-select__chevron(aria-hidden="true")
  Teleport(to="body")
    ul.st-dropdown-select__list.st-dropdown-select__list--floating(
      v-show="open"
      ref="listRef"
      role="listbox"
      :aria-labelledby="triggerId"
      :style="menuStyle"
      tabindex="-1"
    )
      li.st-dropdown-select__option(
        v-for="opt in options"
        :key="String(opt.value)"
        :ref="(el) => setSelectedOptionRef(el, opt)"
        role="option"
        :aria-selected="isSelected(opt)"
        :class="{ 'st-dropdown-select__option--selected': isSelected(opt) }"
        @click="select(opt)"
      )
        img.st-dropdown-select__image(
          v-if="opt.imageUrl"
          :src="opt.imageUrl"
          :alt="''"
          :width="size === 'lg' ? 32 : 24"
          :height="size === 'lg' ? 32 : 24"
        )
        span.st-dropdown-select__text
          span.st-dropdown-select__name {{ opt.label }}
          small.st-dropdown-select__desc(v-if="opt.description") {{ opt.description }}
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUnmounted, useAttrs } from 'vue';
import './DropdownSelect.scss';

defineOptions({ inheritAttrs: false });
const attrs = useAttrs();

export interface DropdownSelectOption {
  value: string | number;
  label: string;
  description?: string;
  imageUrl?: string;
}

const props = withDefaults(
  defineProps<{
    modelValue?: string | number;
    options?: DropdownSelectOption[];
    placeholder?: string;
    label?: string;
    variant?: 'solid' | 'ghost';
    size?: 'sm' | 'md' | 'lg';
    lightBackground?: boolean;
    disabled?: boolean;
    listMaxHeight?: string;
    listMaxWidth?: string;
    triggerAriaLabel?: string;
  }>(),
  {
    options: () => [],
    placeholder: 'Choose...',
    variant: 'solid',
    size: 'md',
    listMaxHeight: '40vh',
    listMaxWidth: '400px',
    triggerAriaLabel: 'Select option',
  }
);

const emit = defineEmits<{
  'update:modelValue': [value: string | number];
}>();

const triggerId = computed(() => `st-dropdown-${Math.random().toString(36).slice(2, 9)}`);
const rootRef = ref<HTMLElement | null>(null);
const triggerRef = ref<HTMLElement | null>(null);
const listRef = ref<HTMLElement | null>(null);
const selectedOptionRef = ref<HTMLElement | null>(null);
const open = ref(false);
const menuStyle = ref<Record<string, string>>({});

// The listbox is teleported to <body> so an ancestor's overflow:hidden / scroll
// container can never clip it. Because it leaves the root we re-establish the
// border CSS vars inline and pin it to the trigger with fixed coordinates,
// re-synced on scroll/resize while open.
function updateMenuPosition() {
  const el = triggerRef.value;
  if (!el) return;
  const r = el.getBoundingClientRect();
  const bw = props.variant === 'ghost' ? 2 : 3;
  menuStyle.value = {
    position: 'fixed',
    left: `${r.left}px`,
    top: `${r.bottom - bw}px`,
    minWidth: `${r.width}px`,
    width: `${r.width}px`,
    maxWidth: props.listMaxWidth,
    right: 'auto',
    maxHeight: props.listMaxHeight,
    zIndex: '2000',
    '--_bw': `${bw}px`,
    '--_bc': 'var(--color-primary, #f35)',
    '--_radius': props.size === 'sm' ? '6px' : props.size === 'lg' ? '10px' : '8px',
  };
}

const currentValue = computed(() => props.modelValue);

function isSelected(opt: DropdownSelectOption): boolean {
  return String(opt.value).toLowerCase() === String(currentValue.value ?? '').toLowerCase();
}

function setSelectedOptionRef(el: unknown, opt: DropdownSelectOption): void {
  if (el && isSelected(opt)) {
    selectedOptionRef.value = el as HTMLElement;
  }
}

const selectedOption = computed(() =>
  props.options.find((opt) => isSelected(opt))
);

const rootClasses = computed(() => ({
  'st-dropdown-select--open': open.value,
  'st-dropdown-select--disabled': props.disabled,
  [`st-dropdown-select--${props.variant}`]: true,
  [`st-dropdown-select--${props.size}`]: true,
  'st-dropdown-select--light': props.lightBackground,
}));

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
    nextTick(() => {
      updateMenuPosition();
      selectedOptionRef.value?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    });
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

function select(opt: DropdownSelectOption) {
  emit('update:modelValue', opt.value);
  open.value = false;
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
