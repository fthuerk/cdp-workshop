# Apache Oozie: theory and Hue lab (Slidev)

Slide deck with two parts:

1. **Theory**: what Oozie is, workflows, coordinators, bundles, actions, datasets
2. **Lab**: the Hue lab (module 08, basics Oozie) step by step, with screenshots

Every command, path, SQL statement and XML snippet sits in a code block. Hover over a block in the browser and click the copy button.

## Run locally

```bash
npm install
npm run dev
```

Opens http://localhost:3030. Useful keys: `o` slide overview, `d` dark mode, `f` fullscreen, arrow keys to navigate (animated steps appear on each click).

Presenter view with notes: http://localhost:3030/presenter/

## Build and export

```bash
npm run build     # static site in dist/
npm run export    # PDF (needs: npx playwright-chromium install chromium)
```

## Publish on GitHub Pages

Done by the workflow `.github/workflows/pages.yml` in the repository root: it builds this deck together with the other decks and an overview page of all labs. See [../README.md](../README.md).

## Files

| Path | Content |
|------|---------|
| `slides.md` | Title slide and imports of the two parts |
| `pages/01-theory.md` | Part 1: theory |
| `pages/02-lab.md` | Part 2: lab |
| `public/images/` | Screenshots from the lab (copied from the workshop repository) |
