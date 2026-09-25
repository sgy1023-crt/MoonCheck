// MoonCheck
//
// A batch / CI front end for JSON Schema validation in MoonBit.
//
// Schema validation itself is delegated to `mizchi/jsonschema`
// (https://mooncakes.io/docs/mizchi/jsonschema). MoonCheck extends it with the
// pieces needed to run validation over many documents in CI:
//
//   - schema.mbt   : a schema linter that rejects schemas the validator would
//                    otherwise silently accept as "anything goes"
//   - validate.mbt : adapter over `mizchi/jsonschema`, turning its errors into
//                    stable, flat, classified errors with `$.a[0]` paths
//   - error.mbt    : the stable error model used by the reports
//   - report.mbt   : text and JSON reports for many documents
//   - cli.mbt      : the `mooncheck` command line contract
//
// See README.md for usage.
