import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  base: process.env.SITE_BASE_PATH ?? '/',
  plugins: [react()],
});
