// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "sgy1023-crt/MoonCheck"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/sgy1023-crt/MoonCheck"

license = "Apache-2.0"

keywords = [ "json", "jsonschema", "validation", "cli", "ci" ]

preferred_target = "wasm"

description = "Batch / CI JSON Schema validation CLI with schema linting and JSON reports, built on mizchi/jsonschema."

import {
  "moonbitlang/async@0.21.3",
  "mizchi/jsonschema@0.8.1",
}
