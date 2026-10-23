import '../models/documento_verificacao.dart';

enum SituacaoDocumentalEstado { naoEnviado, emAnalise, aprovado, rejeitado }

class SituacaoDocumental {
  const SituacaoDocumental({
    required this.estado,
    required this.titulo,
    required this.orientacao,
    this.motivo,
  });

  final SituacaoDocumentalEstado estado;
  final String titulo;
  final String orientacao;
  final String? motivo;
}

SituacaoDocumental situacaoDocumentoIdentidade(
  List<DocumentoVerificacao> documentos,
) {
  final identidade =
      documentos
          .where((item) => item.tipoDocumento == 'documento_identidade')
          .toList()
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

  if (identidade.any((item) => item.status == 'aprovado')) {
    return const SituacaoDocumental(
      estado: SituacaoDocumentalEstado.aprovado,
      titulo: 'Documento de identidade aprovado',
      orientacao:
          'A análise documental foi concluída. Consulte as outras etapas da habilitação de segurança.',
    );
  }
  if (identidade.isEmpty) {
    return const SituacaoDocumental(
      estado: SituacaoDocumentalEstado.naoEnviado,
      titulo: 'Documento de identidade não enviado',
      orientacao:
          'Envie um documento de identidade para iniciar a análise administrativa.',
    );
  }

  final recente = identidade.first;
  if (recente.status == 'pendente') {
    return const SituacaoDocumental(
      estado: SituacaoDocumentalEstado.emAnalise,
      titulo: 'Documento em análise',
      orientacao:
          'A equipe administrativa ainda não concluiu a análise. Atualize esta tela para consultar a decisão.',
    );
  }
  if (recente.status == 'rejeitado') {
    return SituacaoDocumental(
      estado: SituacaoDocumentalEstado.rejeitado,
      titulo: 'Documento precisa ser reenviado',
      orientacao:
          'Confira o motivo informado, corrija o arquivo e envie uma nova versão.',
      motivo: recente.motivoRejeicao,
    );
  }

  return const SituacaoDocumental(
    estado: SituacaoDocumentalEstado.emAnalise,
    titulo: 'Situação documental em atualização',
    orientacao: 'Atualize esta tela para consultar a situação mais recente.',
  );
}
