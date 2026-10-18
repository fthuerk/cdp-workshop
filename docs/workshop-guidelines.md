# Workshop authoring guidelines

Use this document whenever you add or revise a **module**, **lab**, **self-check script**, or **trainer material**. It keeps participant experience consistent across the curriculum.

**Related docs**

| Document | Role |
|----------|------|
| [concept.md](concept.md) | Curriculum sequence, learning objectives, use-case data layout |
| [simplicity.md](simplicity.md) | Scripts and tooling — stay boring and CLI-first |
| [.cursor/rules/no-customer-identifiers.mdc](../.cursor/rules/no-customer-identifiers.mdc) | No end-customer names in this git repo |

**Reference module:** [01-basics-hdfs](../01-basics-hdfs/) (lab, check script, trainer split, HDFS paths).

---

## Audiences — keep them separate

| Audience | Reads | Writes / runs |
|----------|--------|----------------|
| **Participant** | Module `README.md`, `lab/lab.md`, `lab/troubleshooting.md` | Commands in the lab; `lab/check.sh`; `00-setup/participant/check_env.sh` |
| **Trainer** | `trainer/notes.md`, `trainer/demos.md` | Live demos; timing; when to skip fallbacks |
| **Admin** | `00-setup/admin/`, `setup/`, `config.env` | Bootstrap, module `setup.sh` / `verify.sh`, Ranger policies |

**Participant labs must not** point people at `config.env`, bootstrap scripts, or other admin-only wiring. If a path or URL differs per cluster, say “adjust if your trainer gave another value” and show the variable (e.g. `WORKSHOP_ROOT`), not the config file name.

Trainer and troubleshooting docs **may** link to setup scripts when something requires intervention.

---

## Module layout (repository)

Each hands-on module should follow the same skeleton:

```
NN-short-name/           # e.g. 01-basics-hdfs, 03-basics-hive
  README.md              # participant entry: time, prerequisites, goals, link to lab
  lab/
    lab.md               # numbered hands-on sections
    check.sh             # non-interactive self-check (exit 0/1)
    troubleshooting.md   # common failures; trainer escalation where needed
  trainer/
    notes.md             # pacing, pitfalls, answers to check questions
    demos.md             # optional live-only steps (not duplicated in lab)
  setup/                 # admin only
    setup.sh
    verify.sh
    teardown.sh          # optional
```

Module **00-setup** is shared bootstrap; later modules depend on it but do not repeat full environment setup.

---

## Naming: repo folder vs HDFS paths

- **Repo folder:** `NN-<track>-<technology>` (e.g. `01-basics-hdfs`, `10-advanced-hive`).
- **HDFS under `${WORKSHOP_ROOT}`:** short module slug **without** “basics/advanced” (e.g. `01-hdfs`, `03-hive`).

Shared use-case data always lives at `${WORKSHOP_ROOT}/data/<dataset>/`. Module-specific assets live under `${WORKSHOP_ROOT}/<module-slug>/` (lab files, secrets for demos, etc.).

Document the HDFS slug in the lab intro, for example:

```bash
export HDFS_LAB="${WORKSHOP_ROOT}/01-hdfs/lab"
```

---

## Participant identity (`WORKSHOP_USER`)

Every `lab/lab.md` starts with the same pattern:

1. Export the participant’s Kerberos short name once.
2. `kinit` using that variable.
3. Use **`WORKSHOP_USER` everywhere** in lab commands (HDFS home, local temp file suffixes). Do not mix `<your_user>`, `$USER`, and `${USER}` in participant instructions.

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
# module-specific paths below, e.g. HDFS_LAB=...
```

`WORKSHOP_USER` must match the principal used for `kinit` and the HDFS `/user/...` path the lab creates.

**Self-check scripts** should resolve the same identity:

```bash
WS_USER="${WORKSHOP_USER:-${USER}}"
USER_HOME="/user/${WS_USER}"
```

Participants can `export WORKSHOP_USER="${USER}"` on the edge node if their shell already matches their login.

---

## Lab document structure

Run sections **in order**. Separate core sections from stretch.

### Voice in `lab/lab.md`

The reader **is** the person doing the lab. Write in **second person** (`you` / `your`).

- Do **not** refer to “participants”, “learners”, or “users” in the third person.
- Do **not** describe steps as “intended outcomes” of an exercise — state what **you** should see, hear, or get from the shell (including expected errors).
- Say “ask your instructor” (or similar) when you need help; reserve “trainer/admin” wording for `trainer/` and `setup/` docs, not the lab body.

Each numbered section includes:

1. **Goal** — one sentence, outcome-oriented.
2. **Brief context** — one or two sentences before each command block: why this step matters, what to notice, or how it ties to the use case. Split long command sequences into smaller blocks with prose between them; avoid five-line paste-only strips.
3. **Commands** — copy-paste blocks using exported variables.
4. **Check question** (optional) — ties the step to the grid monitoring use case or platform concept. Answer keys live in `trainer/notes.md`, not in the lab.

Do **not** paste full sample transcripts or “capture on cluster” TODO blocks. Success is defined by what **you** observe in the shell and by `check.sh` where applicable.

**Reading command output** is encouraged when a command prints **no column headers** or dense text: one short sentence or bullet list naming each column/field (exact numbers will differ on your cluster). Keep it local to the step — not a copy of your entire terminal scroll.

Optional UI steps (Hue, Knox) must be labeled **Optional** and must not be required to finish the core lab.

End the lab with:

- **Stretch (optional)** — extras for fast groups.
- **Self-check** — path to `./<module>/lab/check.sh` and link to `troubleshooting.md`.

Align section themes with [concept.md — Didactic pattern](concept.md#didactic-pattern-every-module): orient → inspect/apply → relate to governance or pipeline where natural.

---

## Command blocks — style rules

- Prefer **direct cluster CLIs** (`hdfs`, `yarn`, `beeline`, `spark-submit`, etc.). See [simplicity.md](simplicity.md).
- **Export before use:** any variable referenced in a section must appear in the intro or at the start of that section.
- Quote paths: `"/user/${WORKSHOP_USER}/file"`.
- Use **real workshop data** under `${WORKSHOP_ROOT}/data/...`; avoid generic toy datasets (`id,name,value`).
- **Teach exploration:** when finding trash paths, block locations, or log snippets is the learning goal, give listing commands and a placeholder (e.g. `"<path-to-hosts-in-trash>"`) instead of `awk`/`grep` one-liners that compute the answer.
- Avoid defensive shell noise in labs (`2>&1 || true`, nested pipes purely for pretty output) unless teaching shell itself.
- **Never more than 3 command lines in a row without a `#` comment.** Longer blocks get a short comment line before each group of up to 3 commands (blank line between groups).
- Keep blocks **readable aloud** — one logical step per line; no hidden magic.
- After a block, add a **short outcome cue** when it is not obvious (e.g. “You should see three files in the listing” or “You should get permission denied on the last command”).
- When output has **no headers**, explain columns right after the block (see `-count`, `-du`, `fsck` in [01-basics-hdfs/lab/lab.md](../01-basics-hdfs/lab/lab.md) section 3).

