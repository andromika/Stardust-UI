import type { StorybookConfig } from '@storybook/vue3-vite';

const config: StorybookConfig = {
  stories: [
    '../src/stories/**/*.stories.@(js|jsx|mjs|ts|tsx)',
    '../src/ui/themes/**/*.stories.@(js|jsx|mjs|ts|tsx)',
    '../src/ui/stardust-ui/**/*.stories.@(js|jsx|mjs|ts|tsx)',
    '../src/ui/components/**/*.stories.@(js|jsx|mjs|ts|tsx)'
  ],
  addons: [
    '@storybook/addon-a11y',
    '@storybook/addon-docs',
    '@storybook/addon-themes'
  ],
  framework: '@storybook/vue3-vite'
};

export default config;
