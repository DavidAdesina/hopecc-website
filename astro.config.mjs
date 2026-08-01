// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://hopecc.org.uk',
  // /admin dev-server workaround for a known, currently-open Astro bug
  // (withastro/astro#14800): index.html files sitting in a public/
  // subfolder (public/admin/index.html, the Decap CMS screen) aren't
  // served for the bare folder path in `npm run dev` — visiting /admin
  // or /admin/ 404s, only the full /admin/index.html works. This entry
  // fixes that by routing /admin through Astro's own dev router.
  //
  // NOTE: this does nothing in production (`astro build`). The build
  // output path collides with public/admin/index.html, which always
  // wins, so Astro silently skips generating this redirect and prints
  // a "Skipping /admin because a file with the same name exists in the
  // public folder" WARN — that's expected, not a bug, and /admin still
  // works in dist/ because the public-folder file is copied through
  // directly. Confirmed with a real `astro build` (v7.1.6). See
  // README.md's "/admin redirect (dev-server workaround)" section.
  redirects: {
    '/admin': '/admin/index.html',
  },
  vite: {
    plugins: [tailwindcss()],
  },
});
