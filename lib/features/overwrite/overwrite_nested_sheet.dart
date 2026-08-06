import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

Widget fadeAndSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurveTween(curve: Curves.easeInExpo).animate(animation),
    child: FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.4)
          .chain(CurveTween(curve: Curves.easeOutExpo))
          .animate(secondaryAnimation),
      child: const FadeForwardsPageTransitionsBuilder().buildTransitions(
        ModalRoute.of(context) as PageRoute,
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    ),
  );
}

class OverwriteNestedSheet<T> extends ConsumerStatefulWidget {
  final T Function(WidgetRef ref) currentOf;
  final bool Function(BuildContext context, WidgetRef ref) save;
  final WidgetBuilder formBuilder;

  const OverwriteNestedSheet({
    super.key,
    required this.currentOf,
    required this.save,
    required this.formBuilder,
  });

  @override
  ConsumerState<OverwriteNestedSheet<T>> createState() =>
      _OverwriteNestedSheetState<T>();
}

class _OverwriteNestedSheetState<T>
    extends ConsumerState<OverwriteNestedSheet<T>> {
  final GlobalKey<NavigatorState> _nestedNavigatorKey = GlobalKey();
  late T _origin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _origin = widget.currentOf(ref);
    });
  }

  Future<void> _handleClose() async {
    final state = _nestedNavigatorKey.currentState;
    if (state != null && state.canPop()) {
      final res = await globalState.showMessage(
        message: TextSpan(text: context.appLocalizations.confirmExitWindow),
      );
      if (res != true) {
        return;
      }
    }
    if (context.mounted) {
      _handleExit();
    }
  }

  Future<void> _handleExit() async {
    final current = widget.currentOf(ref);
    if (_origin == current) {
      Navigator.of(context).pop();
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.dataChangedSave),
    );
    if (!mounted) {
      return;
    }
    if (res != true) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.save(context, ref)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePop() async {
    final state = _nestedNavigatorKey.currentState;
    if (state != null && state.canPop()) {
      state.pop();
    } else {
      _handleExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nestedNavigator = Navigator(
      key: _nestedNavigatorKey,
      onGenerateInitialRoutes: (navigator, initialRoute) {
        return [
          PagedSheetRoute(builder: (context) => widget.formBuilder(context)),
        ];
      },
    );
    final sheetProvider = SheetProvider.of(context);
    final fillColor = sheetProvider?.type == SheetType.bottomSheet
        ? context.colorScheme.surfaceContainerLow
        : context.colorScheme.surface;
    return CommonPopScope(
      onPop: (_) async {
        _handlePop();
        return false;
      },
      child: sheetProvider!.copyWith(
        nestedNavigatorPop: ([data]) {
          Navigator.of(context).pop(data);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () async {
                  _handleClose();
                },
              ),
            ),
            SizedBox(
              width: sheetProvider.type == SheetType.sideSheet ? 400 : null,
              child: SheetViewport(
                child: PagedSheetRouteTheme(
                  data: const PagedSheetRouteThemeData(
                    transitionsBuilder: fadeAndSlideTransition,
                    transitionDuration: Duration(milliseconds: 300),
                  ),
                  child: PagedSheet(
                    decoration: MaterialSheetDecoration(
                      animationDuration: Duration.zero,
                      size: SheetSize.stretch,
                      color: fillColor,
                      borderRadius: sheetProvider.type == SheetType.bottomSheet
                          ? const BorderRadius.vertical(
                              top: Radius.circular(28),
                            )
                          : BorderRadius.zero,
                      clipBehavior: Clip.antiAlias,
                    ),
                    navigator: nestedNavigator,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
