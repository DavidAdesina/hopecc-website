# Hope Community Church Website

The website for [Hope Community Church](https://hopecc.org.uk), a registered
charity (No. 1108872) based at Deveron Way, Hinckley, Leicestershire, LE10 0XD.

If you're looking for how to **edit the words, photos, or contact details on
the site** rather than how the code works, you want
[`MAINTENANCE-GUIDE.md`](./MAINTENANCE-GUIDE.md) instead — this file is for
developers setting up the project or working on the code itself.

---

## Tech stack

- **[Astro](https://astro.build) 6** — the framework the site is built with.
  Pages are `.astro` files that mix HTML with a small amount of JavaScript.
  Astro outputs plain, fast HTML/CSS with very little JavaScript sent to
  visitors' browsers.
- **[Tailwind CSS](https://tailwindcss.com) v4** — utility CSS framework,
  wired in via the official PostCSS plugin (`@tailwindcss/postcss`, see
  [Tailwind/Vite build fix](#tailwind--vite-build-fix-important) below for
  why it's PostCSS and not the Vite plugin). Most pages on this site
  currently use hand-written CSS in `<style>` blocks rather than Tailwind
  utility classes (see [Styling notes](#styling-notes) below for why).
- **[Prettier](https://prettier.io)**, with the official
  [`prettier-plugin-astro`](https://github.com/withastro/prettier-plugin-astro) —
  handles code formatting (indentation, quotes, trailing commas, line
  wrapping). Config lives in `.prettierrc.json`; `.prettierignore` excludes
  `watch-listen.astro` (under active development — see below) and build
  output. Run `npx prettier --write .` to reformat everything, or
  `npx prettier --check .` to see what would change without writing.
- **Plain HTML/CSS/JS** — all pages, including `contact.astro`,
  `safeguarding.astro`, and `privacy-policy.astro`, use the shared
  `Layout.astro` (Navbar + Footer), so navigation only has to be maintained
  in one place.

As of the last dependency check, the project resolves to **Astro 6.4.8** and
**Tailwind CSS 4.3.3**. `package.json` uses caret ranges (`^6.3.5`, `^4.3.0`),
so exact installed versions may move slightly as patches are released —
run `npm outdated` to check.

**Planned but not yet built (Phase 3):**
- AWS hosting — S3 (storage) + CloudFront (CDN) + Route 53 (DNS) + ACM
  (SSL certificate)
- AWS Lambda + API Gateway — backend for the contact form
- GitHub Actions — automatic deployment when code is pushed to `main`
- Decap CMS — a web-based editing screen so non-technical users can edit
  content without touching code directly (see [Content editing](#content-editing-today-vs-the-plan))

---

## Getting started (local development)

**Requirements:** Node.js **22.12.0 or later** (set in `package.json` →
`engines.node`). Check your version with `node -v`.

```bash
# 1. Clone the repo and move into it
git clone https://github.com/DavidAdesina/hopecc-website.git
cd hopecc-website

# 2. Install dependencies
npm install

# 3. Start the local dev server (usually http://localhost:4321)
npm run dev
```

Other available scripts:

| Command           | What it does                                                        |
|-------------------|----------------------------------------------------------------------|
| `npm run dev`     | Starts a local dev server with live reload while you edit files      |
| `npm run build`   | Builds the production site into a `dist/` folder                     |
| `npm run preview` | Serves the built `dist/` folder locally, so you can check a build    |
| `npm run astro`   | Runs the Astro CLI directly (e.g. `npm run astro -- check`)          |

There is no test suite configured yet. Prettier is configured for formatting
(see [Tech stack](#tech-stack) above) — there's no linter (e.g. ESLint) yet.

---

## Project structure

```
hopecc-website/
├── astro.config.mjs        Astro's main config file — site URL
├── postcss.config.mjs       Registers the Tailwind PostCSS plugin (see
│                            Tailwind / Vite build fix above)
├── tailwind.config.mjs      Tailwind v4 config (see note below — most brand
│                            tokens actually live in global.css, not here)
├── .prettierrc.json          Prettier formatting config (Astro plugin)
├── .prettierignore           Files Prettier skips (watch-listen.astro, dist/)
├── package.json             Dependencies and npm scripts
├── tsconfig.json             TypeScript config (for editor tooling/type checks)
│
├── public/                   Static files served as-is, unprocessed
│   ├── documents/             PDFs (e.g. the safeguarding policy)
│   ├── images/                 All site photos, logos, and the OG share image
│   ├── favicon.ico / favicon.svg
│
└── src/
    ├── assets/                 Astro-starter placeholder assets (unused)
    ├── components/
    │   ├── Navbar.astro         Site header/navigation, used on every page
    │   ├── Footer.astro         Site footer, used on every page
    │   └── Welcome.astro        Unused Astro-starter boilerplate — see below
    ├── layouts/
    │   └── Layout.astro         Shared page shell (Navbar + Footer + <head>
    │                            tags). Every page wraps its content in this.
    ├── pages/
    │   ├── index.astro           Homepage
    │   ├── whats-on.astro         Services, regular activities, gallery, calendar
    │   ├── watch-listen.astro     Sermons/live stream — currently a "coming soon"
    │   │                          page with a scaffold ready for real content
    │   ├── mission.astro           Mission overview / landing page
    │   ├── mission/
    │   │   ├── india.astro          Full India mission story
    │   │   └── romania.astro        Full Romania mission story
    │   ├── contact.astro           Contact page (also handles room hire mode)
    │   ├── room-hire.astro         Redirects to contact.astro?enquiry=room-hire
    │   ├── safeguarding.astro       Safeguarding policy page
    │   └── privacy-policy.astro     Privacy policy page
    └── styles/
        └── global.css            Tailwind entry point (see note below)
```

---

## Styling notes

- **Tailwind v4 custom design tokens go in `src/styles/global.css`, inside an
  `@theme` block — not in `tailwind.config.mjs`.** This tripped us up early on
  and is worth remembering if you add new brand colours or fonts. The current
  `global.css` only contains `@import "tailwindcss";` — no custom theme tokens
  have been added there yet, because most pages use their own hand-written CSS
  instead (see below).
- `global.css` must be imported in `Layout.astro`'s frontmatter for Tailwind
  to apply anywhere at all.
- **Most pages use plain CSS in `<style>` blocks with a shared set of CSS
  custom properties** (`--navy`, `--blue`, `--pale-blue`, `--gold`, `--cream`,
  font `'Nunito'`) repeated near the top of each file, rather than Tailwind
  utility classes. This was a deliberate choice during the build — dynamically
  inserted Tailwind classes were sometimes missed by the compiler, and direct
  CSS proved more reliable for quick layout fixes. If you refactor a page to
  use Tailwind properly, make sure the brand colours are moved into the
  `@theme` block first so they stay consistent site-wide.
- **Brand tokens**, for reference:

  | Token       | Value      |
  |-------------|------------|
  | Navy        | `#0d1f3c`  |
  | Baby blue   | `#4a90c4`  |
  | Pale blue   | `#e8f2f9`  |
  | Gold        | `#c9a84c`  |
  | Cream       | `#f7f9fc`  |
  | Font        | Nunito, weight 800 for headings |

---

## Tailwind / Vite build fix (important)

**As of this update, `@tailwindcss/vite` no longer works with this project.**
This isn't specific to this site — it's a known, currently-open upstream
incompatibility between `@tailwindcss/vite` and the Rolldown-based Vite that
Astro 6 bundles by default. Running a plain `npm install` on the previous
`package.json` would build successfully today but fail the moment any
dependency patch-updates, with an error like:

```
[@tailwindcss/vite:generate:build] Missing field `tsconfigPaths` on
BindingViteResolvePluginConfig.resolveOptions
```

(Tracked upstream: [vitejs/vite#22322](https://github.com/vitejs/vite/issues/22322),
[withastro/astro#16542](https://github.com/withastro/astro/issues/16542).)

**The fix:** switched Tailwind from the Vite plugin to the PostCSS plugin,
which doesn't have this issue.

- `astro.config.mjs` no longer imports or registers `@tailwindcss/vite`.
- A new `postcss.config.mjs` registers `@tailwindcss/postcss` instead.
- `package.json` now depends on `@tailwindcss/postcss` instead of
  `@tailwindcss/vite`.

Verified with a completely clean install (`rm -rf node_modules
package-lock.json && npm install && npm run build`) — all 10 pages build
successfully. No visual or behavioural change; this only affects how
Tailwind is wired into the build, and the site doesn't yet use Tailwind
utility classes on any page (see [Styling notes](#styling-notes)).

---

## `astro.config.mjs`

`site` **must** stay set to `https://hopecc.org.uk`. `Astro.site` (used for
canonical URLs and Open Graph tags in `Layout.astro`) depends on it — removing
or leaving it blank throws `TypeError: Invalid URL` at build time.

---

## Content editing today vs. the plan

Right now, **all page text, images, and contact details are edited directly
inside the `.astro` files** in `src/pages/`. Every editable spot is marked
with an `EDIT:` comment — see `MAINTENANCE-GUIDE.md` for a non-technical
walkthrough of how to find and use these.

There is currently **no content management system (CMS)** and **no automatic
deployment** — changes made to files have to be committed and pushed to the
repo by whoever has developer/git access, and (once Phase 3 is complete) a
GitHub Actions pipeline will handle publishing them live.

**Decap CMS** is planned as the next step after this README, so that
non-technical users can eventually edit approved fields (like service times,
stats, and contact details) through a simple web form instead of editing code.
That is not built yet.

---

## Known unused files

- **`src/components/Welcome.astro`** — leftover boilerplate from the original
  Astro starter template. It is not imported anywhere (`index.astro` uses
  `Layout.astro` instead). Safe to ignore, or delete it entirely if you want
  to tidy the repo — nothing depends on it.

---

## Known flagged items (intentionally left as-is)

These were spotted during a code-quality review. Most have since been
resolved (see below) — one remains outstanding by design:

- **`watch-listen.astro`** has an unused sermon-archive scaffold — a
  `featuredSermons` placeholder array plus matching `.sermons-*` /
  `.sermon-card` CSS — sitting ready for when a real sermon archive or YouTube
  playlist integration goes live. It isn't rendered on the page yet. **Left
  untouched deliberately** — this page is currently under active development,
  so the scaffold stays as-is until that work is done.

### Resolved

- ~~`Navbar.astro` listed the menu links twice~~ — fixed. Both the desktop
  nav and the mobile hamburger menu are now built from a single shared
  `navLinks` list defined once in the component, so adding, removing, or
  renaming a link only needs to happen in one place.
- ~~`mission.astro` had a dead `.cta-section` CSS block~~ — removed. No
  matching HTML existed anywhere in the file; the leftover styles (including
  a duplicate copy inside the mobile media query) have been deleted with no
  visual or behavioural change.
- ~~`mission/romania.astro`'s photo carousel required a matching dot button
  to be hand-added for every new photo~~ — fixed. The carousel script now
  counts the actual photo elements and generates the dot buttons itself at
  runtime, so photos are the only list a maintainer needs to touch.
- ~~`contact.astro`, `safeguarding.astro`, and `privacy-policy.astro` were
  standalone HTML documents with their own duplicated `<nav>` markup~~ —
  migrated onto the shared `Layout.astro` / `Navbar` component, so
  navigation is maintained in one place across the whole site.
- ~~`mission/romania.astro` had a malformed CSS comment~~ — a comment
  written as `/* ... -->` (mixing CSS and HTML comment syntax) was silently
  swallowing the entire rest of the stylesheet as one giant unclosed
  comment. Fixed by closing it properly with `*/`.
- ~~`Navbar.astro` was leaking internal comments into the live site's
  HTML~~ — three HTML-style comments (`<!-- -->`) were sitting inside JS
  map/ternary expressions, so Astro rendered them as literal text into
  every page's navigation markup instead of stripping them at build time
  (one was duplicating once per dropdown sub-link). Converted to JS-style
  `{/* */}` comments, which Astro does strip. Verified via a diff of the
  built HTML before and after — the comments no longer appear in any
  shipped page.
- Code formatting pass completed with Prettier + the official Astro plugin
  across all 13 in-use files (`watch-listen.astro` excluded, per its
  active-development status above). Verified via a real `astro build`
  before and after, plus a whitespace-normalized diff of every generated
  page — all differences were harmless whitespace inside existing tags,
  never new gaps between elements.

---

## Pre-launch plan (status)

| Day | Task | Status |
|-----|------|--------|
| 1 | Dependency audit + migrate contact/safeguarding/privacy-policy onto shared Layout/Navbar/Footer | ✅ Done |
| 2 | Security review (whats-on.astro, romania.astro carousel script) | ✅ Done — no issues found |
| 3 | Consistent commenting pass across all in-use files | ✅ Done |
| 3b | README + plain-English maintenance guide | ✅ This document |
| 3c | Navbar.astro duplicate-list fix (single shared `navLinks` list) | ✅ Done |
| 3d | mission.astro dead `.cta-section` CSS removed | ✅ Done |
| 3e | romania.astro carousel dot-indicator dependency removed (dots now auto-generated from photo count) | ✅ Done |
| 4 | Code formatting pass (Prettier + Astro plugin, watch-listen.astro scaffold left untouched — page under active development). Also fixed the Tailwind/Vite build bug and two other bugs found along the way (see Resolved, above) | ✅ Done |
| 5 | Decap CMS setup (config, GitHub OAuth app) | Not started |
| 6 | CMS testing + maintainer instructions for `/admin` | Not started |
| 7+ | AWS deployment (S3, CloudFront, Route 53, ACM, Lambda, API Gateway) + GitHub Actions CI/CD | Not started |
| Last | DNS cutover, launch, smoke test | Not started |

---

## Contact

Hope Community Church, Deveron Way, Hinckley, Leicestershire, LE10 0XD
Registered Charity No. 1108872
info@hopecc.org.uk
