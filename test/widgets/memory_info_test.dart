import 'dart:async';

import 'package:fl_clash/views/dashboard/widgets/memory_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('MemoryInfo refreshes only while the app is resumed', (
    tester,
  ) async {
    var readCount = 0;

    Future<num> readMemory() async {
      readCount++;
      return readCount;
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(
      TestApp(
        child: MemoryInfo(memoryReader: readMemory),
        homeBuilder: (child) => Scaffold(body: child),
      ),
    );
    await tester.pump();

    expect(readCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 3);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MemoryInfo ignores a request completed in the background', (
    tester,
  ) async {
    final requests = <Completer<num>>[];

    Future<num> readMemory() {
      final request = Completer<num>();
      requests.add(request);
      return request.future;
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TestApp(
        child: MemoryInfo(memoryReader: readMemory),
        homeBuilder: (child) => Scaffold(body: child),
      ),
    );
    await tester.pump();

    expect(requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    requests.first.complete(1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(requests, hasLength(2));

    requests.last.complete(2);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
