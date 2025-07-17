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

class ConnectionItem extends ConsumerWidget {
  final Connection connection;
  final Function(String)? onClickKeyword;
  final Widget? trailing;

  const ConnectionItem({
    super.key,
    required this.connection,
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

  Future<ImageProvider?> _getPackageIcon(Connection connection) async {
    return await app?.getPackageIcon(connection.metadata.process);
  }

  String _getSourceText(Connection connection) {
    final metadata = connection.metadata;
    final progress =
        metadata.process.isNotEmpty ? '${metadata.process} · ' : '';
    final traffic = Traffic(
      up: connection.upload,
      down: connection.download,
    );
    return '$progress ${traffic.toString()}';
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
                connection.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge,
              ),
            ),
            Text(
              connection.start.lastUpdateTimeDesc,
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
          _getSourceText(connection),
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
              itemCount: connection.chains.length,
              itemBuilder: (_, index) {
                final chain = connection.chains[index];
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
              final process = connection.metadata.process;
              if (process.isEmpty) return;
              onClickKeyword!(process);
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 48,
              height: 48,
              child: FutureBuilder<ImageProvider?>(
                future: _getPackageIcon(connection),
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
      onTap: () {},
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
