// LiveCode editor hook.
//
// A language is a PAIR: an Elixir `LiveCode.Language` module (server meaning —
// tokens/completions/diagnostics/snippets/format/preview-config) and an optional
// CLIENT registration here (rendering — highlight + preview). Register one with:
//
//   import { registerLanguage } from ".../livecode.js"
//   registerLanguage("mylang", {
//     highlight(text) { return htmlString },                 // optional
//     preview(text, ctx) { return { srcdoc: "<...>" } },     // optional
//     diagnostics(text) { return [{ severity, message }] },  // optional
//   })
//
// Consumers can also register a named PREVIEW TRANSFORM applied to the source
// before the language renders it (resolve placeholders, sanitize, etc.):
//
//   import { registerTransform } from ".../livecode.js"
//   registerTransform("ebay", (text, ctx) => sanitize(resolvePlaceholders(text)))
//
// and reference it from the editor component with `transform="ebay"`.

const registry = {}
const transforms = {}

export function registerLanguage(name, def) {
  registry[name] = { ...(registry[name] || {}), ...def }
}

export function registerTransform(name, fn) {
  transforms[name] = fn
}

const escape = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
const tokenSpan = (kind, text) => `<span class="lc-token lc-token-${kind}">${escape(text)}</span>`

function highlightGeneric(text, re, classify) {
  let html = ""
  let last = 0
  for (const match of text.matchAll(re)) {
    if (match.index > last) html += escape(text.slice(last, match.index))
    html += tokenSpan(classify(match[0]), match[0])
    last = match.index + match[0].length
  }
  html += escape(text.slice(last))
  return html
}

function highlightSql(text) {
  const keywords = new Set("alter analyze and as asc begin by case cast check column commit constraint create delete desc distinct drop else end except explain false foreign from full group having in index inner insert intersect into is join key left limit not null on or order outer primary references returning right rollback select set table then true union unique update values view where with".split(" "))
  const re = /(--.*$|\/\*[\s\S]*?\*\/|'(?:''|[^'])*'|"(?:""|[^"])*"|\b\d+(?:\.\d+)?\b|[A-Za-z_][A-Za-z0-9_$]*|<=|>=|<>|!=|\|\||::|[+\-*\/=<>.,;()])/gm
  return highlightGeneric(text, re, (part) => {
    const lower = part.toLowerCase()
    if (part.startsWith("--") || part.startsWith("/*")) return "comment"
    if (part.startsWith("'")) return "string"
    if (part.startsWith('"')) return "identifier"
    if (/^\d/.test(part)) return "number"
    if (keywords.has(lower)) return "keyword"
    if (/^[+\-*\/=<>.,;()|:!]+$/.test(part)) return "operator"
    return "identifier"
  })
}

function highlightJson(text) {
  const re = /("(?:\\.|[^"])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\]:,])/gm
  return highlightGeneric(text, re, (part) => {
    if (part.startsWith('"')) return "string"
    if (part === "true" || part === "false") return "boolean"
    if (part === "null") return "null"
    if (/^-?\d/.test(part)) return "number"
    if (/^[{}\[\]]$/.test(part)) return "bracket"
    if (/^[:,]$/.test(part)) return "operator"
    return "text"
  })
}

function highlightHtml(text) {
  const segRe = /<!--[\s\S]*?-->|<[^>]*>/g
  const tagRe = /<\/?|\/?>|"[^"]*"|'[^']*'|[A-Za-z_:][\w.:-]*|=|\s+|./g
  let html = ""
  let last = 0
  for (const match of text.matchAll(segRe)) {
    if (match.index > last) html += tokenSpan("text", text.slice(last, match.index))
    const segment = match[0]
    if (segment.startsWith("<!--")) {
      html += tokenSpan("comment", segment)
    } else {
      let expectName = true
      for (const tag of segment.matchAll(tagRe)) {
        const part = tag[0]
        if (part === "<" || part === "</") { expectName = true; html += tokenSpan("bracket", part) }
        else if (part === ">" || part === "/>") { html += tokenSpan("bracket", part) }
        else if (part.startsWith('"') || part.startsWith("'")) { html += tokenSpan("string", part) }
        else if (part === "=") { html += tokenSpan("operator", part) }
        else if (/^[A-Za-z_:][\w.:-]*$/.test(part)) {
          if (expectName) { expectName = false; html += tokenSpan("tag", part) }
          else { html += tokenSpan("attribute", part) }
        }
        else { html += escape(part) }
      }
    }
    last = match.index + segment.length
  }
  if (last < text.length) html += tokenSpan("text", text.slice(last))
  return html
}

