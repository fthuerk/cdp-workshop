#!/usr/bin/env node
// Builds the GitHub Pages site: an overview page of all modules plus every slide deck in slides/<name>/.
//
//   node slides/build-site.mjs                        # full build into _site/
//   node slides/build-site.mjs --index-only           # only the overview page (fast)
//   node slides/build-site.mjs --base /               # base path for local preview (default: /<repo>/)
//
// The module list comes from the catalog table in the root README.md, so there is nothing to maintain twice.
// Every lab file (<module>/lab/lab_*.md) is linked to its GitHub page. A deck is attached to a module by
// "workshop": { "module": "08" } in the deck's package.json.

import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const slidesDir = join(root, 'slides')

// ---- arguments ----
const args = process.argv.slice(2)
const argValue = (name) => {
  const i = args.indexOf(name)
  return i >= 0 ? args[i + 1] : undefined
}
const out = resolve(argValue('--out') ?? join(root, '_site'))
const indexOnly = args.includes('--index-only')

// ---- repository coordinates (for links to the lab files on GitHub) ----
function repoSlug() {
  if (process.env.GITHUB_REPOSITORY) return process.env.GITHUB_REPOSITORY
  const url = execFileSync('git', ['remote', 'get-url', 'origin'], { cwd: root, encoding: 'utf8' }).trim()
  const m = url.match(/github\.com[:/]([^/]+\/[^/]+?)(\.git)?$/)
  if (!m) throw new Error(`Cannot derive the GitHub repository from the remote: ${url}`)
  return m[1]
}
const slug = repoSlug()
const branch = process.env.GITHUB_REF_NAME ?? 'main'
const blobUrl = (path) => `https://github.com/${slug}/blob/${branch}/${path}`

// Slidev needs the absolute base path of the site: /<repo>/ on GitHub Pages.
const base = (argValue('--base') ?? `/${slug.split('/')[1]}/`).replace(/\/?$/, '/')

