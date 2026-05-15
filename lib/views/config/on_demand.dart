import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

class OnDemandView extends ConsumerStatefulWidget {
  const OnDemandView({super.key});

  @override
  ConsumerState createState() => _OnDemandViewState();
}

class _OnDemandViewState extends ConsumerState<OnDemandView> {
  void _handlePermanentlyDeniedLocationPermission() {
    if (system.isMacOS) {
      final appLocalizations = context.appLocalizations;
      globalState.showMessage(
        title: appLocalizations.locationPermissionRequired,
        cancelable: false,
        message: TextSpan(
          style: context.textTheme.bodyMedium,
          text: appLocalizations.locationPermissionGuide(appName),
        ),
      );
    } else if (system.isAndroid) {
      app?.openAppSettings();
    }
  }

  Future<void> _handleRequestLocationPermission() async {
    final appLocalizations = context.appLocalizations;
    final permission = ref.read(locationPermissionsProvider);
    if (permission == WifiSsidPermission.granted) {
      return;
    }
    if (permission == WifiSsidPermission.permanentlyDenied) {
      _handlePermanentlyDeniedLocationPermission();
      return;
    }
    final res = await wifiSsidManager.requestPermission();
    globalState.container.read(locationPermissionsProvider.notifier).value =
        res;
    if (!mounted) {
      return;
    }
    final needGo = await globalState.showMessage(
      title: appLocalizations.locationPermissionRequired,
      message: const TextSpan(
        text: '位置权限已被拒绝，无法获取当前 Wi-Fi 名称。请前往系统设置手动开启位置权限。',
      ),
      confirmText: appLocalizations.go,
    );
    if (needGo != true) {
      return;
    }
    app?.openAppSettings();
  }

  void _handleOpenBatteryOptimizationSettings() {
    final isDisabled = ref.read(batteryOptimizationDisableProvider);
    if (isDisabled) {
      return;
    }
    permissions.needWaitingBatteryOptimizationSettings = true;
    app?.openBatteryOptimizationSettings();
  }

  Future<void> _handleAddOrUpdate([String? ssid]) async {
    final ssids = ref.read(excludeSSIDsProvider);
    final appLocalizations = context.appLocalizations;
    final newSSID = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: '请输入SSID',
        value: '',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip('SSID').trim();
          }
          if (ssids.contains(value) && ssid != value) {
            return appLocalizations.existsTip('SSID').trim();
          }
          return null;
        },
      ),
    );
    if (newSSID == null || ssid == newSSID) {
      return;
    }
    globalState.container
        .read(excludeSSIDsProvider.notifier)
        .update((state) => [...state, newSSID]);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isLoading = ref.watch(
      loadingProvider(LoadingTag.batteryOptimization),
    );
    final batteryOptimizationDisable = ref.watch(
      batteryOptimizationDisableProvider,
    );
    final locationPermissionsGranted = ref.watch(
      locationPermissionsProvider.select(
        (state) => state == WifiSsidPermission.granted,
      ),
    );
    return CommonScaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: generateSectionV3(
                title: appLocalizations.prerequisites,
                items: [
                  if (system.isAndroid)
                    DecorationListItem(
                      minVerticalPadding: 8,
                      title: Text(appLocalizations.ignoreBatteryOptimization),
                      subtitle: Text(appLocalizations.batteryOptimizationDesc),
                      trailing: isLoading
                          ? const SizedBox(
                              width: 100,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox.square(
                                    dimension: 32,
                                    child: CommonCircleLoading(),
                                  ),
                                ],
                              ),
                            )
                          : CommonMinFilledButtonTheme(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: batteryOptimizationDisable
                                      ? null
                                      : context.colorScheme.error,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                  ),
                                  minimumSize: const Size(80, 40),
                                ),
                                onPressed:
                                    _handleOpenBatteryOptimizationSettings,
                                child: Text(
                                  batteryOptimizationDisable ? '已授权' : '点击授权',
                                ),
                              ),
                            ),
                    ),
                  if (system.isAndroid || system.isMacOS)
                    DecorationListItem(
                      minVerticalPadding: 8,
                      title: Text(appLocalizations.locationPermission),
                      subtitle: Text(appLocalizations.locationPermissionDesc),
                      trailing: CommonMinFilledButtonTheme(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: locationPermissionsGranted
                                ? null
                                : context.colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            minimumSize: const Size(80, 40),
                          ),
                          onPressed: _handleRequestLocationPermission,
                          child: Text(
                            locationPermissionsGranted ? '已授权' : '点击授权',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: ListHeader(
                title: appLocalizations.excludeSsids,
                subTitle: appLocalizations.excludeSsidsDesc,
                actions: [
                  CommonMinFilledButtonTheme(
                    child: FilledButton.tonal(
                      onPressed: _handleAddOrUpdate,
                      child: Text(appLocalizations.add),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ).copyWith(top: 12),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 48,
                ),
                // type: CommonCardType.filled,
                child: NullStatus(label: appLocalizations.ssidsEmpty),
              ),
            ),
          ),
        ],
      ),
      title: appLocalizations.onDemand,
    );
  }
}
