// Renders the platform component map (layered stack with side bars) as an inline SVG string.
// Data: components.json. Interaction (click to highlight) is added by the page script in build-site.mjs.
// Layout constants mirror the interactive navigation map, so both look the same.

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

const LOGO_MAX_HEIGHT = 30
const LOGO_MAX_WIDTH = 100

const layout = {
  labelAnchorX: 108,
  stackLeft: 120,
  coreWidth: 420,
  barWidth: 120,
  captionY: 20,
  frameTop: 34,
  headerHeight: 32,
  headerGap: 6,
  layerHeight: 56,
  layerGap: 4,
  boxPadX: 8,
  boxPadY: 4,
  barBoxHeight: 76,
  frameBottomPad: 8,
}

/** "Security & Governance" -> ["Security", "& Governance"] */
const splitLabel = (label) => {
  if (label.includes(' & ')) return label.split(' & ').map((part, i) => (i === 0 ? part : `& ${part}`))
  // Long labels without "&" wrap at the space (the label column is narrow).
  const words = label.split(' ')
  return label.length > 16 && words.length === 2 ? words : [label]
}

const textLines = (lines, x, y, cls, anchor) => {
  const lineHeight = 11
  const startDy = -((lines.length - 1) * lineHeight) / 2
  const tspans = lines
    .map((line, i) => `<tspan x="${x}" dy="${i === 0 ? startDy : lineHeight}">${esc(line)}</tspan>`)
    .join('')
  return `<text class="${cls}" x="${x}" y="${y}"${anchor ? ` text-anchor="${anchor}"` : ''}>${tspans}</text>`
}

export function renderMap(config, iconBase = 'icons/') {
  const { layers, bars } = config
  const layerTop = layout.frameTop + layout.headerHeight + layout.headerGap
  const layerPitch = layout.layerHeight + layout.layerGap
  const bodyHeight = layers.length * layerPitch - layout.layerGap
  const bodyBottom = layerTop + bodyHeight
  const frameBottom = bodyBottom + layout.frameBottomPad
  const frameHeight = frameBottom - layout.frameTop
  const coreLeft = layout.stackLeft
  const coreRight = coreLeft + layout.coreWidth
  const frameRight = coreRight + bars.length * layout.barWidth
  const vbWidth = frameRight + 12
  const vbHeight = frameBottom + 8
  const headerMidY = layout.frameTop + layout.headerHeight / 2 + 1

  const layerY = (id) => layerTop + layers.findIndex((l) => l.id === id) * layerPitch
  const barLeft = (id) => coreRight + bars.findIndex((b) => b.id === id) * layout.barWidth

  const boxOf = (node) => {
    if (node.layer) {
      const slotW = (layout.coreWidth - layout.boxPadX * 2) / node.cols
      return {
        x: coreLeft + layout.boxPadX + node.col * slotW,
        y: layerY(node.layer) + layout.boxPadY,
        w: slotW - 6,
        h: layout.layerHeight - layout.boxPadY * 2,
      }
    }
    // Bar nodes are spread evenly over the full height of the stack.
    const h = layout.barBoxHeight
    const gap = (bodyHeight - node.count * h) / (node.count + 1)
    return {
      x: barLeft(node.bar) + layout.boxPadX,
      y: layerTop + gap + node.index * (h + gap),
      w: layout.barWidth - layout.boxPadX * 2,
      h,
    }
  }

  const renderNode = (node) => {
    const box = boxOf(node)
    const captionLines = (node.showLabel ? 1 : 0) + (node.role ? 1 : 0)
    const captionHeight = captionLines > 0 ? captionLines * 11 + 3 : 0
    const logoArea = box.h - 8 - captionHeight
    const logoH = Math.min(LOGO_MAX_HEIGHT, logoArea)
    const logoW = Math.min(LOGO_MAX_WIDTH, box.w - 12)
    const logoCy = box.y + 4 + logoArea / 2
    const cx = box.x + box.w / 2
    const roleY = box.y + box.h - 6
    const nameY = node.role ? roleY - 11 : roleY
    const tech = node.tech ?? node.id
    return (
      `<g class="node" data-tech="${esc(tech)}" role="button" tabindex="0" aria-pressed="false" aria-label="${esc(node.label)}">` +
      `<title>${esc(node.label)}</title>` +
      `<rect class="node-rect" x="${box.x}" y="${box.y}" width="${box.w}" height="${box.h}" rx="3" filter="url(#nodeShadow)"/>` +
      `<image class="node-logo" href="${iconBase}${esc(node.icon)}" x="${cx - logoW / 2}" y="${logoCy - logoH / 2}" ` +
      `width="${logoW}" height="${logoH}" preserveAspectRatio="xMidYMid meet"/>` +
      (node.showLabel ? `<text class="node-name" x="${cx}" y="${nameY}" text-anchor="middle">${esc(node.label)}</text>` : '') +
      (node.role ? `<text class="node-role" x="${cx}" y="${roleY}" text-anchor="middle">${esc(node.role)}</text>` : '') +
      '</g>'
    )
  }

  const spine = (x) => {
    const cx = x + layout.barWidth / 2
    const head = 7
    return (
      `<g class="bar-spine"><line x1="${cx}" y1="${layerTop + head}" x2="${cx}" y2="${bodyBottom - head}"/>` +
      `<polygon points="${cx - 4},${layerTop + head} ${cx + 4},${layerTop + head} ${cx},${layerTop}"/>` +
      `<polygon points="${cx - 4},${bodyBottom - head} ${cx + 4},${bodyBottom - head} ${cx},${bodyBottom}"/></g>`
    )
  }

  const parts = [
    `<svg class="map-svg" viewBox="0 0 ${vbWidth} ${vbHeight}" role="group" aria-label="${esc(config.caption)} component map">`,
    '<defs><filter id="nodeShadow" x="-10%" y="-10%" width="120%" height="120%">' +
      '<feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity="0.12"/></filter></defs>',
    `<text class="platform-caption" x="${(coreLeft + frameRight) / 2}" y="${layout.captionY}">${esc(config.caption)}</text>`,
    `<rect class="stack-fill" x="${coreLeft}" y="${layout.frameTop}" width="${frameRight - coreLeft}" height="${frameHeight}" rx="4"/>`,
    ...bars.map(
      (b) =>
        `<rect class="bar-tint" x="${barLeft(b.id)}" y="${layout.frameTop}" width="${layout.barWidth}" height="${frameHeight}"/>`,
    ),
    `<line class="header-line" x1="${coreLeft}" y1="${layout.frameTop + layout.headerHeight}" x2="${frameRight}" y2="${layout.frameTop + layout.headerHeight}"/>`,
    textLines([config.coreLabel], coreLeft + layout.coreWidth / 2, headerMidY, 'section-title', 'middle'),
    ...bars.map((b) =>
      textLines(splitLabel(b.label), barLeft(b.id) + layout.barWidth / 2, headerMidY, 'section-title', 'middle'),
    ),
    ...bars.map(
      (b) =>
        `<line class="section-divider" x1="${barLeft(b.id)}" y1="${layout.frameTop}" x2="${barLeft(b.id)}" y2="${frameBottom}"/>`,
    ),
    ...layers.flatMap((layer, i) => {
      const y = layerY(layer.id)
      const out = [textLines(splitLabel(layer.label), layout.labelAnchorX, y + layout.layerHeight / 2, 'layer-label', 'end')]
      if (i < layers.length - 1) {
        const ly = y + layout.layerHeight + layout.layerGap / 2
        out.push(`<line class="layer-line" x1="${coreLeft}" y1="${ly}" x2="${coreRight}" y2="${ly}"/>`)
      }
      return out
    }),
    ...bars.map((b) => spine(barLeft(b.id))),
    // Opaque white backing so layer lines never show through dimmed boxes.
    ...config.nodes.map((n) => {
      const b = boxOf(n)
      return `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" rx="3" fill="#ffffff"/>`
    }),
    ...config.nodes.map(renderNode),
    `<rect class="stack-frame" x="${coreLeft}" y="${layout.frameTop}" width="${frameRight - coreLeft}" height="${frameHeight}" rx="4"/>`,
    '</svg>',
  ]
  return parts.join('\n')
}

