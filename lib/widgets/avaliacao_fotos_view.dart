import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/service_registry.dart';

class AvaliacaoFotosView extends StatelessWidget {
  const AvaliacaoFotosView({required this.fotos, super.key});

  final List<dynamic> fotos;

  @override
  Widget build(BuildContext context) {
    final urls = fotos
        .whereType<Map>()
        .map((foto) => foto['url'])
        .whereType<String>()
        .where((url) => url.startsWith('avaliacoes/'))
        .toList(growable: false);
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final url in urls) _AvaliacaoFotoTile(url: url)],
      ),
    );
  }
}

class _AvaliacaoFotoTile extends StatefulWidget {
  const _AvaliacaoFotoTile({required this.url});

  final String url;

  @override
  State<_AvaliacaoFotoTile> createState() => _AvaliacaoFotoTileState();
}

class _AvaliacaoFotoTileState extends State<_AvaliacaoFotoTile> {
  late Future<ApiBinaryResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = AppServices.instance.api.getBinary(widget.url);
  }

  @override
  void didUpdateWidget(covariant _AvaliacaoFotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = AppServices.instance.api.getBinary(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ApiBinaryResponse>(
    future: _future,
    builder: (context, snapshot) {
      final bytes = snapshot.data?.bytes;
      return SizedBox(
        width: 96,
        height: 96,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: snapshot.connectionState != ConnectionState.done
              ? const ColoredBox(
                  color: Color(0xFFF1F4F2),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : bytes == null
              ? const ColoredBox(
                  color: Color(0xFFF1F4F2),
                  child: Icon(Icons.broken_image_outlined),
                )
              : Material(
                  color: Colors.transparent,
                  child: Ink.image(
                    image: MemoryImage(bytes),
                    fit: BoxFit.cover,
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => Dialog(
                          child: InteractiveViewer(
                            child: Image.memory(bytes, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
