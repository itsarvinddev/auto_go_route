import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A navigation guard: return `null` to allow navigation, or a location string
/// to redirect there.
///
/// This is structurally identical to go_router's own `GoRouterRedirect`, so any
/// existing redirect function can be used as a guard and vice versa.
typedef RouteGuard = FutureOr<String?> Function(BuildContext, GoRouterState);

/// Shared guard plumbing for [RoutePaths] and [ShellRoutePaths].
///
/// Both route kinds accept a go_router-native [redirect] *and* an ordered list
/// of [middleware] guards. This mixin defines how they compose, so the rule is
/// the same wherever guards appear.
mixin RouteGuardMixin {
  /// A redirect mapped directly onto go_router's own `redirect` field.
  ///
  /// Runs before [middleware]. Because it is go_router's own field, a parent's
  /// [redirect] takes priority over a child's.
  RouteGuard? get redirect;

  /// Guards run in order after [redirect]. The first non-null result wins.
  List<RouteGuard> get middleware;

  /// [redirect] and [middleware] composed into the single function go_router
  /// accepts, or `null` when there is nothing to run.
  ///
  /// Returning `null` here matters: passing a no-op redirect to `GoRoute`
  /// makes go_router treat the route as redirect-capable and changes its
  /// `redirectOnly` bookkeeping, so routes without guards must pass nothing.
  RouteGuard? get composedRedirect {
    final redirect = this.redirect;
    final middleware = this.middleware;
    if (redirect == null && middleware.isEmpty) return null;
    if (middleware.isEmpty) return redirect;
    if (redirect == null && middleware.length == 1) return middleware.first;
    final chain = <RouteGuard>[?redirect, ...middleware];
    return (BuildContext context, GoRouterState state) =>
        _runChain(chain, 0, context, state);
  }

  /// Runs [guards] from [index] on, returning the first non-null result.
  ///
  /// Stays synchronous while the guards do. go_router distinguishes a redirect
  /// that returns a value from one that returns a `Future`: the async path
  /// defers the whole navigation for a frame, so wrapping synchronous guards
  /// in a `Future` would make every guarded route flicker.
  static FutureOr<String?> _runChain(
    List<RouteGuard> guards,
    int index,
    BuildContext context,
    GoRouterState state,
  ) {
    if (index >= guards.length) return null;
    final result = guards[index](context, state);
    if (result is Future<String?>) {
      return result.then(
        // The context belongs to go_router's redirect machinery, which keeps
        // it alive for the duration of the redirect chain — this is the same
        // contract every `FutureOr` redirect in go_router relies on.
        // ignore: use_build_context_synchronously
        (value) => value ?? _runChain(guards, index + 1, context, state),
      );
    }
    return result ?? _runChain(guards, index + 1, context, state);
  }
}
