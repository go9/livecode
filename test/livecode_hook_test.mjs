import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = await readFile(new URL("../priv/static/livecode/livecode.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(`${source}\nexport { renderLineNumbers }`).toString("base64")}`
const { renderLineNumbers } = await import(moduleUrl)

test("line numbers follow the textarea's logical lines", () => {
  const gutter = { childElementCount: 0, innerHTML: "" }

  renderLineNumbers(gutter, "")
  assert.equal(gutter.innerHTML, "<span>1</span>")

  gutter.childElementCount = 1
  renderLineNumbers(gutter, "first\nsecond\n")
  assert.equal(gutter.innerHTML, "<span>1</span><span>2</span><span>3</span>")

  gutter.childElementCount = 3
  renderLineNumbers(gutter, "only")
  assert.equal(gutter.innerHTML, "<span>1</span>")
})
