import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../annotations/auto_go_route.dart';

/// Builds the `Page` for a route declared with an [AutoRouteTransition].
///
/// The generated code calls this, but it is public and stable: a hand-written
/// `pageBuilder` can delegate to it to pick up the same transitions.
///
/// ```dart
/// Page<dynamic> myPageBuilder(BuildContext context, GoRouterState state) =>
///     buildAutoRoutePage(
///       context: context,
///       state: state,
///       child: const SettingsPage(),
///       transition: AutoRouteTransition.slideUp,
///     );
/// ```
Page<T> buildAutoRoutePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  AutoRouteTransition transition = AutoRouteTransition.platform,
  Duration? transitionDuration,
  Duration? reverseTransitionDuration,
  bool fullscreenDialog = false,
  bool opaque = true,
  bool barrierDismissible = false,
  Color? barrierColor,
  bool maintainState = true,
  String? restorationId,
  String? name,
  Object? arguments,
}) {
  final key = state.pageKey;
  final pageName = name ?? state.name ?? state.fullPath;

  switch (transition) {
    case AutoRouteTransition.platform:
      return _isCupertino(context)
          ? CupertinoPage<T>(
              key: key,
              name: pageName,
              arguments: arguments,
              restorationId: restorationId,
              maintainState: maintainState,
              fullscreenDialog: fullscreenDialog,
              child: child,
            )
          : MaterialPage<T>(
              key: key,
              name: pageName,
              arguments: arguments,
              restorationId: restorationId,
              maintainState: maintainState,
              fullscreenDialog: fullscreenDialog,
              child: child,
            );

    case AutoRouteTransition.material:
      return MaterialPage<T>(
        key: key,
        name: pageName,
        arguments: arguments,
        restorationId: restorationId,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
        child: child,
      );

    case AutoRouteTransition.cupertino:
      return CupertinoPage<T>(
        key: key,
        name: pageName,
        arguments: arguments,
        restorationId: restorationId,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
        child: child,
      );

    case AutoRouteTransition.none:
      return CustomTransitionPage<T>(
        key: key,
        name: pageName,
        arguments: arguments,
        restorationId: restorationId,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
        opaque: opaque,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierDismissible ? _dismissLabel(context) : null,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: _noTransition,
        child: child,
      );

    case AutoRouteTransition.fade:
    case AutoRouteTransition.slide:
    case AutoRouteTransition.slideUp:
    case AutoRouteTransition.slideDown:
    case AutoRouteTransition.scale:
    case AutoRouteTransition.rotation:
      final forward = transitionDuration ?? const Duration(milliseconds: 300);
      return CustomTransitionPage<T>(
        key: key,
        name: pageName,
        arguments: arguments,
        restorationId: restorationId,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
        opaque: opaque,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierDismissible ? _dismissLabel(context) : null,
        transitionDuration: forward,
        reverseTransitionDuration: reverseTransitionDuration ?? forward,
        transitionsBuilder: _builderFor(transition),
        child: child,
      );
  }
}

/// The scrim's semantic label, without assuming a Material app.
///
/// `MaterialLocalizations.of` throws when there is no Material localizations
/// ancestor — a `CupertinoApp` or `WidgetsApp` — so an animated route with a
/// dismissible barrier crashed outside `MaterialApp`. Look it up softly and
/// fall back through the Cupertino and widgets layers.
String _dismissLabel(BuildContext context) =>
    Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    )?.modalBarrierDismissLabel ??
    Localizations.of<CupertinoLocalizations>(
      context,
      CupertinoLocalizations,
    )?.modalBarrierDismissLabel ??
    'Dismiss';

bool _isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

Widget _noTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => child;

RouteTransitionsBuilder _builderFor(AutoRouteTransition transition) {
  switch (transition) {
    case AutoRouteTransition.fade:
      return _fade;
    case AutoRouteTransition.slide:
      return _slideFromEnd;
    case AutoRouteTransition.slideUp:
      return _slideFromBottom;
    case AutoRouteTransition.slideDown:
      return _slideFromTop;
    case AutoRouteTransition.scale:
      return _scale;
    case AutoRouteTransition.rotation:
      return _rotation;
    case AutoRouteTransition.platform:
    case AutoRouteTransition.material:
    case AutoRouteTransition.cupertino:
    case AutoRouteTransition.none:
      return _noTransition;
  }
}

Widget _fade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(opacity: animation, child: child);

Widget _slide(
  Offset begin,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => SlideTransition(
  position: Tween<Offset>(
    begin: begin,
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
  child: SlideTransition(
    // Push the outgoing page a third of the way in the same direction, which
    // is what makes a stack of slides read as depth rather than as a carousel.
    position: Tween<Offset>(
      begin: Offset.zero,
      end: begin * -0.33,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(secondaryAnimation),
    child: child,
  ),
);

Widget _slideFromEnd(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Respect reading direction: "in from the end" is right-to-left in LTR and
  // left-to-right in RTL.
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return _slide(Offset(rtl ? -1 : 1, 0), animation, secondaryAnimation, child);
}

Widget _slideFromBottom(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => _slide(const Offset(0, 1), animation, secondaryAnimation, child);

Widget _slideFromTop(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => _slide(const Offset(0, -1), animation, secondaryAnimation, child);

Widget _scale(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => ScaleTransition(
  scale: Tween<double>(
    begin: 0.92,
    end: 1,
  ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
  child: FadeTransition(opacity: animation, child: child),
);

Widget _rotation(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => RotationTransition(
  turns: Tween<double>(
    begin: 0.9,
    end: 1,
  ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
  child: ScaleTransition(
    scale: Tween<double>(
      begin: 0.9,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
    child: FadeTransition(opacity: animation, child: child),
  ),
);