export const mapCss = `
  .map-card { background: #fff; color: #1e293b; border: 1px solid var(--line); border-radius: 12px; padding: .5rem; overflow-x: auto; }
  .map-svg { display: block; width: 100%; min-width: 34rem; height: auto; }
  .map-svg .stack-fill { fill: #fffdf8; }
  .map-svg .stack-frame { fill: none; stroke: #8b6914; stroke-width: 2.5; }
  .map-svg .bar-tint { fill: #f6efdc; }
  .map-svg .section-divider, .map-svg .header-line { stroke: #c9b37a; stroke-width: 1.2; }
  .map-svg .section-title { font-size: 9.5px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; fill: #8b6914; dominant-baseline: middle; }
  .map-svg .bar-spine line { stroke: #d9c58f; stroke-width: 1.5; }
  .map-svg .bar-spine polygon { fill: #d9c58f; }
  .map-svg .layer-label { font-size: 10px; font-weight: 600; fill: #6b5344; dominant-baseline: middle; }
  .map-svg .layer-line { stroke: #cbd5e1; stroke-width: 1; }
  .map-svg .node-name { font-size: 10px; font-weight: 700; fill: #1e293b; }
  .map-svg .node-role { font-size: 8.5px; font-weight: 500; fill: #64748b; }
  .map-svg .platform-caption { font-size: 15px; font-weight: 700; fill: #8b6914; text-anchor: middle; }
  .map-svg .node { cursor: pointer; outline: none; transition: opacity .2s ease; }
  .map-svg .node-rect { fill: #fff; stroke: #1e293b; stroke-width: 1.2; }
  .map-svg .node-logo { pointer-events: none; }
  .map-svg .node:focus-visible .node-rect { stroke: #0b6bcb; stroke-width: 2.5; }
  .map-svg.filtering .node:not(.on) { opacity: .28; }
  .map-svg.filtering .node.on .node-rect { stroke: #0b6bcb; stroke-width: 2; }
`
