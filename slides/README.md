# Slides and overview page

Slide decks (Slidev) for modules of this workshop, and the script that builds the GitHub Pages site.

| Deck | Module |
|------|--------|
| [oozie](oozie/README.md) | 08 Basics: Oozie in Hue |
| [livy](livy/README.md) | 09 Basics: Spark via Livy |

## What gets published

```
index.html          overview of all modules: lab links (to GitHub) and a slides icon where a deck exists
slides/oozie/       deck
slides/livy/        deck
```

The overview page is generated from the module table in the root `README.md`. Every `<module>/lab/lab_*.md` is linked to its page on GitHub. The slides icon appears for modules that have a deck.

## Add a deck

1. Create `slides/<name>/` as a Slidev project (copy an existing deck).
2. In its `package.json` add `"workshop": { "module": "<id>" }` with the module ID from the README table (for example `"07"`).
3. Push to `main`. The workflow builds every folder in `slides/`.

Decks use `routerMode: hash` in `slides.md`, so slide URLs survive a page refresh on GitHub Pages.

## Build locally

```bash
node slides/build-site.mjs --index-only --out /tmp/site    # overview page only (no npm install)
node slides/build-site.mjs --out /tmp/site --base /        # overview page and all decks
npx serve /tmp/site
```

Work on a single deck with `cd slides/<name> && npm install && npm run dev`.

## Publish

In the repository open **Settings, Pages** and set **Source** to **GitHub Actions**. After that every push to `main` that touches `slides/`, the README or a lab file runs `.github/workflows/pages.yml`.
