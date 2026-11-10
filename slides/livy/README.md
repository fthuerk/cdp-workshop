# Apache Livy: introduction (Slidev)

Short slide deck that introduces Apache Livy before the lab `cdp-workshop/09-basics-livy`:

- What Livy is and why it exists
- Where it sits in a CDP cluster (clients, Knox, Livy, YARN, Hive Metastore) and what is inside the Livy server
- Sessions (life cycle, statements, request flow) and batches
- Identity: Knox, `doAs`, impersonation, access control
- Operations: session lifetime, recovery, high availability
- Limits, comparison with `spark-submit`, and a map from the lab sections to the concepts

Sources: [Apache Livy](https://livy.apache.org/) (REST API, programmatic API, `livy.conf` template) and the Cloudera Runtime documentation for **Livy for Spark 3** (Livy API, configuring the Livy server, Thrift server, active/passive HA, Hue Spark 3 engine).

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
