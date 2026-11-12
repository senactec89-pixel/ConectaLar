const HORA_MS = 60 * 60 * 1000;
const PRAZO_RESPOSTA_MS = 48 * HORA_MS;
const FUSO_AGENDA = 'America/Sao_Paulo';

export function calcularExpiracaoProposta(
  criadoEm: Date,
  dataServico: string,
  horarioServico: string,
): Date {
  const criadoEmMs = criadoEm.getTime();
  if (!Number.isFinite(criadoEmMs)) throw new Error('Data de criacao invalida.');

  const inicioServicoMs = instanteCivil(dataServico, horarioServico);
  return new Date(Math.min(criadoEmMs + PRAZO_RESPOSTA_MS, inicioServicoMs));
}

export function propostaExpirada(expiraEm: Date, agora = new Date()): boolean {
  return agora.getTime() >= expiraEm.getTime();
}

function instanteCivil(data: string, horario: string): number {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(data) || !/^\d{2}:\d{2}$/.test(horario)) {
    throw new Error('Data ou horario do servico invalido.');
  }

  const alvoCivilMs = Date.parse(`${data}T${horario}:00.000Z`);
  if (!Number.isFinite(alvoCivilMs)) throw new Error('Data ou horario do servico invalido.');

  let instanteMs = alvoCivilMs;
  for (let tentativa = 0; tentativa < 4; tentativa += 1) {
    const observadoCivilMs = civilMsNoFuso(new Date(instanteMs));
    const ajuste = alvoCivilMs - observadoCivilMs;
    instanteMs += ajuste;
    if (ajuste === 0) return instanteMs;
  }
  return instanteMs;
}

function civilMsNoFuso(instante: Date): number {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: FUSO_AGENDA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(instante).reduce<Record<string, string>>((resultado, parte) => {
    resultado[parte.type] = parte.value;
    return resultado;
  }, {});

  return Date.parse(
    `${partes.year}-${partes.month}-${partes.day}T${partes.hour}:${partes.minute}:${partes.second}.000Z`,
  );
}
