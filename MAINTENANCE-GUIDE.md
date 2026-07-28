# Updating the Hope Community Church Website — A Plain-English Guide

This guide is for **anyone** who needs to update text, photos, or contact
details on the church website — no coding experience required. You don't
need to understand how a website works to use this guide; you just need to
be able to open a file, find a word, change it, and save.

If you get stuck or something doesn't make sense, that's completely normal —
just ask whoever currently looks after the website's technical side for help.

---

## Before you start: one important thing

Right now, changing a file **doesn't update the live website by itself**. A
developer or technical volunteer still needs to take the changed file and
publish it. So the process today is:

1. Open the file and make your change (following this guide).
2. Save the file.
3. Pass it to whoever manages the website's code, so they can publish it.

This will get simpler in future — there's a plan to add a proper "edit this
website" screen (a bit like editing a Word document in a browser) that will
skip steps 2 and 3. Until then, this guide shows you what to change and
where, and someone technical will take care of getting it live.

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

Service times currently appear in **two separate places**, and both need to
be updated together if a time changes:

- **`src/pages/index.astro`** (the homepage) — look for the "SERVICE TIMES
  STRIP" section near the top of the file. Times like `10:30 am` and
  `6:00 pm` are written directly in the text.
- **`src/pages/whats-on.astro`** — look for the `regularServices` list near
  the top of the file. Each service has a `title`, a `time`, and a
  `description` you can edit.

⚠️ **These two places aren't linked to each other** — updating one won't
automatically update the other, so double-check both if a service time
changes.

### 2. Activities (Rocky Kids, Fusion Youth, Dadz, Coffee N Chat, etc.)

In **`src/pages/whats-on.astro`**, look for the `activities` list near the
top of the file. Each activity card has:
- `title` — the name of the activity
- `img` — the photo shown (see "Swapping photos" below)
- `tag` — the short label shown on the photo (e.g. "Children · Yrs 2–6")
- `schedule` — when it runs
- `price` — entry cost
- `description` — the short paragraph about it

To add a brand new activity card, copy one whole block (from `{` to `}`,
including the commas) and change the details inside.

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

**Adding a brand new photo to the "Life at Hope" gallery** (on
`whats-on.astro`): find the `galleryImages` list near the top of the file
and add a new line in the same format as the others — no resizing needed,
the gallery adjusts automatically to any photo shape.

### 4. The Romania page's sliding photo carousel

On **`src/pages/mission/romania.astro`**, the "Satu-Nou village" section has
a small set of photos that slide automatically. To add, remove, or swap a
photo:

1. Search for `EDIT:` near the carousel — it'll point you to the photo
   filenames (e.g. `Village_1.png`, `Village_2.png`, `Village_3.png`).
2. To **swap** a photo, replace the file in `public/images/` (same filename)
   or update the filename in the file to match a new one — same as any
   other photo (see "Photos" above).
3. To **add or remove** a photo, copy or delete one whole
   `<div class="carousel-slide">...</div>` block, including the image
   filename inside it.

You **don't** need to add or remove anything else. The little gold dots
below the photos are created automatically to match however many photos are
there — one dot per photo, no matter how many you add or take away.

### 5. Numbers and stats (mission pages)

The India and Romania mission pages show headline numbers (like "200+ Easter
gathering" or "23 children sponsored"). These numbers currently appear in
**two places each** that need to be kept in sync:

- The short summary version on **`src/pages/mission.astro`** (the "Our
  Mission Fields" cards) — search for `mission-stat`.
- The full version on the country's own page — **`src/pages/mission/india.astro`**
  or **`src/pages/mission/romania.astro`** — search for `stat-number`.

⚠️ If a number changes (e.g. more sponsored children, a new baptism count),
update it in **both** the summary card and the full country page, or the
two pages will show different figures.

### 6. Prayer points

On the India and Romania pages (`src/pages/mission/india.astro` and
`src/pages/mission/romania.astro`), search for `EDIT: prayer` or look for the
navy-blue "How to Pray" section. Each prayer point is one line in a list —
add, remove, or reword lines freely.

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
| Service times                         | `index.astro` **and** `whats-on.astro`                        |
| Activity cards (Rocky Kids, etc.)     | `whats-on.astro`                                               |
| Gallery photos                        | `whats-on.astro`                                                |
| Any photo on any page                 | Find the page, swap the file in `public/images/`               |
| Romania photo carousel                | `mission/romania.astro` — add/remove a `carousel-slide` block; dots update themselves |
| Mission stats/numbers                 | `mission.astro` **and** the relevant `mission/india.astro` or `mission/romania.astro` |
| Prayer points                         | `mission/india.astro` or `mission/romania.astro`               |
| Phone/email/address                   | `Footer.astro`, `contact.astro`, `safeguarding.astro`, `privacy-policy.astro` |
| Safeguarding PDF                      | `safeguarding.astro` (and add the new file to `public/documents/`) |
| Facebook/YouTube links                | `Footer.astro`, `contact.astro`                                 |
| Room hire checklist                   | `contact.astro`                                                 |

---

If in doubt, search `EDIT:`, make the smallest change you can, save, and pass
it along to your technical volunteer to publish. You won't break anything by
editing the words between the tags — just avoid touching anything written in
code symbols.
