import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView> {
  final _requestsStateNotifier = ValueNotifier<ConnectionsState>(
    const ConnectionsState(),
  );
  List<Connection> _requests = [];
  final _tag = CacheTag.requests;
  late ScrollController _scrollController;

  _onSearch(String value) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      query: value,
    );
  }

  _onKeywordsUpdate(List<String> keywords) {
    _requestsStateNotifier.value =
        _requestsStateNotifier.value.copyWith(keywords: keywords);
  }

  @override
  void initState() {
    super.initState();
    final preOffset = globalState.computeScrollPositionCache[_tag] ?? -1;
    _scrollController = ScrollController(
      initialScrollOffset: preOffset > 0 ? preOffset : double.maxFinite,
    );
    _requests = globalState.appState.requests.list;
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      connections: _requests,
    );
    ref.listenManual(
      requestsProvider.select((state) => state.list),
      (prev, next) {
        if (!connectionListEquality.equals(prev, next)) {
          _requests = next;
          updateRequestsThrottler();
        }
      },
    );
  }

  @override
  void dispose() {
    _requestsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  updateRequestsThrottler() {
    throttler.call(FunctionTag.requests, () {
      final isEquality = connectionListEquality.equals(
        _requests,
        _requestsStateNotifier.value.connections,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
            connections: _requests,
          );
        }
      });
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: appLocalizations.requests,
      searchState: AppBarSearchState(onSearch: _onSearch),
      onKeywordsUpdate: _onKeywordsUpdate,
      body: ValueListenableBuilder<ConnectionsState>(
        valueListenable: _requestsStateNotifier,
        builder: (context, state, __) {
          final requests = state.list;
          final items = requests
              .map<Widget>(
                (connection) => ConnectionItem(
                  key: Key(connection.id),
                  connection: connection,
                  onClickKeyword: (value) {
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
          return items.isEmpty
              ? NullStatus(
                  label: appLocalizations.nullTip(appLocalizations.requests),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: CommonScrollBar(
                    trackVisibility: false,
                    controller: _scrollController,
                    child: ListView.builder(
                      reverse: true,
                      shrinkWrap: true,
                      physics: NextClampingScrollPhysics(),
                      controller: _scrollController,
                      itemBuilder: (_, index) {
                        return items[index];
                      },
                      itemExtentBuilder: (index, _) {
                        if (index.isOdd) {
                          return 0;
                        }
                        return ConnectionItem.height;
                      },
                      itemCount: items.length,
                    ),
                  ),
                );
        },
      ),
    );
  }
}
