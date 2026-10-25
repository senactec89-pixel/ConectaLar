import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';

class MfaAdminCard extends StatefulWidget {
  const MfaAdminCard({super.key});

  @override
  State<MfaAdminCard> createState() => _MfaAdminCardState();
}

class _MfaAdminCardState extends State<MfaAdminCard> {
  late Future<bool> _status;

  @override
  void initState() {
    super.initState();
    _status = _consultar();
  }

  Future<bool> _consultar() async {
    if (AppServices.instance.modoDemo) return false;
    try {
      final status = await AppServices.instance.auth.statusMfaAdmin();
      return status['mfaAtivo'] == true;
    } on ApiException {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppInsets.card,
      child: FutureBuilder<bool>(
        future: _status,
        builder: (context, snapshot) {
          final ativo = snapshot.data == true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.phonelink_lock_outlined,
                    color: AppColors.verdeEscuro,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Autenticador administrativo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nao foi possivel consultar o status do autenticador.',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tentar novamente',
                      onPressed: () => setState(() => _status = _consultar()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                )
              else ...[
                Text(
                  ativo
                      ? 'Status: obrigatorio e ativo'
                      : 'Status: pendente de configuracao',
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  ativo
                      ? 'Toda entrada administrativa exige um codigo temporario do autenticador. Essa protecao nao pode ser desativada pela conta.'
                      : 'A API bloqueara as funcoes administrativas ate que a configuracao do autenticador seja concluida no proximo login.',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
