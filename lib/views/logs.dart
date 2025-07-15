import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  final _logsStateNotifier = ValueNotifier<LogsState>(LogsState(
    autoScrollToEnd: true,
  ));
  late ScrollController _scrollController;

  List<Log> _logs = [];

  @override
  void initState() {
    super.initState();
    _logs = globalState.appState.logs.list;
    _scrollController = ScrollController(
      initialScrollOffset: _logs.length * LogItem.height,
    );
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
      logs: _logs,
    );
    ref.listenManual(
      logsProvider.select((state) => state.list),
      (prev, next) {
        if (prev != next) {
          final isEquality = logListEquality.equals(prev, next);
          if (!isEquality) {
            _logs = next;
            updateLogsThrottler();
          }
        }
      },
    );
  }

  List<Widget> _buildActions() {
    return [
      ValueListenableBuilder(
        valueListenable: _logsStateNotifier,
        builder: (_, state, __) {
          return IconButton(
            style: state.autoScrollToEnd
                ? ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      context.colorScheme.secondaryContainer,
                    ),
                  )
                : null,
            onPressed: () {
              _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                autoScrollToEnd: !_logsStateNotifier.value.autoScrollToEnd,
              );
            },
            icon: const Icon(
              Icons.vertical_align_top_outlined,
            ),
          );
        },
      ),
      IconButton(
        onPressed: () {
          _handleExport();
        },
        icon: const Icon(
          Icons.save_as_outlined,
        ),
      ),
    ];
  }

  void _onSearch(String value) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _logsStateNotifier.value =
        _logsStateNotifier.value.copyWith(keywords: keywords);
  }

  @override
  void dispose() {
    _logsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _handleExport() async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        return await globalState.appController.exportLogs();
      },
      needLoading: true,
      title: appLocalizations.exportLogs,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
    );
  }

  updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      final isEquality = logListEquality.equals(
        _logs,
        _logsStateNotifier.value.logs,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
            logs: _logs,
          );
        }
      });
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      actions: _buildActions(),
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      body: ValueListenableBuilder<LogsState>(
        valueListenable: _logsStateNotifier,
        builder: (context, state, __) {
          final logs = state.list;
          final items = logs
              .map<Widget>(
                (log) => LogItem(
                  key: Key(log.dateTime),
                  log: log,
                  onClick: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                ),
              )
              .separated(
                const Divider(
                  height: 0,
                ),
              )
              .toList();
          return logs.isEmpty
              ? NullStatus(
                  label: appLocalizations.nullTip(
                    appLocalizations.logs,
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ScrollToEndBox(
                    onCancelToEnd: () {
                      _logsStateNotifier.value =
                          _logsStateNotifier.value.copyWith(
                        autoScrollToEnd: false,
                      );
                    },
                    controller: _scrollController,
                    enable: state.autoScrollToEnd,
                    dataSource: logs,
                    child: CommonScrollBar(
                      controller: _scrollController,
                      trackVisibility: false,
                      child: ListView.builder(
                        physics: NextClampingScrollPhysics(),
                        reverse: true,
                        shrinkWrap: true,
                        controller: _scrollController,
                        itemBuilder: (_, index) {
                          return items[index];
                        },
                        itemExtentBuilder: (index, _) {
                          if (index.isOdd) {
                            return 0;
                          }
                          return LogItem.height;
                        },
                        itemCount: items.length,
                      ),
                    ),
                  ),
                );
        },
      ),
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;

  static double get height {
    final measure = globalState.measure;
    return measure.bodyLargeHeight * 2 + 8 + 60 + 16;
  }

  const LogItem({
    super.key,
    required this.log,
    this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      title: SizedBox(
        height: globalState.measure.bodyLargeHeight * 2,
        child: Text(
          log.payload,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyLarge,
        ),
      ),
      subtitle: Column(
        children: [
          SizedBox(
            height: 16,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CommonChip(
                onPressed: () {
                  if (onClick == null) return;
                  onClick!(log.logLevel.name);
                },
                label: log.logLevel.name,
              ),
              SelectableText(
                log.dateTime,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
