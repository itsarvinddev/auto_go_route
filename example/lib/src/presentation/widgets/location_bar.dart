import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

/// Shows the location the current page was built for, like a browser's
/// address bar.
///
/// Every URL in the example is produced by a generated, typed helper, so this
/// makes the routing visible: tap a card, and the bar shows the exact path and
/// query string the helper built.
class LocationBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a location bar showing the location its page was built for.
  const LocationBar({super.key}) : _fromRouter = false;

  /// Creates a location bar showing the router's visible location.
  ///
  /// For a shell's own app bar, which is not a page and so has no
  /// `GoRouterState` of its own.
  const LocationBar.router({super.key}) : _fromRouter = true;

  final bool _fromRouter;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = _fromRouter
        ? GoRouter.of(context).currentLocation
        : GoRouterState.of(context).uri.toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled row of values, used to show what a route decoded.
class ParamTable extends StatelessWidget {
  /// Creates a table of `name → value` rows.
  const ParamTable({super.key, required this.title, required this.rows});

  /// The table heading.
  final String title;

  /// Each row: the parameter, where it came from, and its decoded value.
  final List<(String name, String source, String value)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          for (final (name, source, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 72, child: Text(name, style: mono)),
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      source,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Expanded(child: Text(value, style: mono)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
