# Hope Community Church Website

The website for [Hope Community Church](https://hopecc.org.uk), a registered
charity (No. 1108872) based at Deveron Way, Hinckley, Leicestershire, LE10 0XD.

If you're looking for how to **edit the words, photos, or contact details on
the site** rather than how the code works, you want
[`MAINTENANCE-GUIDE.md`](./MAINTENANCE-GUIDE.md) instead — this file is for
developers setting up the project or working on the code itself.

---

## Tech stack

- **[Astro](https://astro.build) 7** — the framework the site is built with.
  Pages are `.astro` files that mix HTML with a small amount of JavaScript.
  Astro outputs plain, fast HTML/CSS with very little JavaScript sent to
  visitors' browsers.
- **[Tailwind CSS](https://tailwindcss.com) v4** — utility CSS framework,
  wired in via the official Vite plugin (`@tailwindcss/vite`, see
  [Tailwind / Vite build fix](#tailwind--vite-build-fix-important) below for
  the back-and-forth on why it's the Vite plugin again and not PostCSS).
  Most pages on this site currently use hand-written CSS in `<style>` blocks
  rather than Tailwind utility classes (see [Styling notes](#styling-notes)
  below for why).
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

As of the last dependency check, the project resolves to **Astro 7.1.6** and
**Tailwind CSS 4.3.3**. `package.json` uses caret ranges (`^7.1.5`, `^4.3.0`),
so exact installed versions may move slightly as patches are released —
run `npm outdated` to check.

**Live, in addition to the above (see [Deployment & infrastructure](#deployment--infrastructure)
for the full picture):**
- **AWS hosting** — S3 (private bucket) + CloudFront (CDN, TLS, routing) +
  ACM (certificate). DNS itself hasn't been cut over to point at this yet —
  the site is fully live and tested on CloudFront's own domain in the
  meantime.
- **AWS Lambda + API Gateway** — one HTTP API, two Lambda functions: the
  contact form (sends via SES) and Decap CMS's GitHub OAuth login proxy.
- **GitHub Actions** — automatic deployment on every push to `main`
  (build → sync to S3 → invalidate CloudFront), authenticated via OIDC
  with no long-lived AWS keys stored anywhere.
- **Decap CMS** — real GitHub login confirmed working end-to-end on the
  live (CloudFront) domain, not just local dev.

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
├── astro.config.mjs        Astro's main config file — site URL, and the
│                            Tailwind Vite plugin (see Tailwind / Vite build
│                            fix below)
├── tailwind.config.mjs      Tailwind v4 config (see note below — most brand
│                            tokens actually live in global.css, not here)
├── .prettierrc.json          Prettier formatting config (Astro plugin)
├── .prettierignore           Files Prettier skips (watch-listen.astro, dist/)
├── package.json             Dependencies and npm scripts
├── tsconfig.json             TypeScript config (for editor tooling/type checks)
│
├── .github/
│   └── workflows/
│       └── deploy.yml         CI/CD — builds and deploys to AWS on every
│                                push to main. See "Deployment &
│                                infrastructure" below.
│
├── terraform/                 All AWS infrastructure as code — see
│   │                            "Deployment & infrastructure" below for
│   │                            what each file does and how to run it.
│   └── lambda/
│       ├── contact-form/       Source for the contact form Lambda
│       └── decap-oauth/        Source for Decap CMS's OAuth login Lambda
│
├── public/                   Static files served as-is, unprocessed
│   ├── admin/                  Decap CMS — config.yml (collections/fields)
│   │                            and index.html (the /admin screen)
│   ├── documents/             PDFs (e.g. the safeguarding policy)
│   ├── images/                 All site photos, logos, and the OG share image
│   ├── favicon.ico / favicon.svg
│
└── src/
    ├── assets/                 Astro-starter placeholder assets (unused)
    ├── data/                    CMS-editable content as JSON — see
    │                            "Content editing" section below for what
    │                            each file holds
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
    │   ├── privacy-policy.astro     Privacy policy page
    │   └── 404.astro                Custom "page not found" page — served by
    │                                 CloudFront whenever S3 can't find a
    │                                 requested file (see Deployment section)
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

This project has flip-flopped between the two official ways of wiring
Tailwind v4 into Astro — the Vite plugin and the PostCSS plugin — because
of two *separate*, unrelated upstream bugs in Astro's Rolldown-based Vite.
As of now, **it's back on the Vite plugin (`@tailwindcss/vite`)**, which is
the current working setup. The history, in case a future dependency update
resurfaces either issue:

**Bug #1 (hit first) — `@tailwindcss/vite` + Rolldown, missing `tsconfigPaths` field.**
`npm run build` would fail intermittently with:

```
[@tailwindcss/vite:generate:build] Missing field `tsconfigPaths` on
BindingViteResolvePluginConfig.resolveOptions
```

(Tracked upstream: [vitejs/vite#22322](https://github.com/vitejs/vite/issues/22322),
[withastro/astro#16542](https://github.com/withastro/astro/issues/16542).)
**Workaround at the time:** switched from the Vite plugin to the PostCSS
plugin (`@tailwindcss/postcss`), which sidestepped this bug entirely.

**Bug #2 (hit after switching to PostCSS) — Rolldown's CSS `@import`
resolver.** With the PostCSS plugin in place, `npm run build` started
failing instead with:

```
[postcss] ENOENT: no such file or directory, open '<project-root>/tailwindcss'
```

This one is a bug in how Rolldown's bundled `postcss-import` resolves the
bare `@import "tailwindcss";` in `global.css` — it was trying to open a
literal file named `tailwindcss` next to `package.json` instead of
resolving the npm package. Reproduced with a real `astro build` in a clean
sandbox; confirmed via a deliberately-broken `postcss.config.mjs` that the
config file itself *was* being loaded correctly, so the fault was further
downstream in Vite/Rolldown's own CSS-import handling, not a misconfiguration.
Pinning `vite` back to `8.0.16` via an override didn't help — the bug is
present there too, so it isn't a narrow version regression. This is a known,
already-traced issue specific to the **PostCSS** code path
([vitejs/vite#22766](https://github.com/vitejs/vite/pull/22766) fixed the
equivalent bug for the Vite-plugin path, not this one).

**Current fix:** since Bug #1 (the original reason for leaving the Vite
plugin) has since been fixed upstream, and Bug #2 (the PostCSS path) hasn't,
the project switched back to `@tailwindcss/vite`:

- `astro.config.mjs` imports `@tailwindcss/vite` and registers it under
  `vite.plugins`.
- `postcss.config.mjs` has been deleted — no longer needed, and leaving it
  in place risked both code paths fighting over the same `@import`.
- `package.json` depends on `@tailwindcss/vite` instead of
  `@tailwindcss/postcss`.

Verified with a completely clean install (`rm -rf node_modules
package-lock.json && npm install && npm run build`) — build succeeds, and
the generated CSS was checked to contain real compiled Tailwind utility
output (not just an empty pass-through), confirming Tailwind is actually
running, not silently skipped. No visual or behavioural change; this only
affects how Tailwind is wired into the build, and the site doesn't yet use
Tailwind utility classes on any page (see [Styling notes](#styling-notes)).

**If this breaks again on a future dependency update:** check which of the
two bugs above has resurfaced (the error message will tell you — `tsconfigPaths`
missing field vs. `ENOENT ... tailwindcss`) before assuming the other plugin
is automatically the fix; they are not the same bug and don't necessarily
get fixed on the same timeline.

---

## `astro.config.mjs`

`site` **must** stay set to `https://hopecc.org.uk`. `Astro.site` (used for
canonical URLs and Open Graph tags in `Layout.astro`) depends on it — removing
or leaving it blank throws `TypeError: Invalid URL` at build time.

### `/admin` redirect (dev-server workaround)

`astro.config.mjs` also has a `redirects` block:

```js
redirects: {
  '/admin': '/admin/index.html',
},
```

This exists because of a known, currently-open Astro dev-server bug
([withastro/astro#14800](https://github.com/withastro/astro/issues/14800)):
`index.html` files sitting in subfolders of `public/` (like
`public/admin/index.html`, the Decap CMS screen) aren't served for the bare
folder path — visiting `/admin` or `/admin/` 404s in `npm run dev`, and only
the full `/admin/index.html` works. The `redirects` entry above fixes that
for local dev by routing `/admin` through Astro's own router instead of
relying on the buggy static-file serving.

**⚠️ This fix doesn't carry over to the production build.** Running
`astro build` skips creating the `/admin` redirect, because its output path
collides with the real `public/admin/index.html` file — the real file wins,
and the bare `/admin` route silently isn't created in `dist/`. On S3 +
CloudFront, this turned out to be a real, confirmed problem — not just a
theoretical one — and not only for `/admin`: **every** directory-style
page on the site (e.g. `/mission/india`, `/contact/`) hit the same S3/403
issue, since S3 has no built-in "serve this folder's index.html" behaviour
without its own website-hosting mode (incompatible with the private-bucket
setup used here). It's now fixed by a CloudFront Function — see
[Deployment & infrastructure](#deployment--infrastructure) below for how.

---

## Deployment & infrastructure

The site is built as static files (`astro build` → `dist/`) and served from
AWS: **S3** holds the built files, **CloudFront** serves them over HTTPS
with a custom domain, and **GitHub Actions** deploys automatically on every
push to `main`. Two small **Lambda** functions handle the contact form and
Decap CMS's login. Everything is defined in Terraform, in `terraform/`.

**Current status:** all of this is live and tested on CloudFront's own
domain. `hopecc.org.uk`'s DNS hasn't been pointed at it yet — that's a
deliberate last step, done only once everything's been proven working
first. Until then, the live public site is still on its previous host.

### Architecture, at a glance

```
Visitor's browser
      │
      ▼
CloudFront (CDN + HTTPS + custom domain)
      │
      ├── default path (/, /whats-on, /admin, ...) ──▶ S3 (private bucket, the built site)
      │
      └── /api/*  ──▶ API Gateway (HTTP API) ──┬──▶ Lambda: contact form ──▶ SES ──▶ info@hopecc.org.uk
                                                 └──▶ Lambda: Decap OAuth  ──▶ GitHub (login for /admin)

git push to main ──▶ GitHub Actions ──▶ npm run build ──▶ aws s3 sync ──▶ CloudFront cache invalidation
                     (authenticates to AWS via OIDC — no stored AWS keys)
```

### The Terraform

Everything below lives in `terraform/` as one flat set of `.tf` files (no
modules/workspaces — this project is small enough that the extra structure
would just be overhead). **Nobody but the person applying it has AWS
credentials configured** — changes are written here, reviewed, then applied
by hand, one resource group at a time, with the plan output checked before
every apply. There's no remote state backend either (state is local);
worth moving to an S3 backend if a second person ever needs to run
`terraform apply`.

| File | What it defines |
|------|------------------|
| `versions.tf` | Pins the Terraform CLI and AWS/archive provider versions |
| `providers.tf` | The AWS provider (`eu-west-2`) plus an aliased `us-east-1` one, required only because CloudFront certificates must be requested there |
| `variables.tf` | Every configurable value — domain name, budget threshold, GitHub repo, etc. |
| `outputs.tf` | Values printed after `apply`: ACM's DNS validation records, CloudFront's own domain, the contact form's test URL, and the GitHub Actions role ARN |
| `s3.tf` | The private site bucket, fully public-access-blocked, encrypted at rest, readable only by this CloudFront distribution |
| `acm.tf` | The TLS certificate for `hopecc.org.uk` + `www`, validated via DNS records added by hand in NetNerd (DNS isn't on Route 53) |
| `cloudfront.tf` | The CDN distribution itself: both origins, the `/api/*` routing, the clean-URL fix, and the custom 404 page mapping — see below |
| `iam.tf` | The two brothers' read-only + sandbox IAM users, and the "must have MFA" enforcement policy |
| `sandbox.tf` | A separate, low-stakes S3 bucket the brothers can freely read/write, with a 30-day auto-expiry |
| `billing.tf` | An AWS Budget ($/month cap — AWS Budgets always runs in USD, regardless of GBP billing — three warning tiers, emailed to three addresses) |
| `ses.tf` | The verified email identity (`info@hopecc.org.uk`) the contact form sends from |
| `lambda.tf` | The contact form Lambda, its IAM role, and its narrow SES-send permission |
| `api-gateway.tf` | The one HTTP API and its `POST /api/contact` route |
| `decap-oauth.tf` | The Decap CMS OAuth proxy Lambda, its `GET /auth` and `GET /callback` routes, and its narrow SSM-read permission |
| `github-actions-oidc.tf` | The GitHub OIDC trust relationship and the deploy role's permissions (see CI/CD below) |

**AWS resources this creates** (account `249994635027`, region `eu-west-2`
unless noted) — these are identifiers, not secrets, so they're fine to have
here for reference:

| Resource | Name / ID |
|----------|-----------|
| Site bucket | `hopecc-website-249994635027` |
| Sandbox bucket | `hopecc-website-sandbox-249994635027` |
| CloudFront distribution | `E26BTS9MBN5LNH` (`d3jmbi4qqbxnbe.cloudfront.net`) |
| CloudFront OAC | `E2Q0CFO958IOWX` |
| ACM certificate | `us-east-1`, covers `hopecc.org.uk` + `www.hopecc.org.uk` |
| HTTP API | `b5emulwcc6` — serves both the contact form and Decap OAuth |
| Lambda functions | `hopecc-website-contact-form`, `hopecc-website-decap-oauth` (both `nodejs22.x`) |
| GitHub OIDC deploy role | `hopecc-website-github-actions-deploy` |
| AWS Budget | `hopecc-website-monthly-budget` ($10/month, 3 tiers) |

### Clean URLs (the CloudFront Function)

A private S3 bucket with CloudFront has no equivalent of S3's own
"website hosting" mode, so there's no automatic resolution of a folder
path (`/admin`, `/contact/`) to its `index.html`. Without a fix, visiting
almost any page directly (not just via an in-site link) returned a masked
403. `cloudfront.tf`'s `aws_cloudfront_function.rewrite_clean_urls` fixes
this on every request, with one important distinction:

- A path that **already ends in `/`** gets `index.html` silently appended —
  safe, since the browser's address bar already shows a directory.
- A path **missing its trailing slash** (`/admin`, not `/admin/`) gets a
  real `301` redirect to the same path *plus* a slash, rather than a
  silent rewrite. This matters specifically for Decap CMS: its admin
  screen fetches `config.yml` using a path *relative to the browser's
  address bar*, so silently serving `/admin`'s content without updating
  the address bar broke that fetch. Redirecting fixes the address bar
  first, so the relative fetch resolves correctly afterwards.

### The custom 404 page

S3 returns a **403**, not a 404, for a missing object — it can't
distinguish "this doesn't exist" from "you're not allowed to know if it
exists" without leaking bucket contents, so it defaults to the more
restrictive answer. `cloudfront.tf`'s `custom_error_response` maps that
403 to a real 404 response, served from `/404.html` (built from
`src/pages/404.astro`, styled to match the rest of the site rather than
showing a generic error page).

### The contact form & Decap CMS login

Both are small Lambda functions behind the same API Gateway HTTP API,
reached through CloudFront's `/api/*` routing so the browser never leaves
the site's own domain (no CORS involved):

- **Contact form** (`POST /api/contact`) — validates the submission,
  sends it via SES to `info@hopecc.org.uk`. If the request fails for any
  reason, `contact.astro`'s form falls back to opening the visitor's own
  email app, pre-filled with their message, so a bad moment for the API
  never costs a real enquiry.
- **Decap OAuth proxy** (`GET /auth`, `GET /callback`) — stands in for
  the OAuth exchange Netlify would normally provide, so `/admin`'s GitHub
  login works from a plain S3 + CloudFront site. The GitHub OAuth App's
  client ID is a public identifier (safe to commit; see `variables.tf`);
  its client **secret** lives only in SSM Parameter Store
  (`/hopecc-website/decap-oauth/github-client-secret`, `SecureString`) and
  is never written to Terraform state or this repo. Confirmed working
  end-to-end on the live CloudFront domain, not just local dev.

### CI/CD

`.github/workflows/deploy.yml` runs on every push to `main`:

1. Check out the repo, set up Node 22, pin `npm@12` (see the `allowScripts`
   note below), `npm ci`, `npm run build`.
2. Authenticate to AWS via **OIDC** — GitHub issues a short-lived signed
   token; `github-actions-oidc.tf`'s trust policy only accepts one scoped
   specifically to this exact repo and the `main` branch. No AWS access
   keys are stored as a GitHub secret at all.
3. `aws s3 sync dist/ s3://hopecc-website-249994635027 --delete`
4. `aws cloudfront create-invalidation` on the one distribution, so
   changes appear immediately rather than waiting for cached copies to
   expire.

The deploy role's permissions are scoped to exactly those two actions on
exactly this bucket and this distribution — nothing broader.

**Rollback:** `git revert` the commit, push, let the pipeline redeploy.
Deliberately simple — no S3 versioning or "keep last N builds" scheme, both
because it needs zero extra infrastructure and because it's easy to explain
to a future non-technical maintainer.

**`allowScripts` gotcha:** npm 12 blocks dependency install scripts unless
the package.json's `allowScripts` lists the *exact resolved* version from
`package-lock.json` (not just the package name). If a dependency with a
native build step (`sharp`, `esbuild`) is ever bumped, double check
`allowScripts` still matches the lockfile's resolved version — a stale pin
here fails silently at `npm ci` time in CI, not at `npm install` time
locally.

### A couple of stale comments, not yet cleaned up

Two comments in the Terraform/config that were accurate when written are
now out of date (nothing broken — just worth a tidy-up commit sometime):
`public/admin/config.yml`'s header still says to hold off pushing until
OAuth is confirmed working (it has been, since Session 4); `cloudfront.tf`'s
`custom_error_response` comment still says to check whether `404.astro`
exists yet (it does, added the same session).

---

## Content editing today vs. the plan

**As of Day 5, the "Core scope" content is CMS-editable via Decap CMS:**
service times, activity cards, gallery photos, the Romania village carousel,
mission stats (India/Romania), and prayer points. These now live as JSON
files in `src/data/` (see below) instead of being hardcoded inside the
`.astro` pages, and `public/admin/config.yml` defines the Decap CMS forms
for editing them.

**Everything else** — hero text, page copy, contact details, form fields,
the safeguarding PDF link, etc. — is still a direct code edit via the
`EDIT:` comment convention. See `MAINTENANCE-GUIDE.md` for the
non-technical walkthrough of both.

### ✅ Decap CMS login works on the live site

`/admin` is fully wired up: real GitHub login, confirmed working end-to-end
on the live CloudFront domain (not just local dev). The OAuth proxy that
makes this possible — a small Lambda behind API Gateway, since a plain S3 +
CloudFront site has nothing like Netlify's built-in OAuth support — is
covered in [Deployment & infrastructure](#deployment--infrastructure)
above. `config.yml`'s `backend.base_url` points at it already.

The CMS config can still be tested fully offline with no AWS/GitHub
involved at all — see the "Testing Decap locally" comment at the top of
`public/admin/config.yml` (`npx decap-server` + `npm run dev`, then visit
`localhost:4321/admin`). Handy for trying out a new field layout before
touching the live config.

### `/admin` script pinning (Day 6b hardening pass)

`public/admin/index.html` loads Decap CMS from unpkg. It used to reference
`decap-cms@^3.0.0`, which let unpkg serve whatever the newest matching
release was on every page load, with no check that the file hadn't
changed. It's now pinned to an exact version with a Subresource Integrity
(SRI) hash, so the browser won't run the script if the bytes it receives
don't match what was verified. Since this script handles GitHub-auth
credentials with push access to `main` (the OAuth proxy has been live
since Session 4), this was worth locking down before that shipped rather
than after.

This means the script **no longer auto-updates**. To bump the Decap
version in future: `npm install decap-cms@<new-version>` from the npm
registry, compute the sha384 hash of the resulting
`node_modules/decap-cms/dist/decap-cms.js`, and update both the version
number and the `integrity` attribute in `public/admin/index.html`
together — never hand-edit or guess the hash.

One caveat worth knowing: `dist/decap-cms.js` is webpack code-split and
dynamically loads further chunk files from unpkg at runtime as different
CMS features are used. The SRI hash only covers the entry file the
`<script>` tag points at — it doesn't extend to those chunks. Fully
closing that gap would mean self-hosting the whole `dist/` folder instead
of pulling from unpkg; not needed now, but worth remembering if the
threat model here ever tightens further.

### The `src/data/` JSON files

| File | Used by | What it holds |
|------|---------|----------------|
| `services.json` | `index.astro` (times strip) + `whats-on.astro` (Services section) | Service times — editing this once keeps both pages in sync (previously these were two separate hardcoded lists, a known source of drift) |
| `activities.json` | `whats-on.astro` | Rocky Kids, Fusion Youth, Dadz, Coffee N Chat cards |
| `gallery.json` | `whats-on.astro` | "Life at Hope" photo gallery |
| `romania-carousel.json` | `mission/romania.astro` | The sliding village photo carousel |
| `mission-stats.json` | `mission.astro` (overview cards) + `mission/india.astro` + `mission/romania.astro` | Headline numbers — same drift-prevention benefit as `services.json`. Each stat has a `showOnOverview` flag controlling whether it appears on the summary card |
| `prayer-points.json` | `mission/india.astro` + `mission/romania.astro` | "How to Pray" lists |

One small content fix made during this migration: the India "baptisms" stat
had two different labels in the two places it appeared ("Baptised
believers" on the overview card vs. "New baptisms" on the full page) — now
unified to "New baptisms" everywhere, sourced from the same file. Same for
two of the Romania stat labels (shortened to match between the overview
card and the full page).

**Not yet built:** the "Full scope" option (making every remaining
`EDIT:`-marked field CMS-editable) was considered and explicitly not
chosen for now — see Day 5 notes for the reasoning.

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
| 5 | Decap CMS setup (config, GitHub OAuth app) | ✅ Done — config.yml + data extraction complete. Real login went live in the AWS deployment phase below (Session 3) |
| 6 | CMS testing + maintainer instructions for `/admin` | ✅ Done — hands-on testing complete, all findings resolved |
| 6b | Final pre-AWS audit (security/performance sweep before Phase 3) | ✅ Done — dead `/admin` redirect comment corrected, `noindex` added to the CMS admin screen, this status table updated |
| 6c | Admin panel hardening — Decap CDN script pinned to an exact version with an SRI hash (was an unpinned `^3.0.0` range) | ✅ Done — see "`/admin` script pinning" in Content editing section |
| 7+ | AWS deployment (S3, CloudFront, ACM, Lambda, API Gateway) + GitHub Actions CI/CD | ✅ Done — see the AWS deployment table below |
| Last | DNS cutover, launch, wind-down + ownership handover | In progress — see below |

**AWS deployment (this ran as its own set of sessions, tracked separately
since it's infrastructure work rather than code):**

| Session | Task | Status |
|---------|------|--------|
| 1 | AWS foundations + static hosting (S3, CloudFront, ACM, IAM, budget) | ✅ Done |
| 2 | Contact form backend (Lambda, API Gateway, SES) | ✅ Done |
| 3 | Decap OAuth proxy + `/admin` routing | ✅ Done — real GitHub login confirmed working end-to-end on the live CloudFront domain |
| 4 | CI/CD, rollback strategy, package-manager confirmation | ✅ Done — also caught and fixed two bugs (clean URLs, missing 404 page) and one commit gap (`config.yml`'s `base_url`) that would otherwise have surfaced during DNS cutover |
| 5 | DNS cutover, launch, wind-down + ownership handover to Ian | In progress — DNS hasn't been pointed at CloudFront yet; this is the last planned step |

See [Deployment & infrastructure](#deployment--infrastructure) above for
what all of this actually built.

---

## Contact

Hope Community Church, Deveron Way, Hinckley, Leicestershire, LE10 0XD
Registered Charity No. 1108872
info@hopecc.org.uk
