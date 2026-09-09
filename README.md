# MoonCheck

A lightweight, reusable JSON / API parameter validator with a CLI, written in MoonBit.

_This README is under construction. Full documentation (Features, Quick Start,
CLI Usage, Use Cases, Testing) will be added as the implementation lands._

## Status

- [ ] Core schema type model
- [ ] Primitive validators (string / int / number / bool)
- [ ] Object, nested object and array validation
- [ ] Constraints (required, min/max, minLength/maxLength, enum)
- [ ] Structured validation errors
- [ ] CLI (`mooncheck validate schema.json data.json`)
- [ ] Unit tests
- [ ] Examples
- [ ] Full README

## Project Structure

```
MoonCheck/
├── moon.mod               # module metadata
├── moon.pkg               # root library package
├── MoonCheck.mbt          # library entry
├── MoonCheck_test.mbt     # black-box tests (public API)
├── MoonCheck_wbtest.mbt   # white-box tests (internals)
└── cmd/
    └── main/              # CLI executable
        ├── main.mbt
        └── moon.pkg
```

## License

Apache-2.0
