# Updating the Hope Community Church Website — A Plain-English Guide

This guide is for **anyone** who needs to update text, photos, or contact
details on the church website — no coding experience required. You don't
need to understand how a website works to use this guide; you just need to
be able to open a file, find a word, change it, and save.

If you get stuck or something doesn't make sense, that's completely normal —
just ask whoever currently looks after the website's technical side for help.

---

## There's a proper "edit this website" screen — it's switched on

Six of the most-changed things on the site — **service times, activity
cards, gallery photos, the Romania photo carousel, mission stats, and
prayer points** — now have a proper point-and-click editing screen (Decap
CMS), so you don't need this guide at all for those six things.

**To use it:** go to the website's address with `/admin` on the end (e.g.
`hopecc.org.uk/admin`), and log in with GitHub when asked. Pick the section
you want, make your change in the form, and press **Publish** — the live
website updates itself automatically, usually within a minute or two. There
is no separate "save" step and nothing to pass along to anyone afterwards.

If you don't have a login for this yet, ask whoever looks after the
website's technical side to set one up for you — until then, those six
things can still be edited the old way, using their own small files (see
below), the same simple way as everything else in this guide.

---

## Before you start: one important thing

If you're using the `/admin` editing screen described just above, publishing
is automatic — skip straight to the rest of this guide.

For anything this guide asks you to edit as a file directly (most things
below), changing the file **still doesn't update the live website by
itself** — someone with access to the website's code needs to take your
change and send it live. So the process today is:

1. Open the file and make your change (following this guide).
2. Save the file.
3. Pass it to whoever manages the website's code.

The good news: getting it live from there is now quick and automatic on
their end too — once they add your change, the website updates itself
within about a minute, with no manual publishing step for them either.

---

## The one trick that makes this easy: searching for "EDIT:"

Every file that has editable content has been marked with little notes that
look like this:

```
<!-- EDIT: hero background image — swap for any landscape photo -->
```

or, in some files:

```
// EDIT: contact details
```

**You never need to touch anything else in the file.** Just:

1. Open the file in any text editor (Notepad, VS Code, even GitHub's own
   editor in a web browser all work fine).
2. Press **Ctrl+F** (Windows) or **Cmd+F** (Mac) to open the "Find" box.
3. Type `EDIT:` and press Enter.
4. It'll jump you straight to the next editable spot, with a short comment
   telling you what it is and how to change it.
5. Edit the actual words or numbers just below or after that comment line —
   never the comment itself, and never anything written in code-like
   symbols such as `<div>`, `class="..."`, or curly brackets `{ }`.

If you're ever unsure whether something is safe to change, a good rule of
thumb is: **if it's a sentence a normal person would read, it's safe to
edit. If it's technical-looking (lots of `<`, `>`, `{`, `}`, or CSS-looking
words), leave it alone and ask for help.**

---

## Common things people need to change

### 1. Service times

Service times used to live in two separate places that could drift out of
sync. They've now been combined into **one file**:

- **`src/data/services.json`** — open it, find the service you want (e.g.
  `"Sunday Morning Service"`), and edit its `"time"` value (the fuller
  version shown on the What's On page) and `"shortTime"` value (the short
  version shown on the homepage strip). Both values need updating if the
  time changes, but they're now right next to each other in one file
  instead of split across two page files.

### 2. Activities (Rocky Kids, Fusion Youth, Dadz, Coffee N Chat, etc.)

