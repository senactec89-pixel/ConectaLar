// Captura a galeria DEMO com Chrome DevTools Protocol, sem dependências extras.
// Requer build/web servido localmente e Chrome com depuração remota.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  String option(String name, String fallback) =>
      args
          .where((arg) => arg.startsWith('--$name='))
          .map((arg) => arg.substring(name.length + 3))
          .firstOrNull ??
      fallback;

  final base = Uri.parse(option('base', 'http://127.0.0.1:8765/'));
  if (!const {'127.0.0.1', 'localhost'}.contains(base.host)) {
    throw ArgumentError('Use a galeria DEMO em um servidor local.');
  }
  final output = Directory(
    option('output', 'docs/evidencias/estilizacao-2026-10-14'),
  );
  await output.create(recursive: true);
  final manifest = File('${output.path}/capturas.json');
  final records = <Map<String, dynamic>>[];
  final previousErrors = <dynamic>[];
  if (await manifest.exists()) {
    final previous =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    records.addAll((previous['capturas'] as List).cast<Map<String, dynamic>>());
    previousErrors.addAll(previous['excecoesNavegador'] as List);
  }
  final widths = option('widths', '360,390,412').split(',').map(int.parse);
  final scales = option('scales', '1,2').split(',').map(int.parse);
  final settleMilliseconds = int.parse(option('settle-ms', '0'));
  final scenes = option(
    'scenes',
    'home,perfil-publico,busca,admin-documentos,agenda',
  ).split(',');
  final http = HttpClient();
  final pagesRequest = await http.getUrl(
    Uri.parse('http://127.0.0.1:${option('port', '9335')}/json/list'),
  );
  final pages =
      jsonDecode(await utf8.decoder.bind(await pagesRequest.close()).join())
          as List;
  http.close();
  final page = pages.cast<Map<String, dynamic>>().firstWhere(
    (item) => item['type'] == 'page',
  );
  final cdp = _Cdp(
    await WebSocket.connect(page['webSocketDebuggerUrl'] as String),
  );
  Future<void> screenshot(String name, int width, int scale) async {
    final capture = await cdp.call('Page.captureScreenshot', {
      'format': 'png',
      'fromSurface': true,
      'captureBeyondViewport': false,
    });
    final bytes = base64Decode(capture['data'] as String);
    if (bytes.length < 10000) throw StateError('Captura vazia: $name.');
    final file = File('${output.path}/$name-$width.png');
    await file.writeAsBytes(bytes);
    records.add({
      'arquivo': file.path.split('/').last,
      'largura': width,
      'altura': 844,
      'dpr': 1,
      'escalaTexto': scale,
    });
    stdout.writeln(file.path);
  }

  try {
    await cdp.call('Page.enable');
    await cdp.call('Runtime.enable');
    for (final width in widths) {
      await cdp.call('Emulation.setDeviceMetricsOverride', {
        'width': width,
        'height': 844,
        'deviceScaleFactor': 1,
        'mobile': true,
        'screenWidth': width,
        'screenHeight': 844,
      });
      for (final scale in scales) {
        for (final scene in scenes) {
          final name = '$scene${scale == 2 ? '-200' : ''}';
          await cdp.call('Page.navigate', {
            'url': base
                .replace(
                  queryParameters: {
                    'tela': scene,
                    if (scale == 2) 'escala': '2',
                  },
                )
                .toString(),
          });
          final limiteCarregamento = DateTime.now().add(
            const Duration(seconds: 90),
          );
          Map<String, dynamic> preview = const {};
          while (DateTime.now().isBefore(limiteCarregamento)) {
            final check = await cdp.call('Runtime.evaluate', {
              'expression':
                  '({url: location.href, semanticos: document.querySelectorAll("flt-semantics").length})',
              'returnByValue': true,
            });
            preview =
                (check['result'] as Map<String, dynamic>)['value']
                    as Map<String, dynamic>;
            if (preview['semanticos'] is num &&
                (preview['semanticos'] as num) > 0) {
              break;
            }
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          final pagina = Uri.parse(preview['url'] as String);
          if (pagina.host != base.host || (preview['semanticos'] as num) == 0) {
            throw StateError(
              'A galeria não carregou a tela $scene: ${pagina.host}.',
            );
          }
          if (settleMilliseconds > 0) {
            await Future<void>.delayed(
              Duration(milliseconds: settleMilliseconds),
            );
          }
          await screenshot(name, width, scale);
          if (scene == 'admin-documentos') {
            await cdp.click('Visualizar');
            await Future<void>.delayed(const Duration(seconds: 6));
            await screenshot('$name-arquivo', width, scale);
            await cdp.click('Conferido');
            await Future<void>.delayed(const Duration(milliseconds: 500));
            await cdp.call('Input.dispatchMouseEvent', {
              'type': 'mouseWheel',
              'x': width ~/ 2,
              'y': 600,
              'deltaX': 0,
              'deltaY': 500,
            });
            await Future<void>.delayed(const Duration(milliseconds: 500));
            await cdp.click('Analisar');
            await Future<void>.delayed(const Duration(milliseconds: 500));
            await screenshot('$name-decisao', width, scale);
          } else {
            for (final position in [('conteudo', 480), ('final', 3000)]) {
              await cdp.call('Input.dispatchMouseEvent', {
                'type': 'mouseWheel',
                'x': width ~/ 2,
                'y': 440,
                'deltaX': 0,
                'deltaY': position.$2,
              });
              await Future<void>.delayed(const Duration(milliseconds: 500));
              await screenshot('$name-${position.$1}', width, scale);
            }
          }
        }
      }
    }
    final browserErrors = [...previousErrors, ...cdp.exceptions];
    await manifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'origem': 'Flutter Web em galeria DEMO local; dados fictícios',
        'capturas': records,
        'excecoesNavegador': browserErrors,
      }),
    );
    if (browserErrors.isNotEmpty) {
      throw StateError(
        'O navegador registrou exceções. Confira capturas.json.',
      );
    }
  } finally {
    await cdp.close();
  }
}

