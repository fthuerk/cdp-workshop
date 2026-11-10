# Apache Oozie: introduction (Slidev)

Short slide deck on the basic functionality of Apache Oozie: what it is, workflows, coordinators, bundles, actions, datasets, variables, and how Hue fits in. The hands-on lab is not part of the deck; it is in `08-basics-oozie/lab/lab_basics_oozie.md`.

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
| `slides.md` | Title slide, platform slide and import of the theory part |
| `pages/01-theory.md` | All slides |
| `public/images/` | Navigation diagram used on the second slide |