In **`src/data/activities.json`**, each activity card has:
- `title` — the name of the activity
- `img` — the photo shown (see "Swapping photos" below)
- `focalPoint` — which part of the photo to keep visible (see "Photos getting
  cropped oddly?" below)
- `tag` — the short label shown on the photo (e.g. "Children · Yrs 2–6")
- `schedule` — when it runs
- `price` — entry cost
- `description` — the short paragraph about it

To add a brand new activity card, copy one whole block (from `{` to `}`,
including the commas) and change the details inside.

*Tip: landscape photos work best here — see "Photos getting cropped oddly?"
just below for the ideal shape and size.*

### Photos getting cropped oddly?

The activity cards and the Romania photo carousel show photos inside a
fixed-size box, so the site automatically trims the edges off any photo
that doesn't perfectly match that shape — a bit like when a photo gets
cropped to fit a square frame on social media.

If an important part of the photo (a face, a sign, whatever matters) is
getting cut off, you don't need to resize or edit the photo yourself.
Instead, use the **"Photo position"** option next to that photo:
- In `src/data/activities.json` or `src/data/romania-carousel.json`, this
  is the `focalPoint` value.
- In the `/admin` editing screen, it's a dropdown labelled "Photo position"
  right under the photo — just pick "Keep the top in view", "Keep the
  bottom in view", etc., save, and check the page again.

This won't fix every case perfectly (it nudges the crop, it doesn't let
you zoom or drag like some apps do), but for most photos it's enough. If a
photo still doesn't look right after trying a few options, the simplest
fix is choosing a different photo that's already closer to a square or
landscape shape.

**Best photo shape and size to use in the first place**, so cropping is
rarely an issue:

- **Shape:** Landscape (wider than tall) — like a phone photo taken
  holding the phone sideways, not upright. Both the activity card boxes
  and the Romania carousel are wider than they are tall, so a landscape
  photo survives the crop far better than a portrait one.
- **Size:** At least **1200 × 800 pixels**. Most modern phone photos are
  already bigger than this — only worry if it's a very old or
  already-cropped image.
- **Main subject:** Try to keep faces or the key detail roughly in the
  **upper two-thirds** of the photo, not right at the very bottom edge.
- **Avoid:** Upright/portrait photos (like a vertical phone selfie) — these
  lose the most to cropping and are the ones most likely to need the
  "Photo position" dropdown above.

### 3. Photos (swapping an existing image)

Almost every photo on the site is referenced by a path like
`/images/Church-Front.jpg`. To swap a photo:

1. Find the new photo file.
2. Rename it to match the existing filename exactly (e.g. `Church-Front.jpg`),
   **or** give it a new name and update the path in the file to match.
3. Place it in the `public/images/` folder, replacing the old file if you
   reused the same name.
4. If you gave it a new filename, search for the old filename (e.g. search
   `Church-Front.jpg`) in the relevant page file and update the path there too.

**Adding a brand new photo to the "Life at Hope" gallery**: find
**`src/data/gallery.json`** and add a new line in the same format as the
others — no resizing needed, the gallery adjusts automatically to any photo
shape.

### 4. The Romania page's sliding photo carousel

The carousel photos live in **`src/data/romania-carousel.json`**. To add,
remove, or swap a photo:

1. Open the file — you'll see a short list of photo filenames (e.g.
   `Village_1.png`, `Village_2.png`, `Village_3.png`) with a description
   for each.
2. To **swap** a photo, replace the file in `public/images/` (same
   filename) or update the filename in the JSON to match a new one — same
   as any other photo (see "Photos" above).
3. To **add or remove** a photo, copy or delete one whole `{ "src": ...,
   "alt": ... }` entry, including the closing comma if needed.

You **don't** need to add or remove anything else. The little gold dots
below the photos are created automatically to match however many photos are
there — one dot per photo, no matter how many you add or take away.

*Tip: landscape photos work best here too — see "Photos getting cropped
oddly?" above for the ideal shape and size, and the "Photo position"
dropdown if a photo's important part gets cut off.*

### 5. Numbers and stats (mission pages)

