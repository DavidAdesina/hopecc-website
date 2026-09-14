// src/lib/page-visibility.js — Hope Community Church
// ─────────────────────────────────────────────────────────────────────────
// WHAT THIS FILE DOES
//   The single place that reads src/data/page-visibility.json and answers
//   "is this page switched on, and if not, what should it say?" for any
//   page, plus for Navbar.astro/Footer.astro deciding whether to show a
//   link to it. Every toggleable page and both nav components import this
//   — nothing reads page-visibility.json directly anywhere else, so the
//   "what happens if the id is missing / the file is broken" safety rule
//   below only has to be written once, correctly, in one place.
//
// SAFETY RULE — READ BEFORE CHANGING THIS FILE:
//   getPageStatus() only ever returns enabled: false if the CMS file
//   explicitly says so for that exact id. Any other situation — the id
//   isn't in the file, the entry is missing a field — returns
//   enabled: true (the page shows normally). This is deliberate: a typo
//   or a build-time glitch should make a page fail visible, not fail
//   invisible. A page silently disappearing is far more likely to go
//   unnoticed than a page staying up that someone meant to hide, and for
//   this site specifically it's much safer to lean that way.
//
// ONE THING THIS SAFETY NET CANNOT CATCH — read this once, then it's not
// something you need to think about day to day:
//   If src/data/page-visibility.json ever becomes invalid JSON (not just
//   "missing an id" — genuinely broken syntax, like a stray comma), the
//   `import` line below fails at build time, before any of the code in
//   this file even runs. That fails the ENTIRE site build, not just the
//   Mission pages — confirmed directly in testing. In practice this
//   should never happen from normal Decap CMS use: the "Show/Hide Pages"
//   screen only offers a tick-box and a text field, which can't produce
//   broken JSON — this is only reachable by someone hand-editing this
//   file outside the CMS. And CONFIRMED against the real
//   .github/workflows/deploy.yml (Sept 2026): "Build site" is a single
//   ordinary step, no continue-on-error, sitting strictly before
//   "Configure AWS credentials", "Sync build to S3" and "Invalidate
//   CloudFront cache" in the same job — GitHub Actions' default
//   behaviour stops a job at its first failed step, so a broken build
//   here never reaches S3 or CloudFront at all. The live site simply
//   doesn't update; it isn't touched.
// ─────────────────────────────────────────────────────────────────────────
import pageVisibility from '../data/page-visibility.json';

export const DEFAULT_UNAVAILABLE_MESSAGE =
  "We're updating this page and it'll be back soon. Thank you for your patience.";

/**
 * Look up one page's current status by id.
 * @param {string} id
 * @returns {{ enabled: boolean, message: string }}
 */
export function getPageStatus(id) {
  try {
    const entry = pageVisibility?.pages?.find((p) => p.id === id);
    if (!entry) return { enabled: true, message: '' };
    return {
      // Only an explicit `false` turns a page off. `true`, missing, or any
      // other value all mean "on" — so a blank/new CMS entry defaults on.
      enabled: entry.enabled !== false,
      message: (entry.customMessage || '').trim() || DEFAULT_UNAVAILABLE_MESSAGE,
    };
  } catch {
    // Guards against unexpected shapes in the data (e.g. "pages" isn't
    // an array) — NOT JSON syntax errors, which fail at the import line
    // above, before this function ever runs. See the file-level comment.
    return { enabled: true, message: '' };
  }
}

/**
 * Used only by Navbar.astro/Footer.astro: is this id enabled? (No message
 * needed for a nav link — it either shows or it doesn't.)
 * @param {string} id
 * @returns {boolean}
 */
export function isPageEnabled(id) {
  return getPageStatus(id).enabled;
}
