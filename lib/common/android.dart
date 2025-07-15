import 'dart:io';

import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';

class Android {
  Future<void> init() async {
    app?.onExit = () async {
      await globalState.appController.savePreferences();
    };
  }
}

final android = Platform.isAndroid ? Android() : null;
