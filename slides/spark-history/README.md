# Spark History Server: introduction (Slidev)

Short slide deck (8 content slides, about 10 minutes) before the lab `cdp-workshop/16-basics-spark-history`:

- Why a History Server, and where it sits (driver writes the event log, History Server reads it)
- Running (incomplete) against completed applications
- Anatomy: application, job, stage, task
- One tab, one question; what to look for (skew, shuffle, GC, failed attempts)
- How the lab links UI rows back to code, and a map of the nine lab steps

Port numbers, event log paths and retention settings are not on the slides: they differ per cluster and come from the handout.

## Run locally

```bash
npm install
npm run dev
```

Opens http://localhost:3030. Useful keys: `o` slide overview, `d` dark mode, `f` fullscreen.

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
| `slides.md` | Title slide and import of the theory part |
| `pages/01-theory.md` | All theory slides |
