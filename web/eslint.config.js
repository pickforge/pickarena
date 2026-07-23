import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import tseslint from 'typescript-eslint';

const complexityRules = {
  complexity: ['error', 15],
  'max-depth': ['error', 4],
  'max-lines-per-function': [
    'error',
    { max: 100, skipBlankLines: true, skipComments: true }
  ]
};

export default [
  {
    ignores: ['.svelte-kit/**', 'build/**', 'coverage/**']
  },
  {
    files: ['src/**/*.ts', 'scripts/**/*.ts', '*.config.ts'],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parser: tseslint.parser
    },
    rules: complexityRules
  },
  ...svelte.configs['flat/base'],
  {
    files: ['src/**/*.svelte'],
    languageOptions: {
      globals: globals.browser,
      parserOptions: {
        parser: tseslint.parser
      }
    },
    rules: complexityRules
  },
  {
    files: ['**/*.test.ts'],
    rules: {
      'max-lines-per-function': 'off'
    }
  }
];
