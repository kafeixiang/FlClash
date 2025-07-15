import 'dart:async';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  final _connectionsStateNotifier = ValueNotifier<ConnectionsState>(
    const ConnectionsState(),
  );
  final ScrollController _scrollController = ScrollController();

  Timer? timer;

  List<Widget> _buildActions() {
    return [
      IconButton(
        onPressed: () async {
          clashCore.closeConnections();
          _connectionsStateNotifier.value =
              _connectionsStateNotifier.value.copyWith(
            connections: await clashCore.getConnections(),
          );
        },
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ];
  }

  void _onSearch(String value) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _connectionsStateNotifier.value =
        _connectionsStateNotifier.value.copyWith(keywords: keywords);
  }

  Future<void> _updateConnections() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(
          connections: await clashCore.getConnections(),
        );
        timer = Timer(Duration(seconds: 1), () async {
          _updateConnections();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateConnections();
  }

  Future<void> _handleBlockConnection(String id) async {
    clashCore.closeConnection(id);
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      connections: await clashCore.getConnections(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      actions: _buildActions(),
      body: ValueListenableBuilder<ConnectionsState>(
        valueListenable: _connectionsStateNotifier,
        builder: (_, state, __) {
          final connections = state.list;
          if (connections.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
            );
          }
          final items = connections
              .map<Widget>(
                (connection) => ConnectionItem(
                  key: Key(connection.id),
                  connection: connection,
                  onClickKeyword: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.block),
                    onPressed: () {
                      _handleBlockConnection(connection.id);
                    },
                  ),
                ),
              )
              .separated(
                const Divider(
                  height: 0,
                ),
              )
              .toList();
          return CommonScrollBar(
            trackVisibility: false,
            controller: _scrollController,
            child: ListView.builder(
              controller: _scrollController,
              itemBuilder: (context, index) {
                return items[index];
              },
              itemExtentBuilder: (index, _) {
                if (index.isOdd) {
                  return 0;
                }
                return ConnectionItem.height;
              },
              itemCount: connections.length,
            ),
          );
        },
      ),
    );
  }
}