function jsonDiagnostics(text) {
  const value = text.trim()
  if (!value) return []
  try {
    JSON.parse(value)
    return []
  } catch (error) {
    return [{ severity: "error", message: error.message }]
  }
}

function renderLineNumbers(gutter, text) {
  const count = text.split("\n").length
  if (!gutter || gutter.childElementCount === count) return
  gutter.innerHTML = Array.from({ length: count }, (_, index) => `<span>${index + 1}</span>`).join("")
}

// Built-in languages. HTML is previewable (renders into a sandboxed iframe).
registerLanguage("sql", { highlight: highlightSql })
registerLanguage("json", { highlight: highlightJson, diagnostics: jsonDiagnostics })
registerLanguage("html", { highlight: highlightHtml, preview: (text) => ({ srcdoc: text }) })

const PREVIEW_DEBOUNCE_MS = 120

export const LiveCode = {
  mounted() {
    this.resolveRefs()
    if (!this.textarea) return
    this.activeCompletion = 0
    this.previewTimer = null
    const persistentDiagnostics = Array.from(
      this.diagnostics?.querySelectorAll("[data-livecode-persistent-diagnostic]") || []
    )
    this.persistentDiagnostics = persistentDiagnostics.map((item) => item.outerHTML).join("")
    this.persistentDiagnosticError = persistentDiagnostics.some((item) =>
      item.classList.contains("lc-diagnostic-error")
    )

    this.items = () => Array.from(this.completions?.querySelectorAll("[data-livecode-insert]") || [])
    this.visibleItems = () => this.items().filter((item) => !item.hidden)

    this.renderHighlight = () => {
      if (!this.highlightCode) return
      const value = this.textarea.value
      const highlighter = this.lang.highlight || ((text) => escape(text))
      let html = highlighter(value)
      // A textarea reserves a blank line for a trailing newline; a <pre>
      // collapses it. Add one back so the overlay's last line (and the caret on
      // it) stays aligned with the textarea.
      if (value === "" || value.endsWith("\n")) html += "\n"
      this.highlightCode.innerHTML = html

      renderLineNumbers(this.gutter, value)
      this.renderDiagnostics()
    }

    this.renderDiagnostics = () => {
      if (!this.diagnostics || !this.lang.diagnostics) return
      const items = this.lang.diagnostics(this.textarea.value)
      const clientDiagnostics = items
        .map(
          (d) =>
            `<div class="lc-diagnostic lc-diagnostic-${d.severity}"><span class="lc-diagnostic-severity">${d.severity}</span><span>${escape(d.message)}</span></div>`
        )
        .join("")
      this.diagnostics.innerHTML = this.persistentDiagnostics + clientDiagnostics
      this.diagnostics.hidden = !this.diagnostics.innerHTML
      const invalid = this.persistentDiagnosticError || items.some((d) => d.severity === "error")
      this.el.classList.toggle("lc-invalid", invalid)
      this.textarea.setAttribute("aria-invalid", String(invalid))
      if (this.diagnostics.hidden) this.textarea.removeAttribute("aria-describedby")
      else this.textarea.setAttribute("aria-describedby", this.diagnostics.id)
    }

    this.currentPrefix = () => {
      const cursor = this.textarea.selectionStart || 0
      const before = this.textarea.value.slice(0, cursor)
      const match = before.match(/[A-Za-z0-9_$\."-]+$/)
      return match ? match[0].replace(/^"/, "").toLowerCase() : ""
    }

    this.syncScroll = () => {
      if (this.highlight) {
        this.highlight.scrollTop = this.textarea.scrollTop
        this.highlight.scrollLeft = this.textarea.scrollLeft
      }
      // Keep the line-number gutter locked to the code's vertical scroll.
      if (this.gutter) this.gutter.scrollTop = this.textarea.scrollTop
    }

    this.caretPoint = () => {
      const cursor = this.textarea.selectionStart || 0
      const value = this.textarea.value
      const before = value.slice(0, cursor)
      const after = value.slice(cursor) || " "
      const style = getComputedStyle(this.textarea)
      const mirror = this._caretMirror || document.createElement("div")
      this._caretMirror = mirror
      mirror.className = "lc-caret-mirror"

      const copy = [
        "boxSizing", "width", "height", "overflowX", "overflowY", "borderTopWidth",
        "borderRightWidth", "borderBottomWidth", "borderLeftWidth", "paddingTop", "paddingRight",
        "paddingBottom", "paddingLeft", "fontFamily", "fontSize", "fontWeight", "fontStyle",
        "letterSpacing", "textTransform", "wordSpacing", "lineHeight", "tabSize", "whiteSpace"
      ]
      copy.forEach((name) => { mirror.style[name] = style[name] })
      mirror.style.position = "fixed"
      mirror.style.left = `${this.textarea.getBoundingClientRect().left}px`
      mirror.style.top = `${this.textarea.getBoundingClientRect().top}px`
      mirror.style.visibility = "hidden"
      mirror.style.pointerEvents = "none"
      mirror.style.zIndex = "-1"

      mirror.innerHTML = `${escape(before)}<span data-lc-caret></span>${escape(after)}`
      if (!mirror.parentNode) document.body.appendChild(mirror)

      const marker = mirror.querySelector("[data-lc-caret]")
      const markerRect = marker.getBoundingClientRect()
      const wrapRect = this.textarea.parentElement.getBoundingClientRect()
      const lineHeight = parseFloat(style.lineHeight) || parseFloat(style.fontSize) * 1.45 || 20

      return {
        left: markerRect.left - wrapRect.left - this.textarea.scrollLeft,
        top: markerRect.top - wrapRect.top + lineHeight - this.textarea.scrollTop
      }
    }

    this.positionCompletions = () => {
      if (!this.completions) return
      const point = this.caretPoint()
      const wrapWidth = this.textarea.clientWidth
      const width = Math.min(420, Math.max(240, wrapWidth - 24))
      const left = Math.min(Math.max(8, point.left), Math.max(8, wrapWidth - width - 8))
      this.completions.style.left = `${left}px`
      this.completions.style.top = `${Math.max(8, point.top + 4)}px`
      this.completions.style.width = `${width}px`
    }

    this.markActive = (index = 0) => {
      const visible = this.visibleItems()
      if (visible.length === 0) return
      this.activeCompletion = Math.max(0, Math.min(index, visible.length - 1))
      this.items().forEach((item) => item.classList.remove("lc-active"))
      visible[this.activeCompletion]?.classList.add("lc-active")
      visible[this.activeCompletion]?.scrollIntoView({ block: "nearest" })
    }

    this.filterCompletions = (force = false) => {
      const prefix = this.currentPrefix()
      const canShow = force || prefix.length >= 2

      this.items().forEach((item) => {
        const label = item.querySelector(".lc-completion-label")?.textContent?.toLowerCase() || ""
        item.hidden = !canShow || (prefix && !label.includes(prefix))
      })

      if (this.visibleItems().length === 0) return false
      this.markActive(0)
      return true
    }

    this.hideCompletions = () => {
      if (this.completions) this.completions.hidden = true
    }

    this.showCompletions = (force = false) => {
      if (!this.completions) return
      if (!this.filterCompletions(force)) {
        this.hideCompletions()
        return
      }
      this.positionCompletions()
      this.completions.hidden = false
    }

    this.replacePrefix = (text) => {
      const cursor = this.textarea.selectionStart || 0
      const value = this.textarea.value
      const before = value.slice(0, cursor)
      const match = before.match(/[A-Za-z0-9_$\."-]+$/)
      const start = match ? cursor - match[0].length : cursor
      const end = this.textarea.selectionEnd || cursor
      this.textarea.value = value.slice(0, start) + text + value.slice(end)
      const next = start + text.length
      this.textarea.setSelectionRange(next, next)
      this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
      this.textarea.focus()
      this.hideCompletions()
    }

    this.acceptActiveCompletion = () => {
      const item = this.visibleItems()[this.activeCompletion]
      if (!item) return false
      this.replacePrefix(item.dataset.livecodeInsert || item.textContent.trim())
      return true
    }

    // ── Preview + view modes ────────────────────────────────────────────
    this.ensureFrame = () => {
      if (this._frame || !this.previewPane) return this._frame
      const frame = document.createElement("iframe")
      frame.className = "lc-preview-frame"
      frame.setAttribute("title", "Preview")
      // Empty sandbox token = maximum isolation (no script execution, no
      // same-origin). The editor never needs the preview to run scripts.
      if (this.sandbox) frame.setAttribute("sandbox", "")
      this.previewPane.appendChild(frame)
      this._frame = frame
      return frame
    }

    this.renderPreview = () => {
      if (!this.previewMode || !this.previewPane || this.view === "code") return
      let text = this.textarea.value
      const transform = transforms[this.transformName]
      if (transform) {
        try {
          text = transform(text, { el: this.el, language: this.language })
        } catch (error) {
          text = `<pre style="color:#b91c1c">preview transform error: ${escape(String(error))}</pre>`
        }
      }
      const renderer = registry[this.previewMode]?.preview || this.lang.preview
      const result = renderer ? renderer(text, { el: this.el, language: this.language }) : { srcdoc: text }
      const frame = this.ensureFrame()
      if (frame) frame.srcdoc = result.srcdoc != null ? result.srcdoc : result.html != null ? result.html : text
    }

    this.schedulePreview = () => {
      if (!this.previewMode || this.view === "code") return
      clearTimeout(this.previewTimer)
      this.previewTimer = setTimeout(() => this.renderPreview(), PREVIEW_DEBOUNCE_MS)
    }

    this.setView = (view) => {
      this.view = view
      this.el.classList.remove("lc-view-code", "lc-view-split", "lc-view-preview")
      this.el.classList.add(`lc-view-${view}`)
      this.el.dataset.livecodeView = view
      this.toolbar?.querySelectorAll("[data-livecode-view-btn]").forEach((btn) => {
        const active = btn.dataset.livecodeViewBtn === view
        btn.classList.toggle("lc-tab-active", active)
        btn.setAttribute("aria-pressed", String(active))
      })
      if (view !== "code") this.renderPreview()
    }

    // ── Listeners ───────────────────────────────────────────────────────
    this.textarea.addEventListener("scroll", () => {
      this.syncScroll()
      if (!this.completions?.hidden) this.positionCompletions()
    })

    this.textarea.addEventListener("input", (event) => {
      this.renderHighlight()
      this.syncScroll()
      this.schedulePreview()

      if (!this.completions?.hidden) this.positionCompletions()
      if (event.isTrusted && this.currentPrefix().length >= 2) this.showCompletions(false)
      else this.hideCompletions()
    })

    this.textarea.addEventListener("keydown", (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key === " ") {
        event.preventDefault()
        this.showCompletions(true)
        return
      }

      if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
        this.pushEventTo(this.el, "livecode:submit", { value: this.textarea.value })
        return
      }

      if (!this.completions?.hidden) {
        if (event.key === "ArrowDown") {
          event.preventDefault()
          this.markActive(this.activeCompletion + 1)
          return
        }

        if (event.key === "ArrowUp") {
          event.preventDefault()
          this.markActive(this.activeCompletion - 1)
          return
        }

        if (event.key === "Enter" || event.key === "Tab") {
          if (this.acceptActiveCompletion()) event.preventDefault()
          return
        }
      }

      if (event.key === "Escape") this.hideCompletions()
    })

    this.completions?.addEventListener("click", (event) => {
      const item = event.target.closest("[data-livecode-insert]")
      if (!item) return
      this.replacePrefix(item.dataset.livecodeInsert || item.textContent.trim())
    })

    this.toolbar?.addEventListener("click", (event) => {
      const btn = event.target.closest("[data-livecode-view-btn]")
      if (btn) this.setView(btn.dataset.livecodeViewBtn)
    })

    this.renderHighlight()
    this.syncScroll()
    this.hideCompletions()
    if (this.previewMode) this.setView(this.view || "code")
  },

  resolveRefs() {
    this.textarea = this.el.querySelector("[data-livecode-textarea]")
    this.highlight = this.el.querySelector(".lc-highlight")
    this.highlightCode = this.el.querySelector("[data-livecode-highlight]")
    this.gutter = this.el.querySelector("[data-livecode-gutter]")
    this.completions = this.el.querySelector("[data-livecode-completions]")
    this.diagnostics = this.el.querySelector("[data-livecode-diagnostics]")
    this.toolbar = this.el.querySelector("[data-livecode-toolbar]")
    this.previewPane = this.el.querySelector("[data-livecode-preview-pane]")
    this.language = this.el.dataset.livecodeLanguage || "text"
    this.lang = registry[this.language] || {}
    this.previewMode = this.el.dataset.livecodePreview || null
    this.sandbox = this.el.dataset.livecodeSandbox !== "false"
    this.transformName = this.el.dataset.livecodeTransform || null
    this.view = this.el.dataset.livecodeView || (this.previewMode ? "code" : null)
  },

  updated() {
    this.resolveRefs()
    this.renderHighlight?.()
    this.syncScroll?.()
    this.schedulePreview?.()

    if (this.currentPrefix && document.activeElement === this.textarea && this.currentPrefix().length >= 2) {
      this.showCompletions?.(false)
    } else if (this.currentPrefix && this.currentPrefix().length < 2) {
      this.hideCompletions?.()
    }
  },

  destroyed() {
    clearTimeout(this.previewTimer)
    this._caretMirror?.remove()
  }
}

export default LiveCode