class _Cdp {
  _Cdp(this.socket) {
    subscription = socket.listen((data) {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      if (message['method'] == 'Runtime.exceptionThrown') {
        exceptions.add(message['params']);
      }
      if (message['method'] == 'Runtime.consoleAPICalled') {
        final params = message['params'] as Map<String, dynamic>;
        final values = (params['args'] as List)
            .cast<Map<String, dynamic>>()
            .map((arg) => arg['value'] ?? arg['description'] ?? '')
            .join(' ');
        if (RegExp(
          r'EXCEPTION CAUGHT|Unable to load|overflowed by|Error while',
          caseSensitive: false,
        ).hasMatch(values)) {
          exceptions.add({'console': values});
        }
      }
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
  final exceptions = <dynamic>[];
  int nextId = 0;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final id = ++nextId;
    final completer = Completer<Map<String, dynamic>>();
    pending[id] = completer;
    socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<void> click(String label) async {
    final match = jsonEncode(label);
    final result = await call('Runtime.evaluate', {
      'expression':
          '''(() => {
        const nodes = [...document.querySelectorAll('flt-semantics')];
        const candidates = nodes.filter(node =>
          ((node.getAttribute('aria-label') || '').includes($match) ||
           (node.textContent || '').includes($match)) &&
          node.getAttribute('role') === 'button');
        candidates.sort((a, b) => {
          const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
          return ra.width * ra.height - rb.width * rb.height;
        });
        const node = candidates.find(node => {
          const rect = node.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 && rect.top < 844;
        });
        if (!node) return null;
        const rect = node.getBoundingClientRect();
        return {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2};
      })()''',
      'returnByValue': true,
    });
    final point = (result['result'] as Map<String, dynamic>)['value'];
    if (point == null) throw StateError('Ação não encontrada: $label.');
    for (final type in ['mousePressed', 'mouseReleased']) {
      await call('Input.dispatchMouseEvent', {
        'type': type,
        'x': point['x'],
        'y': point['y'],
        'button': 'left',
        'clickCount': 1,
      });
    }
  }

  Future<void> close() async {
    await subscription.cancel();
    await socket.close();
  }
}