The India and Romania mission pages show headline numbers (like "200+ Easter
gathering" or "23 children sponsored"). These now live in **one shared
file**, **`src/data/mission-stats.json`**, under an `"india"` list and a
`"romania"` list. Each number has a `"value"`, a `"label"`, and a
`"showOnOverview"` true/false — the ones marked `true` also appear on the
Mission page's summary cards (up to three per country), so **updating a
number here keeps the summary card and the full country page in sync
automatically** — no more updating two places by hand.

### 6. Prayer points

Prayer points for both India and Romania now live in one file,
**`src/data/prayer-points.json`**, under an `"india"` list and a
`"romania"` list. Each entry is one line of text — add, remove, or reword
lines freely.

### 7. Contact details (phone, email, address)

Contact details appear in **several different files**, since different pages
show different combinations of them:

- **`src/components/Footer.astro`** — appears on every page, at the bottom.
- **`src/pages/contact.astro`** — the main Contact page.
- **`src/pages/safeguarding.astro`** — has its own safeguarding-specific
  contact box.
- **`src/pages/privacy-policy.astro`** — has a "Data Controller" contact box.

If the church's phone number, general email, or address changes, search for
the old value (e.g. search `01455 233798`) across each of these files one
at a time so nothing gets missed.

### 8. Safeguarding policy PDF

To replace the safeguarding policy document:

1. Place the new PDF file in `public/documents/`.
2. In **`src/pages/safeguarding.astro`**, search for `EDIT: PDF link` — there
   are two links pointing to the PDF filename (one to view, one to download).
   Update both to the new filename.
3. Just above that, search for `EDIT: PDF metadata` and update the "Issue"
   number and date badge so it matches the new document.

### 9. Social media links (Facebook, YouTube)

These appear in **`src/components/Footer.astro`** and **`src/pages/contact.astro`**.
Search for `facebook.com` or `youtube.com` in either file to find and update
the links.

### 10. Room hire checklist

The list of things someone needs to include in a room hire enquiry lives in
**`src/pages/contact.astro`**. Search for `EDIT: Room hire checklist` — each
bullet point is one `checklist-item` block you can edit, add to, or remove.

---

## A note on the "Watch & Listen" page

This page (`src/pages/watch-listen.astro`) is currently a "coming soon" page,
since the church doesn't yet have a live sermon archive or livestream set up.
There's already a ready-made structure sitting in the file, waiting to be
switched on once real sermon videos are available — a technical volunteer
will be able to activate this fairly quickly once YouTube video links are
ready to add. Nothing needs to be done here for now.

---

## A note on `Welcome.astro`

You may notice a file called `src/components/Welcome.astro`. This is a
leftover from when the website was first set up and isn't used anywhere on
the live site — you can ignore it completely. It's safe for a developer to
delete it in future; it doesn't affect anything.

---

## Quick reference: "I want to change..."

| What you want to change              | File(s) to open                                              |
|---------------------------------------|----------------------------------------------------------------|
| Service times                         | `src/data/services.json` — one file, feeds both the homepage and What's On |
| Activity cards (Rocky Kids, etc.)     | `src/data/activities.json`                                     |
| Gallery photos                        | `src/data/gallery.json`                                         |
| Any photo on any page                 | Find the page, swap the file in `public/images/`               |
| Romania photo carousel                | `src/data/romania-carousel.json` — add/remove a photo entry; dots update themselves |
| Mission stats/numbers                 | `src/data/mission-stats.json` — one file, feeds both the summary card and the full page |
| Prayer points                         | `src/data/prayer-points.json`                                   |
| Phone/email/address                   | `Footer.astro`, `contact.astro`, `safeguarding.astro`, `privacy-policy.astro` |
| Safeguarding PDF                      | `safeguarding.astro` (and add the new file to `public/documents/`) |
| Facebook/YouTube links                | `Footer.astro`, `contact.astro`                                 |
| Room hire checklist                   | `contact.astro`                                                 |

---

If in doubt, search `EDIT:`, make the smallest change you can, save, and pass
it along to your technical volunteer to publish. You won't break anything by
editing the words between the tags — just avoid touching anything written in
code symbols.
