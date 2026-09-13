import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

/// Builds a build-time error whose message carries its own fix.
///
/// build_runner renders only `InvalidGenerationSource.message` — the `todo`
/// field never reaches the terminal — so guidance left there is invisible to
/// the person who has to act on it. Folding it into the message is what turns
/// "this is wrong" into "this is wrong, and here is the fix".
InvalidGenerationSourceError routeError(
  String problem, {
  String? todo,
  Element? element,
}) => InvalidGenerationSourceError(
  todo == null ? problem : '$problem\n\nTo fix: $todo',
  todo: todo ?? '',
  element: element,
);
