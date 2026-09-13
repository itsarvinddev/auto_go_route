# auto_go_route_generator

The `build_runner` code generator for
[`auto_go_route`](https://pub.dev/packages/auto_go_route).

You do not use this package directly — add it as a `dev_dependency` next to
`auto_go_route` and `build_runner` applies it to your package automatically.
Keep both packages on the same major version.

```yaml
dependencies:
  auto_go_route: ^2.0.0

dev_dependencies:
  auto_go_route_generator: ^2.0.0
  build_runner: ^2.15.1
```

```bash
dart run build_runner build
```

**Documentation, examples and the migration guide live with the runtime
package: [auto_go_route](https://pub.dev/packages/auto_go_route).**

## What it does

Reads `@AutoGoRoute`, `@AutoGoRouteShell`, `@AutoGoRouteBranch` and
`@AutoGoRouteBase`, and emits — into a `part` file next to the library holding
`@AutoGoRouteBase` — the `go_router` route tree, one typed route class per
widget, a `BuildContext` navigation extension, and a route-name enum.

Parameter types come from the annotated widget's own constructor, so
`final int id;` produces `goToProductPage(id: 42)` rather than
`goToProductPage(id: '42')`.

## Options

```yaml
# build.yaml
targets:
  $default:
    builders:
      auto_go_route_generator:auto_go_route_builder:
        options:
          source_globs:
            - lib/features/**/*.dart
            - lib/app_router.dart
```

`source_globs` narrows (or widens) the assets scanned for annotations;
defaults to `lib/**/*.dart`. Narrowing it to the directories that actually hold
routes is the cheapest way to speed up a very large package.

## Build errors

The generator prefers a named build error over an unparseable generated file.
It reports, among others: a `parent:` cycle, an unannotated `parent:`, an
optional path parameter, a duplicated path parameter, a route name that is not
a Dart identifier, two routes whose helpers would collide, a required query
parameter with no default, two `extra` parameters, a shell without a child
slot, conflicting error handlers, `metadata` that cannot be re-emitted as
source, and any function or key named by an annotation that does not resolve in
the router library.

Every message names the offending widget and what to change.

## License

MIT — see [LICENSE](LICENSE).
