// Regole di lint comuni alle app ron1n (React + TypeScript). Per un'app senza
// React togli i plugin react-hooks e react-refresh. Lo stile (spazi, virgolette, a capo)
// è compito di Prettier: eslint-config-prettier spegne le regole in conflitto.
import js from '@eslint/js'
import prettier from 'eslint-config-prettier'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import { defineConfig, globalIgnores } from 'eslint/config'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default defineConfig([
  globalIgnores(['dist', 'coverage']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      reactHooks.configs.flat.recommended,
      reactRefresh.configs.vite,
    ],
    languageOptions: {
      ecmaVersion: 2023,
      globals: globals.browser,
    },
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/consistent-type-imports': 'error',
      eqeqeq: ['error', 'smart'],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
  {
    // Componenti shadcn: esportano anche le varianti cva accanto al componente.
    files: ['src/components/ui/**/*.tsx'],
    rules: { 'react-refresh/only-export-components': 'off' },
  },
  {
    // Configurazione, e2e e, quando arriverà, il backend: girano in Node.
    files: ['*.config.{js,ts}', 'e2e/**/*.ts', 'server/**/*.ts'],
    languageOptions: { globals: globals.node },
  },
  prettier,
])
