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

  // Widget _buildTable(LogsState state) {
  //   final items = state.list;
  //   final payload = state.list.reduce(
  //     (longest, current) {
  //       return current.payload.length > longest.payload.length
  //           ? current
  //           : longest;
  //     },
  //   ).payload;
  //   final size = globalState.measure.computeTextSize(
  //     Text(
  //       payload,
  //       style: context.textTheme.bodyMedium,
  //       maxLines: 1,
  //     ),
  //   );
  //   print("[loogest]===>${payload},${size.width}");
  //   return Padding(
  //     padding: EdgeInsets.all(8),
  //     child: TableView.builder(
  //       verticalDetails: ScrollableDetails.vertical(
  //         controller: _scrollController,
  //         reverse: true,
  //         physics: NextClampingScrollPhysics(),
  //       ),
  //       columnBuilder: (index) {
  //         if (index == 0) {
  //           return const TableSpan(
  //             extent: FixedTableSpanExtent(100),
  //           );
  //         }
  //         return TableSpan(
  //           extent: MaxSpanExtent(
  //             RemainingSpanExtent(),
  //             FixedTableSpanExtent(
  //               size.width + 300,
  //             ),
  //           ),
  //         );
  //       },
  //       columnCount: 2,
  //       rowCount: items.length,
  //       rowBuilder: (_) {
  //         return const TableSpan(
  //           extent: FixedTableSpanExtent(36),
  //         );
  //       },
  //       cellBuilder: (_, vicinity) {
  //         final item = items[vicinity.row];
  //         return TableViewCell(
  //           child: Container(
  //             padding: EdgeInsets.symmetric(
  //               vertical: 4,
  //               horizontal: 6,
  //             ),
  //             alignment: Alignment.centerLeft,
  //             child: vicinity.column == 0
  //                 ? Text(
  //                     item.logLevel.name,
  //                     style: context.textTheme.bodyMedium,
  //                   )
  //                 : Text(
  //                     item.payload,
  //                     maxLines: 1,
  //                     style: context.textTheme.bodyMedium,
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget _buildList(LogsState state) {
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

    return ListView.builder(
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
    );
  }

  @override
  void dispose() {
    _logsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
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

  void updateLogsThrottler() {
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
          if (logs.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(
                appLocalizations.logs,
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ScrollToEndBox(
              onCancelToEnd: () {
                _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                  autoScrollToEnd: false,
                );
              },
              controller: _scrollController,
              enable: state.autoScrollToEnd,
              dataSource: logs,
              child: CommonScrollBar(
                controller: _scrollController,
                trackVisibility: false,
                child: _buildList(state),
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
