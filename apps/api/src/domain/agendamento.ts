import { BadRequestException } from '@nestjs/common';

export const fusoAgenda = 'America/Sao_Paulo';
export const duracaoLegadaMinutos = 120;

export function agoraCivil(data: Date = new Date()): { data: string; horario: string } {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: fusoAgenda,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(data).reduce<Record<string, string>>((resultado, parte) => {
    resultado[parte.type] = parte.value;
    return resultado;
  }, {});
  return {
    data: `${partes.year}-${partes.month}-${partes.day}`,
    horario: `${partes.hour}:${partes.minute}`,
  };
}

export function horarioIniciado(dataServico: string, horarioServico: string, agora = new Date()): boolean {
  const civil = agoraCivil(agora);
  return `${dataServico}T${horarioServico}` <= `${civil.data}T${civil.horario}`;
}

export interface PeriodoAtendimento {
  readonly dataServico: string;
  readonly horarioServico: string;
  readonly duracaoMinutos: number;
}

export function parseDuracao(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 1 || value > 1_440) {
    throw new BadRequestException({ code: 'DURACAO_INVALIDA' });
  }
  return value;
}

export function minutosHorario(value: string): number {
  const [hora = 0, minuto = 0] = value.split(':').map(Number);
  return hora * 60 + minuto;
}

export function horarioMinutos(value: number): string {
  return `${Math.floor(value / 60).toString().padStart(2, '0')}:${(value % 60).toString().padStart(2, '0')}`;
}

export function inicioCivil(periodo: PeriodoAtendimento): number {
  // Compare civil times in the single approved agenda timezone. Do not let the
  // server's own TZ move a DATE or an appointment to another day.
  return Date.parse(`${periodo.dataServico.slice(0, 10)}T00:00:00Z`) +
    minutosHorario(periodo.horarioServico) * 60_000;
}

export function periodosSobrepostos(a: PeriodoAtendimento, b: PeriodoAtendimento): boolean {
  const inicioA = inicioCivil(a);
  const inicioB = inicioCivil(b);
  return inicioA < inicioB + b.duracaoMinutos * 60_000 &&
    inicioB < inicioA + a.duracaoMinutos * 60_000;
}

export function diaAnterior(data: string): string {
  return new Date(Date.parse(`${data}T00:00:00Z`) - 86_400_000).toISOString().slice(0, 10);
}

export function intervalosLivres(
  data: string,
  semanais: readonly { diaSemana: number; horaInicio: string; horaFim: string; ativo: boolean }[],
  ocupados: readonly PeriodoAtendimento[],
): { horaInicio: string; horaFim: string }[] {
  const meiaNoite = Date.parse(`${data}T00:00:00Z`);
  const diaSemana = new Date(meiaNoite).getUTCDay();
  let livres = semanais.filter((item) => item.ativo && item.diaSemana === diaSemana)
    .map((item) => [minutosHorario(item.horaInicio), minutosHorario(item.horaFim)] as const);
  for (const ocupado of ocupados) {
    const inicio = (inicioCivil(ocupado) - meiaNoite) / 60_000;
    const fim = inicio + ocupado.duracaoMinutos;
    livres = livres.flatMap(([a, b]) => {
      if (inicio >= b || fim <= a) return [[a, b] as const];
      return [
        ...(inicio > a ? [[a, inicio] as const] : []),
        ...(fim < b ? [[fim, b] as const] : []),
      ];
    });
  }
  return livres.sort(([a], [b]) => a - b).map(([inicio, fim]) => ({
    horaInicio: horarioMinutos(inicio), horaFim: horarioMinutos(fim),
  }));
}
