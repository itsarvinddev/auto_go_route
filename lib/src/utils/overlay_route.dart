import 'package:flutter/material.dart';

class AdaptiveOverlayPage<T> extends Page<T> {
  final Widget child;
  final bool? showDragHandle;
  final bool useSafeArea;
  final bool isScrollControlled;
  final TraversalEdgeBehavior? traversalEdgeBehavior;
  final Offset? anchorPoint;
  final Color? barrierColor;
  final bool barrierDismissible;
  final String? barrierLabel;
  final String? barrierOnTapHint;
  final CapturedThemes? capturedThemes;
  final Clip? clipBehavior;
  final bool enableDrag;
  final BoxConstraints? constraints;
  final double? elevation;
  final bool? requestFocus;
  final double scrollControlDisabledMaxHeightRatio;
  final ShapeBorder? shape;
  final AnimationStyle? sheetAnimationStyle;
  final AnimationController? transitionAnimationController;
  final double? heightFactor;

  const AdaptiveOverlayPage({
    required this.child,
    this.showDragHandle = false,
    this.useSafeArea = true,
    this.isScrollControlled = true,
    this.traversalEdgeBehavior,
    this.anchorPoint,
    this.barrierColor,
    this.barrierDismissible = true,
    this.barrierLabel,
    this.barrierOnTapHint,
    this.capturedThemes,
    this.clipBehavior = Clip.none,
    this.enableDrag = true,
    this.constraints,
    this.elevation,
    this.requestFocus,
    this.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    this.sheetAnimationStyle,
    this.transitionAnimationController,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
    this.heightFactor = 0.98,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return isMobile
        ? ModalBottomSheetRoute<T>(
            settings: this,
            isScrollControlled: isScrollControlled,
            showDragHandle: showDragHandle,
            useSafeArea: useSafeArea,
            anchorPoint: anchorPoint,
            backgroundColor: barrierColor,
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
            scrollControlDisabledMaxHeightRatio:
                scrollControlDisabledMaxHeightRatio,
            shape: shape,
            sheetAnimationStyle: sheetAnimationStyle,
            transitionAnimationController: transitionAnimationController,
            builder: (context) {
              return ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: FractionallySizedBox(
                  heightFactor: heightFactor,
                  child:
                      (ModalRoute.of(context)?.settings as AdaptiveOverlayPage)
                          .child,
                ),
              );
            },
          )
        : RawDialogRoute<T>(
            settings: this,
            traversalEdgeBehavior: traversalEdgeBehavior,
            anchorPoint: anchorPoint,
            barrierColor: barrierColor,
            barrierDismissible: barrierDismissible,
            barrierLabel: barrierLabel,
            pageBuilder: (context, animation, secondaryAnimation) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 700,
                    maxWidth: 720,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: (ModalRoute.of(context)?.settings
                            as AdaptiveOverlayPage)
                        .child,
                  ),
                ),
              );
            },
          );
  }
}