---

## Core vs trainer-only operations

If a step changes **shared** cluster state (replication on a demo file, quota, snapshot, Ranger policy):

- Either the **admin `setup.sh` already prepared** the right permissions so participants can run it in the lab, or
- The step belongs in **`trainer/demos.md`**, not in the participant lab.

Do not label shared-state exercises “optional — ask trainer” in the lab; either include them as a normal step (when policy and setup allow) or move them to trainer materials.

---

## Module `README.md` (participant)

Include:

- One-line tie to the **grid monitoring use case**
- **Estimated time** (core + optional stretch)
- **Prerequisites** (prior modules, valid ticket — link to 00-setup)
- **Learning goals** (3–6 bullets, observable skills)
- **Flow** table: concept (trainer) → lab → stretch → self-check
- Link to **trainer** materials for the instructor
- **Admin** block: three commands max (`bootstrap`, module `setup.sh`, `verify.sh`) — participants ignore this section
- **Next module** link

Use `/user/${WORKSHOP_USER}` (or “personal HDFS home”) in prose, not inconsistent placeholders.

---

## `lab/check.sh`

- Source `lib/common.sh` and `load_config` when the check needs `WORKSHOP_ROOT`.
- Require a valid Kerberos ticket (`require_kerberos_ticket`).
- Print `[PASS]` / `[FAIL]` lines; exit `1` if any fail.
- Check **outcomes** the lab promises (files present, secret unreadable, table exists), not implementation details.
- On failure, point to `lab/troubleshooting.md`.

Keep checks **fast** and safe to re-run.

---

## `lab/troubleshooting.md`

- Short sections keyed by **error symptom** or command failure.
- Participant fixes first (`klist`, paths, typo in `WORKSHOP_USER`).
- “Ask trainer” only when admin setup or policy is involved — link to the relevant `setup/` or bootstrap doc for trainers.
- Use the same `WORKSHOP_USER` / `WORKSHOP_ROOT` vocabulary as the lab.

---

## Trainer materials

- **`notes.md`:** timing per lab section, check-question talking points, when to use fallbacks from [concept.md](concept.md).
- **`demos.md`:** steps that are **live-only** or need elevated access; may reference `config.env` and admin paths.

Do not duplicate the full lab in `demos.md`; extend or dramatize it.

---

## New module checklist

Before marking a module **Ready** in the root README:

- [ ] Folder layout matches the skeleton above.
- [ ] HDFS module slug under `${WORKSHOP_ROOT}` documented in lab intro.
- [ ] `lab/lab.md` uses `WORKSHOP_USER` + standard opening exports.
- [ ] No participant-facing `config.env` or bootstrap references.
- [ ] Check questions have answers in `trainer/notes.md`.
- [ ] `lab/check.sh` passes on a clean participant run after admin setup.
- [ ] `setup/verify.sh` validates shared paths and permissions.
- [ ] Sample data paths match [concept.md — Use case data](concept.md#use-case-data-on-hdfs).
- [ ] No customer identifiers ([anonymization rule](../.cursor/rules/no-customer-identifiers.mdc)).
- [ ] Root [README.md](../README.md) catalog row updated (time, status, link).

---

## Config and secrets

- Cluster URLs, replication defaults, Ranger credentials: **`config.env`** (from `config.env.example`), used by **scripts only**.
- Labs use inline defaults (`WORKSHOP_ROOT=/2026_cdp_workshop`) with “adjust if needed,” not “see config.env.”
