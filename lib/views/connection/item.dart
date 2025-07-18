import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final Function(String)? onClickKeyword;
  final Widget? trailing;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.onClickKeyword,
    this.trailing,
  });

  static double get subTitleHeight {
    return 40;
  }

  static double get height {
    final measure = globalState.measure;
    return measure.bodyMediumHeight +
        8 +
        12 +
        measure.bodyLargeHeight +
        subTitleHeight +
        16 * 2;
  }

  Future<ImageProvider?> _getPackageIcon(TrackerInfo connection) async {
    return await app?.getPackageIcon(connection.metadata.process);
  }

  String _getSourceText(TrackerInfo connection) {
    final metadata = connection.metadata;
    final progress =
        metadata.process.isNotEmpty ? '${metadata.process} · ' : '';
    final traffic = Traffic(
      up: connection.upload,
      down: connection.download,
    );
    return '$progress${traffic.toString()}';
  }

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always &&
            Platform.isAndroid,
      ),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 8,
          children: [
            Flexible(
              flex: 1,
              child: Text(
                trackerInfo.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge,
              ),
            ),
            Text(
              trackerInfo.start.lastUpdateTimeDesc,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          _getSourceText(trackerInfo),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final subTitle = SizedBox(
      height: subTitleHeight,
      child: Row(
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: ListView.separated(
              separatorBuilder: (_, __) => SizedBox(
                width: 6,
              ),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              itemCount: trackerInfo.chains.length,
              itemBuilder: (_, index) {
                final chain = trackerInfo.chains[index];
                return CommonChip(
                  label: chain,
                  onPressed: () {
                    if (onClickKeyword == null) return;
                    onClickKeyword!(chain);
                  },
                );
              },
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    final icon = value
        ? GestureDetector(
            onTap: () {
              if (onClickKeyword == null) return;
              final process = trackerInfo.metadata.process;
              if (process.isEmpty) return;
              onClickKeyword!(process);
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 48,
              height: 48,
              child: FutureBuilder<ImageProvider?>(
                future: _getPackageIcon(trackerInfo),
                builder: (_, snapshot) {
                  if (!snapshot.hasData && snapshot.data == null) {
                    return Container();
                  } else {
                    return Image(
                      image: snapshot.data!,
                      gaplessPlayback: true,
                      width: 48,
                      height: 48,
                    );
                  }
                },
              ),
            ),
          )
        : null;
    return ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      onTap: () {
        showExtend(
          context,
          builder: (_, type) {
            return AdaptiveSheetScaffold(
              type: type,
              body: TrackerInfoDetailView(
                trackerInfo: trackerInfo,
              ),
              title: '连接详情',
            );
          },
        );
      },
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              if (icon != null) icon,
              Flexible(
                child: title,
              )
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          subTitle,
        ],
      ),
    );
  }
}

class TrackerInfoDetailView extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const TrackerInfoDetailView({
    super.key,
    required this.trackerInfo,
  });

  String _getRuleText() {
    final rule = trackerInfo.rule;
    final rulePayload = trackerInfo.rulePayload;
    if (rulePayload.isNotEmpty) {
      return '$rule($rulePayload)';
    }
    return rule;
  }

  String _getProgressText() {
    final process = trackerInfo.metadata.process;
    final uid = trackerInfo.metadata.uid;
    if (uid != 0) {
      return '$process($uid)';
    }
    return process;
  }

  String _getSourceText() {
    final sourceIP = trackerInfo.metadata.sourceIP;
    if (sourceIP.isEmpty) {
      return '';
    }
    final sourcePort = trackerInfo.metadata.sourcePort;
    if (sourcePort.isNotEmpty) {
      return '$sourceIP:$sourcePort';
    }
    return sourceIP;
  }

  String _getDestinationText() {
    final destinationIP = trackerInfo.metadata.destinationIP;
    if (destinationIP.isEmpty) {
      return '';
    }
    final destinationPort = trackerInfo.metadata.destinationPort;
    if (destinationPort.isNotEmpty) {
      return '$destinationIP:$destinationPort';
    }
    return destinationIP;
  }

  Widget _buildItem({
    required String title,
    required String desc,
  }) {
    return ListItem(
      title: Row(
        spacing: 72,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Flexible(
            child: Text(
              desc,
              textAlign: TextAlign.end,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _buildItem(
        title: '创建时间',
        desc: trackerInfo.start.showFull,
      ),
      if (_getProgressText().isNotEmpty)
        _buildItem(
          title: '进程',
          desc: _getProgressText(),
        ),
      _buildItem(
        title: '连接类型',
        desc: trackerInfo.metadata.network,
      ),
      _buildItem(
        title: '规则',
        desc: _getRuleText(),
      ),
      if (trackerInfo.metadata.host.isNotEmpty)
        _buildItem(
          title: '域名',
          desc: trackerInfo.metadata.host,
        ),
      if (_getSourceText().isNotEmpty)
        _buildItem(
          title: '来源',
          desc: _getSourceText(),
        ),
      if (_getDestinationText().isNotEmpty)
        _buildItem(
          title: '目标',
          desc: _getDestinationText(),
        ),
      _buildItem(
        title: '上传',
        desc: TrafficValue(value: trackerInfo.upload).show,
      ),
      _buildItem(
        title: '下载',
        desc: TrafficValue(value: trackerInfo.download).show,
      ),
    ];
    return SelectionArea(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) {
          return items[index];
        },
      ),
    );
  }
}
