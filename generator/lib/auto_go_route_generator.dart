/// The build_runner code generator for `auto_go_route`.
///
/// Add it as a `dev_dependency` alongside `build_runner`; the builder applies
/// itself automatically to any package depending on `auto_go_route`.
///
/// ```sh
/// dart run build_runner build
/// ```
library;

export 'builder.dart';
export 'src/analysis/graph_resolver.dart';
export 'src/analysis/route_collector.dart';
export 'src/emit/route_emitter.dart';
export 'src/generators/route_generator.dart';
export 'src/model/route_model.dart';
export 'src/utils/generator_utils.dart';
