# Slides and overview page

Slide decks (Slidev) for modules of this workshop, and the script that builds the GitHub Pages site.

| Deck | Module |
|------|--------|
| [oozie](oozie/README.md) | 08 Basics: Oozie in Hue |
| [livy](livy/README.md) | 09 Basics: Spark via Livy |

## What gets published

```
index.html          overview: platform component map plus all modules (lab links to GitHub, slides icon where a deck exists)
icons/              product logos used by the component map
slides/oozie/       deck
slides/livy/        deck
```

The overview page is generated from the module table in the root `README.md`. Every `<module>/lab/lab_*.md` is linked to its page on GitHub. The slides icon appears for modules that have a deck.

## Component map

Above the module table the page shows the platform stack (tools, orchestration, engines, data, storage, security, management) as an inline SVG. Clicking a component highlights the modules that use it (several components can be combined); hovering a module row shows its components in the map. Without JavaScript the map is static.

| File | Purpose |
|------|---------|
| `site/components.json` | Layers, side bars, components (logo, role, position) and the `modules` object that maps a module ID to its components |
| `site/map.mjs` | Renders the SVG and holds its styles |
| `site/icons/` | Logos (local files, no CDN) |

Add a module: add its row to the README table, then list its components under `modules` in `components.json` (the build fails on unknown module IDs or component IDs). Add a component: add an entry under `nodes` and drop the logo into `site/icons/`. A box with `"tech": "hive"` highlights together with the box whose ID is `hive`.

## Add a deck

1. Create `slides/<name>/` as a Slidev project (copy an existing deck).
2. In its `package.json` add `"workshop": { "module": "<id>" }` with the module ID from the README table (for example `"07"`).
3. Push to `main`. The workflow builds every folder in `slides/`.

## Privacy: no third-party requests

The published pages load nothing from third-party hosts, so no visitor IP address is sent to Google or a CDN:

- Fonts (Nunito Sans, Fira Code; SIL OFL) are bundled from the `@fontsource/*` npm packages via each deck's `style.css`. `fonts: provider: none` in `slides.md` turns off Slidev's Google Fonts loading.
- The favicon is `public/favicon.png` (`favicon:` in `slides.md`) instead of Slidev's default jsdelivr URL.
- `build-site.mjs` fails the build if any built page or stylesheet references an external `http(s)` host. Mermaid diagrams and code highlighting run in the browser.

Keep it that way when you add a deck: copy `style.css`, the `fonts`/`favicon` lines of an existing `slides.md`, and avoid external images, iframes and `plantuml` code blocks (Slidev renders those through plantuml.com).

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
