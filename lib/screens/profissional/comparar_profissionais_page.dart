import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/profissional.dart';
import '../../widgets/app_bar_custom.dart';

class CompararProfissionaisPage extends StatelessWidget {
  const CompararProfissionaisPage({required this.profissionais, super.key})
    : assert(profissionais.length == 2);

  final List<Profissional> profissionais;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: const AppBarCustom(title: 'Comparar profissionais'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 760
              ? (constraints.maxWidth - 720) / 2
              : AppSpace.pageGutter;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpace.md,
              horizontalPadding,
              AppSpace.xxl,
            ),
            children: [
              Text(
                'Compare informações públicas dos perfis.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textoSuave),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final profissional in profissionais)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.xs,
                        ),
                        child: _ResumoProfissional(profissional: profissional),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              for (final campo in _camposComparacao(profissionais))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: _CampoComparacao(campo: campo),
                ),
              const SizedBox(height: AppSpace.sm),
              const Card(
                child: Padding(
                  padding: AppInsets.card,
                  child: Text(
                    'O selo indica análise documental aprovada e não é garantia de segurança, qualidade ou resultado. O preço exibido é inicial; valores finais são combinados diretamente entre as partes.',
                    style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResumoProfissional extends StatelessWidget {
  const _ResumoProfissional({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final inicial = profissional.nome.trim().isEmpty
        ? '?'
        : profissional.nome.trim().characters.first.toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.verdePastel,
              foregroundColor: AppColors.verdeEscuro,
              child: Text(
                inicial,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              profissional.nome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  profissional.verificado
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: profissional.verificado
                      ? AppColors.verde
                      : AppColors.textoSuave,
                ),
                const SizedBox(width: AppSpace.xs),
                Flexible(
                  child: Text(
                    profissional.verificado ? 'Verificado' : 'Sem selo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoComparacao extends StatelessWidget {
  const _CampoComparacao({required this.campo});

  final _CampoComparado campo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(campo.titulo, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < campo.valores.length; index++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : AppSpace.sm,
                      ),
                      child: Semantics(
                        label:
                            '${campo.profissionais[index]}: ${campo.valores[index]}',
                        child: Text(
                          campo.valores[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoComparado {
  const _CampoComparado(this.titulo, this.profissionais, this.valores);

  final String titulo;
  final List<String> profissionais;
  final List<String> valores;
}

List<_CampoComparado> _camposComparacao(List<Profissional> profissionais) {
  String avaliacao(Profissional profissional) {
    final quantidade = profissional.quantidadeAvaliacoes ?? 0;
    final nota = profissional.notaMedia;
    if (nota == null || quantidade == 0) return 'Ainda sem avaliações';
    final sufixo = quantidade == 1 ? 'avaliação' : 'avaliações';
    return '${nota.toStringAsFixed(1).replaceAll('.', ',')} de 5 · $quantidade $sufixo';
  }

  String localizacao(Profissional profissional) {
    final cidade = [
      profissional.cidade,
      profissional.uf,
    ].whereType<String>().where((item) => item.trim().isNotEmpty).join('/');
    return cidade.isEmpty
        ? profissional.bairro
        : '${profissional.bairro}, $cidade';
  }

  String servicos(Profissional profissional) {
    final nomes = profissional.ofertas.isNotEmpty
        ? profissional.ofertas.map((oferta) => oferta.nome).toList()
        : profissional.servicos;
    if (nomes.isEmpty) return 'Serviços não informados';
    return nomes.join(' · ');
  }

  String preco(Profissional profissional) {
    final valor = profissional.precoInicial;
    if (valor == null) return 'Preço sob consulta';
    return 'A partir de R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  final nomes = profissionais.map((item) => item.nome).toList(growable: false);
  return [
    _CampoComparado(
      'Avaliações',
      nomes,
      profissionais.map(avaliacao).toList(growable: false),
    ),
    _CampoComparado(
      'Localização',
      nomes,
      profissionais.map(localizacao).toList(growable: false),
    ),
    _CampoComparado(
      'Serviços oferecidos',
      nomes,
      profissionais.map(servicos).toList(growable: false),
    ),
    _CampoComparado(
      'Preço inicial',
      nomes,
      profissionais.map(preco).toList(growable: false),
    ),
  ];
}
