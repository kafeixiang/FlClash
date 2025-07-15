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

  static double get height {
    final measure = globalState.measure;
    return measure.bodyLargeHeight +
        8 +
        12 +
        measure.bodyMediumHeight * 1 +
        40 +
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
    final title = Text(
      connection.desc,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodyLarge,
    );
    final subTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 8,
        ),
        Text(
          _getSourceText(connection),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(
          height: 12,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CommonChip(
              label: connection.chains.last,
              onPressed: () {
                if (onClickKeyword == null) return;
                onClickKeyword!(connection.chains.last);
              },
            ),
            Text(
              connection.start.lastUpdateTimeDesc,
            )
          ],
        )
      ],
    );
    return ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      onTap: () {},
      tileTitleAlignment: ListTileTitleAlignment.titleHeight,
      leading: value
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
          : null,
      title: title,
      subtitle: subTitle,
      trailing: trailing,
    );
  }
}