// ---- helpers ----
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
const firstHeading = (file) => readFileSync(file, 'utf8').match(/^#\s+(.+)$/m)?.[1].trim()

// ---- 1. module catalog from README.md ----
// Row: | 08 | [Basics: Oozie in Hue](08-basics-oozie/README.md) | Basics | ~70 min | Draft (...) |
function readModules() {
  const rows = []
  for (const line of readFileSync(join(root, 'README.md'), 'utf8').split('\n')) {
    const cells = line.split('|').map((c) => c.trim())
    if (cells.length < 5 || !/^(\d\d|[A-Z]\d)$/.test(cells[1])) continue
    const [, id, module, track] = cells
    const link = module.match(/^\[(.+)\]\((.+)\)$/)
    const title = link ? link[1] : module
    const dir = link ? dirname(link[2]) : null
    const labDir = dir && join(root, dir, 'lab')
    const labs = labDir && existsSync(labDir)
      ? readdirSync(labDir)
          .filter((f) => /^lab_.*\.md$/.test(f))
          .sort()
          .map((f) => ({ title: firstHeading(join(labDir, f)) ?? f, path: `${dir}/lab/${f}` }))
      : []
    // Modules without a lab folder (00-setup) link to their README.
    if (dir && labs.length === 0) labs.push({ title, path: `${link[2]}` })
    rows.push({ id, title, track, dir, labs })
  }
  return rows
}

// ---- 2. slide decks ----
function readDecks() {
  return readdirSync(slidesDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(join(slidesDir, d.name, 'package.json')))
    .map((d) => {
      const pkg = JSON.parse(readFileSync(join(slidesDir, d.name, 'package.json'), 'utf8'))
      const title = readFileSync(join(slidesDir, d.name, 'slides.md'), 'utf8').match(/^title:\s*(.+)$/m)?.[1]
      return { name: d.name, module: pkg.workshop?.module, title: title ?? d.name }
    })
}

function buildDeck(deck) {
  const cwd = join(slidesDir, deck.name)
  const run = (cmd, cmdArgs) => execFileSync(cmd, cmdArgs, { cwd, stdio: 'inherit' })
  console.log(`\n== building deck "${deck.name}" ==`)
  run('npm', [existsSync(join(cwd, 'package-lock.json')) ? 'ci' : 'install'])
  run('npx', ['slidev', 'build', '--base', `${base}slides/${deck.name}/`, '--out', join(out, 'slides', deck.name)])
}

// Privacy guard: the published pages must not load anything from third-party hosts (fonts, CDNs, trackers),
// because the visitor's IP address would be sent to them. Fails the build if a page or stylesheet does.
function assertNoExternalRequests(dir) {
  const found = []
  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name)
      if (e.isDirectory()) walk(p)
      else if (/\.(html|css)$/.test(e.name)) {
        const text = readFileSync(p, 'utf8')
        const refs = [
          ...text.matchAll(/<(?:link|script|img|iframe|source|video|audio)\b[^>]*?\b(?:src|href)=["'](https?:\/\/[^"']+)/g),
          ...text.matchAll(/url\(\s*["']?(https?:\/\/[^)"']+)/g),
          ...text.matchAll(/@import\s+(?:url\()?\s*["']?(https?:\/\/[^;)"']+)/g),
        ]
        for (const m of refs) found.push(`${p.slice(out.length + 1)}: ${m[1]}`)
      }
    }
  }
  walk(dir)
  if (found.length) throw new Error(`Third-party requests in the built site:\n  ${found.join('\n  ')}`)
}

// ---- 3. overview page ----
const slidesIcon =
  '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" ' +
  'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="1.5"/>' +
  '<path d="M12 16v4M8 20h8"/></svg>'

function renderIndex(modules, decks) {
  const deckByModule = new Map(decks.map((d) => [d.module, d]))
  const body = modules
    .map((m) => {
      const deck = deckByModule.get(m.id)
      const planned = !m.dir
      let labCell
      if (planned) labCell = `<span class="muted">${esc(m.title)}</span>`
      else if (m.labs.length === 1) labCell = `<a href="${blobUrl(m.labs[0].path)}">${esc(m.title)}</a>`
      else
        labCell =
          `<span>${esc(m.title)}</span><ul>` +
          m.labs.map((l) => `<li><a href="${blobUrl(l.path)}">${esc(l.title)}</a></li>`).join('') +
          '</ul>'
      const slidesCell = deck
        ? `<a class="slides" href="slides/${esc(deck.name)}/" title="Slides: ${esc(deck.title)}" aria-label="Slides: ${esc(deck.title)}">${slidesIcon}</a>`
        : ''
      return (
        `<tr class="${planned ? 'planned' : ''}"><td class="id">${esc(m.id)}</td><td>${labCell}</td>` +
        `<td class="slidecol">${slidesCell}</td><td>${esc(m.track)}</td></tr>`
      )
    })
    .join('\n')

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CDP workshop</title>
<style>
  :root { color-scheme: light dark; --muted: #6b7280; --line: #d1d5db; --accent: #0b6bcb; }
  @media (prefers-color-scheme: dark) { :root { --muted: #9ca3af; --line: #374151; --accent: #6cb2ff; } }
  body { font: 16px/1.5 system-ui, sans-serif; max-width: 62rem; margin: 2rem auto; padding: 0 1rem; }
  h1 { margin-bottom: .25rem; }
  p.lead { color: var(--muted); margin-top: 0; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; padding: .5rem .6rem; border-bottom: 1px solid var(--line); vertical-align: top; }
  th { font-size: .8rem; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }
  td.id { font-variant-numeric: tabular-nums; color: var(--muted); white-space: nowrap; }
  td.slidecol { width: 2rem; text-align: center; }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }
  a.slides { display: inline-flex; vertical-align: middle; }
  ul { margin: .25rem 0 0; padding-left: 1.1rem; }
  .muted { color: var(--muted); }
  .badge { font-size: .75rem; padding: .1rem .5rem; border-radius: 999px; border: 1px solid var(--line); white-space: nowrap; }
  .badge.ready { border-color: #16a34a; color: #16a34a; }
  .badge.draft { border-color: #d97706; color: #d97706; }
  footer { margin-top: 1.5rem; font-size: .85rem; color: var(--muted); }
</style>
</head>
<body>
<h1>CDP workshop</h1>
<p class="lead">Hands-on modules for Cloudera Data Platform. Click a module to open its lab on GitHub; the ${slidesIcon.replace('width="18" height="18"', 'width="14" height="14"')} icon opens the slide deck.</p>
<table>
<thead><tr><th>ID</th><th>Lab</th><th>Slides</th><th>Track</th></tr></thead>
<tbody>
${body}
</tbody>
</table>
<footer><a href="https://github.com/${slug}">Source on GitHub</a></footer>
</body>
</html>
`
}

// ---- main ----
const modules = readModules()
const decks = readDecks()
for (const d of decks) {
  if (!modules.some((m) => m.id === d.module))
    throw new Error(`Deck "${d.name}" points to module "${d.module}", which is not in the README catalog`)
}

rmSync(out, { recursive: true, force: true })
mkdirSync(out, { recursive: true })
if (!indexOnly) decks.forEach(buildDeck)
writeFileSync(join(out, 'index.html'), renderIndex(modules, decks))
writeFileSync(join(out, '.nojekyll'), '')
assertNoExternalRequests(out)
console.log(`\nSite written to ${out} (${modules.length} modules, ${decks.length} decks, base ${base})`)
