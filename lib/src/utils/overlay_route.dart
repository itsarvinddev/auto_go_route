import 'package:flutter/material.dart';

/// A `Page` that presents its child as a bottom sheet on narrow screens and a
/// centred dialog on wide ones.
///
/// Use it from a shell's `pageBuilder` to turn a group of routes into a modal
/// flow whose URL is still real and shareable:
///
/// ```dart
/// Page<dynamic> sheetPageBuilder(
///   BuildContext context,
///   GoRouterState state,
///   Widget child,
/// ) => AdaptiveOverlayPage(child: child, heightFactor: 0.9);
///
/// @AutoGoRouteShell(path: '/compose', pageBuilder: 'sheetPageBuilder')
/// class ComposeShell extends StatelessWidget { /* ... */ }
/// ```
class AdaptiveOverlayPage<T> extends Page<T> {
  /// Creates an adaptive overlay page.
  const AdaptiveOverlayPage({
    required this.child,
    this.breakpoint = 600,
    this.showDragHandle,
    this.useSafeArea = true,
    this.isScrollControlled = true,
    this.traversalEdgeBehavior,
    this.anchorPoint,
    this.backgroundColor,
    this.barrierColor,
    this.barrierDismissible = true,
    this.barrierLabel,
    this.barrierOnTapHint,
    this.capturedThemes,
    this.clipBehavior = Clip.antiAlias,
    this.enableDrag = true,
    this.constraints,
    this.elevation,
    this.requestFocus,
    this.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    this.dialogShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    ),
    this.dialogConstraints = const BoxConstraints(
      maxHeight: 700,
      maxWidth: 720,
    ),
    this.sheetAnimationStyle,
    this.transitionAnimationController,
    this.heightFactor = 0.98,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
  });

  /// The content to present.
  final Widget child;

  /// Width in logical pixels below which the sheet form is used.
  ///
  /// Defaults to 600 — Material's compact/medium boundary.
  final double breakpoint;

  /// Whether the bottom sheet shows a drag handle.
  final bool? showDragHandle;

  /// Whether the bottom sheet avoids system intrusions.
  final bool useSafeArea;

  /// Whether the bottom sheet can grow past half the screen.
  final bool isScrollControlled;

  /// Focus traversal behaviour at the dialog's edges.
  final TraversalEdgeBehavior? traversalEdgeBehavior;

  /// The point used to disambiguate which display to present on.
  final Offset? anchorPoint;

  /// The surface colour of the sheet or dialog.
  ///
  /// Distinct from [barrierColor]. 1.x passed one value as both, so setting a
  /// scrim colour also repainted the sheet — and vice versa.
  final Color? backgroundColor;

  /// The colour of the scrim behind the sheet or dialog.
  final Color? barrierColor;

  /// Whether tapping the scrim dismisses the overlay.
  final bool barrierDismissible;

  /// Semantic label for the scrim.
  final String? barrierLabel;

  /// Accessibility hint for tapping the scrim.
  final String? barrierOnTapHint;

  /// Themes captured from the caller's context.
  final CapturedThemes? capturedThemes;

  /// How the content is clipped to [shape] or [dialogShape].
  final Clip? clipBehavior;

  /// Whether the bottom sheet can be dragged.
  final bool enableDrag;

  /// Size constraints for the bottom sheet.
  final BoxConstraints? constraints;

  /// Elevation of the sheet or dialog.
  final double? elevation;

  /// Whether the route requests focus when shown.
  final bool? requestFocus;

  /// Maximum height ratio when [isScrollControlled] is `false`.
  final double scrollControlDisabledMaxHeightRatio;

  /// The bottom sheet's shape. Also drives the sheet's clip.
  final ShapeBorder? shape;

  /// The dialog's shape. Also drives the dialog's clip.
  final ShapeBorder? dialogShape;

  /// Size constraints for the dialog form.
  final BoxConstraints dialogConstraints;

  /// Animation style for the bottom sheet.
  final AnimationStyle? sheetAnimationStyle;

  /// Controller driving the bottom sheet's transition.
  final AnimationController? transitionAnimationController;

  /// Fraction of the available height the sheet occupies.
  ///
  /// Set to `null` to let the content size itself.
  final double? heightFactor;

  @override
  Route<T> createRoute(BuildContext context) {
    // Read the size once, here, rather than inside the builder: `createRoute`
    // runs when the route is created, so the sheet-versus-dialog choice is
    // fixed for the life of the route. Resizing the window mid-flight keeps
    // the form it was created with instead of tearing down the route.
    final isCompact = MediaQuery.sizeOf(context).width < breakpoint;
    return isCompact ? _sheetRoute() : _dialogRoute(context);
  }

  Route<T> _sheetRoute() {
    // Capture `child` directly instead of reaching back through
    // `ModalRoute.of(context)!.settings as AdaptiveOverlayPage`, which throws
    // as soon as anything else wraps the route.
    final content = child;
    final heightFactor = this.heightFactor;
    return ModalBottomSheetRoute<T>(
      settings: this,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      anchorPoint: anchorPoint,
      backgroundColor: backgroundColor,
      barrierLabel: barrierLabel,
      barrierOnTapHint: barrierOnTapHint,
      capturedThemes: capturedThemes,
      clipBehavior: clipBehavior,
      enableDrag: enableDrag,
      constraints: constraints,
      elevation: elevation,
      isDismissible: barrierDismissible,
      modalBarrierColor: barrierColor,
      requestFocus: requestFocus,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      shape: shape,
      sheetAnimationStyle: sheetAnimationStyle,
      transitionAnimationController: transitionAnimationController,
      builder: (context) => heightFactor == null
          ? content
          : FractionallySizedBox(heightFactor: heightFactor, child: content),
    );
  }

  Route<T> _dialogRoute(BuildContext context) {
    final content = child;
    return RawDialogRoute<T>(
      settings: this,
      traversalEdgeBehavior: traversalEdgeBehavior,
      anchorPoint: anchorPoint,
      barrierColor: barrierColor ?? Colors.black54,
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          Localizations.of<MaterialLocalizations>(
            context,
            MaterialLocalizations,
          )?.modalBarrierDismissLabel ??
          'Dismiss',
      requestFocus: requestFocus,
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: dialogShape,
        clipBehavior: clipBehavior ?? Clip.antiAlias,
        child: ConstrainedBox(constraints: dialogConstraints, child: content),
      ),
    );
  }
}
