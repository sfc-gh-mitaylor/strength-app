// Fail fast if the wrong Node major is in use.
//
// Why this file exists: `engines` in package.json plus `engine-strict=true` in
// .npmrc does NOT enforce the root project's own Node range — npm only applies
// engine-strict to dependencies it installs. Verified: `npm ci` on Node 25 with
// engines set to ">=22 <23" exits 0 and says nothing.
//
// So the pin needs a real check. This runs as `preinstall`, which means it
// fires on `npm ci` and `npm install` before anything is downloaded, and gives
// an actionable message instead of a confusing build error thirty seconds later.
//
// The version comes from .nvmrc so there is exactly one source of truth, shared
// with CI via actions/setup-node's node-version-file.

import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const wanted = readFileSync(join(root, ".nvmrc"), "utf8").trim()
const actual = process.versions.node.split(".")[0]

if (actual !== wanted) {
  console.error(
    [
      "",
      `  This project requires Node ${wanted}.x — you are running ${process.version}.`,
      "",
      `  Pinned in .nvmrc, which CI also reads, so a mismatch here means your`,
      `  local results will not match CI.`,
      "",
      "  Fix it with one of:",
      "    nvm use                                  # if you use nvm",
      `    export PATH="/opt/homebrew/opt/node@${wanted}/bin:$PATH"   # Homebrew keg-only`,
      "",
    ].join("\n"),
  )
  process.exit(1)
}
