export const LiveCode = {
  mounted() {
    this.textarea = this.el.querySelector("[data-livecode-textarea]")
    this.highlight = this.el.querySelector(".lc-highlight")
    this.highlightCode = this.el.querySelector("[data-livecode-highlight]")
    this.completions = this.el.querySelector("[data-livecode-completions]")
    this.diagnostics = this.el.querySelector("[data-livecode-diagnostics]")
    this.language = this.el.dataset.livecodeLanguage || "text"
    this.activeCompletion = 0

    if (!this.textarea) return

    this.items = () => Array.from(this.completions?.querySelectorAll("[data-livecode-insert]") || [])
    this.visibleItems = () => this.items().filter((item) => !item.hidden)
    this.escape = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    this.tokenSpan = (kind, text) => `<span class="lc-token lc-token-${kind}">${this.escape(text)}</span>`

    this.highlightGeneric = (text, re, classify) => {
      let html = ""
      let last = 0
      for (const match of text.matchAll(re)) {
        if (match.index > last) html += this.escape(text.slice(last, match.index))
        html += this.tokenSpan(classify(match[0]), match[0])
        last = match.index + match[0].length
      }
      html += this.escape(text.slice(last))
      return html || "\n"
    }

    this.highlightSql = (text) => {
      const keywords = new Set("alter analyze and as asc begin by case cast check column commit constraint create delete desc distinct drop else end except explain false foreign from full group having in index inner insert intersect into is join key left limit not null on or order outer primary references returning right rollback select set table then true union unique update values view where with".split(" "))
      const re = /(--.*$|\/\*[\s\S]*?\*\/|'(?:''|[^'])*'|"(?:""|[^"])*"|\b\d+(?:\.\d+)?\b|[A-Za-z_][A-Za-z0-9_$]*|<=|>=|<>|!=|\|\||::|[+\-*\/=<>.,;()])/gm
      return this.highlightGeneric(text, re, (part) => {
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

    this.highlightJson = (text) => {
      const re = /("(?:\\.|[^"])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\]:,])/gm
      return this.highlightGeneric(text, re, (part) => {
        if (part.startsWith('"')) return "string"
        if (part === "true" || part === "false") return "boolean"
        if (part === "null") return "null"
        if (/^-?\d/.test(part)) return "number"
        if (/^[{}\[\]]$/.test(part)) return "bracket"
        if (/^[:,]$/.test(part)) return "operator"
        return "text"
      })
    }

    this.highlightHtml = (text) => {
      const segRe = /<!--[\s\S]*?-->|<[^>]*>/g
      const tagRe = /<\/?|\/?>|"[^"]*"|'[^']*'|[A-Za-z_:][\w.:-]*|=|\s+|./g
      let html = ""
      let last = 0
      for (const match of text.matchAll(segRe)) {
        if (match.index > last) html += this.tokenSpan("text", text.slice(last, match.index))
        const segment = match[0]
        if (segment.startsWith("<!--")) {
          html += this.tokenSpan("comment", segment)
        } else {
          let expectName = true
          for (const tag of segment.matchAll(tagRe)) {
            const part = tag[0]
            if (part === "<" || part === "</") { expectName = true; html += this.tokenSpan("bracket", part) }
            else if (part === ">" || part === "/>") { html += this.tokenSpan("bracket", part) }
            else if (part.startsWith('"') || part.startsWith("'")) { html += this.tokenSpan("string", part) }
            else if (part === "=") { html += this.tokenSpan("operator", part) }
            else if (/^[A-Za-z_:][\w.:-]*$/.test(part)) {
              if (expectName) { expectName = false; html += this.tokenSpan("tag", part) }
              else { html += this.tokenSpan("attribute", part) }
            }
            else { html += this.escape(part) }
          }
        }
        last = match.index + segment.length
      }
      if (last < text.length) html += this.tokenSpan("text", text.slice(last))
      return html || "\n"
    }

    this.renderDiagnostics = () => {
      if (!this.diagnostics || this.language !== "json") return
      const value = this.textarea.value.trim()
      if (!value) {
        this.diagnostics.hidden = true
        this.el.classList.remove("lc-invalid")
        return
      }

      try {
        JSON.parse(value)
        this.diagnostics.hidden = true
        this.el.classList.remove("lc-invalid")
      } catch (error) {
        this.diagnostics.innerHTML = `<div class="lc-diagnostic lc-diagnostic-error"><span class="lc-diagnostic-severity">error</span><span>${this.escape(error.message)}</span></div>`
        this.diagnostics.hidden = false
        this.el.classList.add("lc-invalid")
      }
    }

    this.renderHighlight = () => {
      if (!this.highlightCode) return
      const value = this.textarea.value
      this.highlightCode.innerHTML =
        this.language === "json"
          ? this.highlightJson(value)
          : this.language === "html"
            ? this.highlightHtml(value)
            : this.highlightSql(value)
      this.renderDiagnostics()
    }

    this.currentPrefix = () => {
      const cursor = this.textarea.selectionStart || 0
      const before = this.textarea.value.slice(0, cursor)
      const match = before.match(/[A-Za-z0-9_$\."-]+$/)
      return match ? match[0].replace(/^"/, "").toLowerCase() : ""
    }

    this.syncScroll = () => {
      if (!this.highlight) return
      this.highlight.scrollTop = this.textarea.scrollTop
      this.highlight.scrollLeft = this.textarea.scrollLeft
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
        "letterSpacing", "textTransform", "wordSpacing", "lineHeight", "tabSize"
      ]
      copy.forEach((name) => { mirror.style[name] = style[name] })
      mirror.style.position = "fixed"
      mirror.style.left = `${this.textarea.getBoundingClientRect().left}px`
      mirror.style.top = `${this.textarea.getBoundingClientRect().top}px`
      mirror.style.whiteSpace = "pre-wrap"
      mirror.style.overflowWrap = "break-word"
      mirror.style.visibility = "hidden"
      mirror.style.pointerEvents = "none"
      mirror.style.zIndex = "-1"

      mirror.innerHTML = `${this.escape(before)}<span data-lc-caret></span>${this.escape(after)}`
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
      this.renderHighlight()
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

    this.textarea.addEventListener("scroll", () => {
      this.syncScroll()
      if (!this.completions?.hidden) this.positionCompletions()
    })

    this.textarea.addEventListener("input", (event) => {
      this.renderHighlight()
      this.syncScroll()

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

    this.renderHighlight()
    this.syncScroll()
    this.hideCompletions()
  },

  updated() {
    this.textarea = this.el.querySelector("[data-livecode-textarea]")
    this.highlight = this.el.querySelector(".lc-highlight")
    this.highlightCode = this.el.querySelector("[data-livecode-highlight]")
    this.completions = this.el.querySelector("[data-livecode-completions]")
    this.diagnostics = this.el.querySelector("[data-livecode-diagnostics]")
    this.language = this.el.dataset.livecodeLanguage || "text"
    this.renderHighlight?.()
    this.syncScroll?.()

    if (this.currentPrefix && document.activeElement === this.textarea && this.currentPrefix().length >= 2) {
      this.showCompletions?.(false)
    } else if (this.currentPrefix && this.currentPrefix().length < 2) {
      this.hideCompletions?.()
    }
  }
}

export default LiveCode
