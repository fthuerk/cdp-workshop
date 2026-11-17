# Apache Kafka: introduction (Slidev)

Short slide deck that introduces Apache Kafka before the lab `cdp-workshop/15-basics-kafka`:

- What Kafka is and where it sits in a CDP cluster
- Topics, partitions, offsets and keys
- Brokers, replicas, leader and in-sync replicas
- Producers, consumers, consumer groups, offsets and lag
- Retention
- Security: Kerberos login of a client (`SASL_SSL`, `GSSAPI`, ticket cache) and authorization with Ranger
- Command-line tools, limits, and a map from the lab sections to the concepts

Sources: [Apache Kafka documentation](https://kafka.apache.org/documentation/) (design, producer and consumer configs, security) and the Cloudera Runtime documentation for Kafka (Kerberos client configuration, Ranger authorization).

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
| `public/images/` | Screenshot of the platform component map with Kafka highlighted |
