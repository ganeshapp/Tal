// Run with: flutter test tool/render_assets_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tal/core/engine_stub.dart';
import 'package:tal/core/store.dart';
import 'package:tal/main.dart';
import 'package:tal/theme.dart';

Future<void> capture(
  WidgetTester tester,
  GlobalKey key,
  String path, {
  double ratio = 1,
}) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes =
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes);
    image.dispose();
  });
}

void main() {
  testWidgets('Render app branding and preview images', (tester) async {
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1024, 1024);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: forest,
            child: Center(child: Mark(size: 780)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'assets/brand/icon.png');
    for (final e
        in {
          'mdpi': 48,
          'hdpi': 72,
          'xhdpi': 96,
          'xxhdpi': 144,
          'xxxhdpi': 192,
        }.entries) {
      await capture(
        tester,
        key,
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
        ratio: e.value / 1024,
      );
    }
    for (final size in [192, 512]) {
      await capture(
        tester,
        key,
        'web/icons/Icon-$size.png',
        ratio: size / 1024,
      );
      await capture(
        tester,
        key,
        'web/icons/Icon-maskable-$size.png',
        ratio: size / 1024,
      );
    }
    await capture(tester, key, 'web/favicon.png', ratio: 32 / 1024);
    final ios = jsonDecode(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
      ).readAsStringSync(),
    );
    for (final entry in ios['images']) {
      final String? file = entry['filename'];
      if (file == null) continue;
      final size =
          double.parse((entry['size'] as String).split('x').first) *
          double.parse((entry['scale'] as String).replaceAll('x', ''));
      await capture(
        tester,
        key,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/$file',
        ratio: size / 1024,
      );
    }
    final mac = jsonDecode(
      File(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
      ).readAsStringSync(),
    );
    for (final entry in mac['images']) {
      final String? file = entry['filename'];
      if (file == null) continue;
      final size =
          double.parse((entry['size'] as String).split('x').first) *
          double.parse((entry['scale'] as String).replaceAll('x', ''));
      await capture(
        tester,
        key,
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/$file',
        ratio: size / 1024,
      );
    }
    await tester.runAsync(() async {
      for (final name in ['Inter', 'Lora']) {
        await (FontLoader(name)
          ..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
      }
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final store = (await tester.runAsync(AppStore.load))!;
    for (final size in [const Size(390, 844), const Size(1440, 1080)]) {
      tester.view.physicalSize = size;
      final pageKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: pageKey,
          child: TalApp(store: store, engines: PreviewEngines()),
        ),
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        pageKey,
        'docs/screenshots/home-${size.width.toInt()}.png',
      );
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
