# Keep it simple

Workshop tooling should stay boring and obvious. Lab structure, audience split, and naming: [workshop-guidelines.md](workshop-guidelines.md).

- **Scripts do the next step** — e.g. admin setup runs `kinit` before HDFS commands; participants still `kinit` themselves for labs.
- **Prefer cluster CLIs** (`hdfs`, `beeline`, `yarn`) over wrappers, SDKs, or extra frameworks.
- **One small helper in `lib/`** beats copy-paste across modules.
- **Skip optional knobs** — no new config flags or abstraction layers unless a lab truly needs them.

When in doubt, choose the path a trainer can read aloud in one sentence.
