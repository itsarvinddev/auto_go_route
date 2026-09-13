# Contributing

Thanks for helping out. This repository holds two published packages and one
example app:

```
.            auto_go_route            the runtime library
generator/   auto_go_route_generator  the build_runner code generator
example/     a Flutter app that exercises every feature
```

## Setup

```bash
git clone https://github.com/itsarvinddev/auto_go_route.git
cd auto_go_route
flutter pub get
(cd generator && dart pub get)
(cd example && flutter pub get)
```

## The loop

```bash
# runtime
flutter analyze --fatal-infos && flutter test

# generator
cd generator && dart analyze --fatal-infos && dart test
# the lowest-resolution run skips checks that only hold for the newest analyzer
cd generator && dart pub downgrade && dart test -x latest-resolution && dart pub upgrade

# the example — the acceptance test for generated code
cd example && dart run build_runner build
cd example && flutter analyze --fatal-infos && flutter test
```

`dart format .` before committing; CI checks it.

## Where to put a test

Every fix needs one, and which suite it belongs in follows from what broke:

- **`test/`** — anything in the runtime library. Widget tests drive a real
  `GoRouter` rather than constructing a `GoRouterState` by hand, so they
  exercise the matching the helpers sit on top of. See
  `test/support/test_router.dart`.
- **`generator/test/builder_test.dart`** — the *emitted source*, asserted with
  the whitespace-insensitive `containsCode` matcher so the formatter's
  preferences do not break the suite.
- **`generator/test/errors_test.dart`** — every build error. A generator bug
  that produces an unparseable file should become a named build error, and this
  is where that gets pinned. Put a `timeout:` on anything that used to hang.
- **`example/test/widget_test.dart`** — end-to-end behaviour of the generated
  router. If a feature cannot be expressed through the generated API, the API
  is not finished; this is where that shows up.

`generator/test/support/harness.dart` holds `generate()`, `errorFor()` and the
`containsCode` matcher shared by every builder test.
`generator/test/support/stub_package.dart` stands in for `auto_go_route` inside
them, because a pure-Dart generator package cannot resolve Flutter. New
annotation fields have to be added there too, or the annotation read throws.

`review_regressions_test.dart` in both packages pins defects found by
adversarial review — shapes the original suite let through. When a bug escapes,
its reproduction goes there.

## Regenerating the example

The example's `app_router.routes.g.dart` is committed, and CI fails if a fresh
build produces a different file. After changing the generator:

```bash
cd example && dart run build_runner build
```

and commit the result — the diff is the most readable review of an emitter
change.

## Versioning

Both packages move together, and the generator's `pubspec.yaml` floors are
commented with *why* each one exists. Do not narrow the `analyzer` range: pub
picks the newest analyzer the user's SDK allows, and that is what lets the
generator parse new Dart syntax. Pinning it is what caused
[#3](https://github.com/itsarvinddev/auto_go_route/issues/3).

There is one rule in `generator/build.yaml` worth restating, because it fails
only at build-plan time: **no `required_inputs` entry may be a suffix of
anything this package emits.** `.routes.g.dart` ends with both `.dart` and
`.g.dart`, so both are permanently off-limits.

## Pull requests

1. Branch off `main`.
2. Add the test first, or alongside.
3. Add a `CHANGELOG.md` entry — the package's, or both if the change spans them.
4. Note any breaking change in `MIGRATION.md` with before/after code.

Open an issue first for anything large, so we can agree on the shape.
