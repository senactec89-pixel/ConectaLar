// Exporta a fonte SVG para os tamanhos nativos sem dependências do app.
// Execute na raiz: dart run tool/generate_brand_assets.dart
// Requer Chrome; CHROME_EXECUTABLE pode indicar outro executável compatível.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  final svg = await File(
    'assets/branding/conectalar_symbol.svg',
  ).readAsString();
  final profile = await Directory.systemTemp.createTemp('conectalar-brand-');
  Process? chrome;
  _Browser? browser;
  try {
    chrome = await Process.start(
      Platform.environment['CHROME_EXECUTABLE'] ?? 'google-chrome',
      [
        '--headless=new',
        '--disable-gpu',
        '--no-first-run',
        '--remote-debugging-port=0',
        '--user-data-dir=${profile.path}',
        'about:blank',
      ],
    );
    chrome.stdout.drain<void>();
    chrome.stderr.drain<void>();
    final portFile = File('${profile.path}/DevToolsActivePort');
    for (var attempt = 0; !await portFile.exists(); attempt++) {
      if (attempt >= 100) {
        throw StateError('Chrome não iniciou em 10 segundos.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final port = (await portFile.readAsLines()).first;
    final http = HttpClient();
    final response = await (await http.getUrl(
      Uri.parse('http://127.0.0.1:$port/json/list'),
    )).close();
    final pages = jsonDecode(await utf8.decoder.bind(response).join()) as List;
    http.close();
    final page = pages.firstWhere((item) => item['type'] == 'page');
    browser = _Browser(
      await WebSocket.connect(page['webSocketDebuggerUrl'] as String),
    );
    final cdp = browser;
    await browser.call('Page.enable');
    await browser.call('Emulation.setDefaultBackgroundColorOverride', {
      'color': {'r': 0, 'g': 0, 'b': 0, 'a': 0},
    });

    Future<Uint8List> render(
      int size, {
      bool opaque = true,
      double scale = 0.9,
    }) async {
      await cdp.call('Emulation.setDeviceMetricsOverride', {
        'width': size,
        'height': size,
        'deviceScaleFactor': 1,
        'mobile': false,
      });
      final markup =
          '''<html><head><style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:${opaque ? '#FFFFFF' : 'transparent'}}
body{display:flex;align-items:center;justify-content:center}
svg{width:${scale * 100}%;height:${scale * 100}%}
</style></head><body>$svg</body></html>''';
      await cdp.call('Runtime.evaluate', {
        'expression':
            '''document.open();document.write(${jsonEncode(markup)});document.close();
new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))''',
        'awaitPromise': true,
      });
      final capture = await cdp.call('Page.captureScreenshot', {
        'format': 'png',
      });
      return base64Decode(capture['data'] as String);
    }

    Future<void> export(
      String path,
      int size, {
      bool opaque = true,
      double scale = 0.9,
    }) async {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(await render(size, opaque: opaque, scale: scale));
      stdout.writeln('$path ($size px)');
    }

    await export(
      'assets/branding/conectalar_symbol.png',
      512,
      opaque: false,
      scale: 1,
    );
    await export('assets/branding/conectalar_icon_1024.png', 1024);
    for (final density in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await export(
        'android/app/src/main/res/mipmap-${density.key}/ic_launcher.png',
        density.value,
      );
    }
    for (final platform in ['ios', 'macos']) {
      final directory = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
      final manifest =
          jsonDecode(await File('$directory/Contents.json').readAsString())
              as Map;
      final exported = <String>{};
      for (final entry in manifest['images'] as List) {
        final name = entry['filename'] as String;
        if (!exported.add(name)) continue;
        final points = double.parse((entry['size'] as String).split('x').first);
        final factor = double.parse(
          (entry['scale'] as String).replaceAll('x', ''),
        );
        await export('$directory/$name', (points * factor).round());
      }
    }
    for (var scale = 1; scale <= 3; scale++) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await export(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        128 * scale,
        opaque: false,
      );
    }
    for (final size in [192, 512]) {
      await export('web/icons/Icon-$size.png', size);
      await export('web/icons/Icon-maskable-$size.png', size, scale: 0.74);
    }
    await export('web/favicon.png', 32, opaque: false, scale: 1);
    final frames = <int, Uint8List>{};
    for (final size in [16, 24, 32, 48, 64, 128, 256]) {
      frames[size] = await render(size);
    }
    final header = ByteData(6 + 16 * frames.length);
    header.setUint16(2, 1, Endian.little);
    header.setUint16(4, frames.length, Endian.little);
    var offset = header.lengthInBytes;
    var index = 0;
    for (final frame in frames.entries) {
      final at = 6 + 16 * index++;
      header.setUint8(at, frame.key == 256 ? 0 : frame.key);
      header.setUint8(at + 1, frame.key == 256 ? 0 : frame.key);
      header.setUint16(at + 4, 1, Endian.little);
      header.setUint16(at + 6, 32, Endian.little);
      header.setUint32(at + 8, frame.value.length, Endian.little);
      header.setUint32(at + 12, offset, Endian.little);
      offset += frame.value.length;
    }
    final ico = BytesBuilder()..add(header.buffer.asUint8List());
    frames.values.forEach(ico.add);
    await File(
      'windows/runner/resources/app_icon.ico',
    ).writeAsBytes(ico.takeBytes());

    // Os mesmos caminhos da fonte SVG alimentam os vetores nativos Android.
    final paths = RegExp(r'<path fill="([^"]+)" d="([^"]+)"')
        .allMatches(svg)
        .map(
          (match) =>
              '<path android:fillColor="${match[1]}" android:pathData="${match[2]}"/>',
        )
        .join('\n');
    for (final adaptive in [false, true]) {
      final name = adaptive
          ? 'conectalar_adaptive_foreground'
          : 'conectalar_logo';
      final viewport = adaptive ? 108 : 640;
      final transform = adaptive
          ? 'android:scaleX="0.1" android:scaleY="0.1" android:translateX="-22.8" android:translateY="13.2"'
          : 'android:translateX="-448" android:translateY="-88"';
      await File('android/app/src/main/res/drawable/$name.xml').writeAsString(
        '''<?xml version="1.0" encoding="utf-8"?>
<!-- Gerado por tool/generate_brand_assets.dart a partir do SVG oficial. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="${adaptive ? 108 : 128}dp" android:height="${adaptive ? 108 : 128}dp" android:viewportWidth="$viewport" android:viewportHeight="$viewport">
  <group $transform>$paths</group>
</vector>
''',
      );
    }
  } finally {
    await browser?.close();
    if (chrome != null) {
      chrome.kill();
      await chrome.exitCode;
    }
    // Processos auxiliares do Chrome podem terminar após o processo principal.
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        if (await profile.exists()) await profile.delete(recursive: true);
        break;
      } on FileSystemException {
        if (attempt == 2) {
          stderr.writeln(
            'Assets exportados; perfil temporário em ${profile.path}.',
          );
        }
      }
    }
  }
}

class _Browser {
  _Browser(this.socket) {
    subscription = socket.listen((data) {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final completer = pending.remove(message['id']);
      if (completer == null) return;
      if (message.containsKey('error')) {
        completer.completeError(StateError('${message['error']}'));
      } else {
        completer.complete(message['result'] as Map<String, dynamic>);
      }
    });
  }
  final WebSocket socket;
  late final StreamSubscription<dynamic> subscription;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  int nextId = 0;
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) {
    final id = ++nextId;
    final completer = Completer<Map<String, dynamic>>();
    pending[id] = completer;
    socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<void> close() async {
    await subscription.cancel();
    await socket.close();
  }
}
