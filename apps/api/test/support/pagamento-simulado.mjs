// Local test fixture only: no database, provider, network or money movement.
export class PagamentoSimulado {
  constructor(totalCentavos) {
    validarCentavos(totalCentavos);
    this.totalCentavos = totalCentavos;
    this.recebidoCentavos = 0;
    this.eventos = new Map();
    this.profissionalConcluiu = false;
    this.clienteConfirmou = false;
    this.contestado = false;
    this.repasseSimulado = false;
  }

  receber({ eventoId, valorCentavos }) {
    if (typeof eventoId !== 'string' || !eventoId.trim()) throw new Error('EVENTO_INVALIDO');
    validarCentavos(valorCentavos);
    if (this.eventos.has(eventoId)) {
      if (this.eventos.get(eventoId) !== valorCentavos) throw new Error('EVENTO_CONFLITANTE');
      return;
    }
    if (this.repasseSimulado || valorCentavos > this.totalCentavos - this.recebidoCentavos) {
      throw new Error('VALOR_INESPERADO');
    }
    this.eventos.set(eventoId, valorCentavos);
    this.recebidoCentavos += valorCentavos;
  }

  concluirPeloProfissional() {
    if (this.contestado || this.repasseSimulado) throw new Error('CONCLUSAO_INDISPONIVEL');
    this.profissionalConcluiu = true;
  }

  confirmarPeloCliente() {
    if (!this.profissionalConcluiu || this.contestado || this.repasseSimulado) {
      throw new Error('CONFIRMACAO_INDISPONIVEL');
    }
    this.clienteConfirmou = true;
  }

  contestar() {
    if (!this.profissionalConcluiu || this.clienteConfirmou || this.repasseSimulado) {
      throw new Error('CONTESTACAO_INDISPONIVEL');
    }
    this.contestado = true;
  }

  simularRepasse() {
    if (!this.profissionalConcluiu || !this.clienteConfirmou || this.contestado ||
        this.recebidoCentavos !== this.totalCentavos || this.repasseSimulado) {
      throw new Error('REPASSE_INDISPONIVEL');
    }
    this.repasseSimulado = true;
    return { valorCentavos: this.recebidoCentavos, apenasSimulacao: true };
  }
}

function validarCentavos(valor) {
  if (!Number.isSafeInteger(valor) || valor <= 0) throw new Error('VALOR_INVALIDO');
}
