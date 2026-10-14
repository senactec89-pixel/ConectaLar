import { BadGatewayException, BadRequestException, Injectable } from '@nestjs/common';

export interface LocalizacaoEndereco {
  readonly cep: string;
  readonly logradouro: string;
  readonly complemento: string | null;
  readonly bairro: string;
  readonly cidade: string;
  readonly uf: string;
  readonly regiao: string | null;
  readonly ibge: string | null;
  readonly latitude: number | null;
  readonly longitude: number | null;
  readonly precisao: string | null;
}

interface EnderecoGeocodificavel {
  readonly cep?: string | null;
  readonly logradouro?: string | null;
  readonly numero?: string | null;
  readonly bairro?: string | null;
  readonly cidade?: string | null;
  readonly uf?: string | null;
}

@Injectable()
export class LocalizacaoService {
  async consultarCep(valor: string): Promise<LocalizacaoEndereco> {
    const cep = somenteCep(valor);
    const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(8_000),
    }).catch(() => null);
    if (response === null || !response.ok) {
      throw new BadGatewayException({
        code: 'SERVICO_CEP_INDISPONIVEL',
        message: 'A consulta de CEP está indisponível. Tente novamente.',
      });
    }

    const data = (await response.json()) as Record<string, unknown>;
    if (data.erro === true) {
      throw new BadRequestException({
        code: 'CEP_NAO_ENCONTRADO',
        message: 'CEP não encontrado.',
      });
    }

    const endereco = {
      cep,
      logradouro: texto(data.logradouro),
      complemento: textoOpcional(data.complemento),
      bairro: texto(data.bairro),
      cidade: texto(data.localidade),
      uf: texto(data.uf).toUpperCase(),
      regiao: textoOpcional(data.regiao),
      ibge: textoOpcional(data.ibge),
    };
    const coordenadas = await this.geocodificar(endereco);
    return { ...endereco, ...coordenadas };
  }

  async geocodificar(endereco: EnderecoGeocodificavel): Promise<{
    latitude: number | null;
    longitude: number | null;
    precisao: string | null;
  }> {
    const apiKey = process.env.GOOGLE_MAPS_SERVER_API_KEY?.trim();
    if (!apiKey) {
      return { latitude: null, longitude: null, precisao: null };
    }

    const partes = [
      endereco.logradouro,
      endereco.numero,
      endereco.bairro,
      endereco.cidade,
      endereco.uf,
      endereco.cep,
      'Brasil',
    ].filter((item): item is string => Boolean(item?.trim()));
    if (partes.length < 3) {
      return { latitude: null, longitude: null, precisao: null };
    }

    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('address', partes.join(', '));
    url.searchParams.set('region', 'br');
    url.searchParams.set('language', 'pt-BR');
    url.searchParams.set('key', apiKey);
    const response = await fetch(url, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(8_000),
    }).catch(() => null);
    if (response === null || !response.ok) {
      return { latitude: null, longitude: null, precisao: null };
    }

    const data = (await response.json()) as {
      status?: string;
      results?: Array<{
        geometry?: {
          location?: { lat?: number; lng?: number };
          location_type?: string;
        };
      }>;
    };
    const geometry = data.status === 'OK' ? data.results?.[0]?.geometry : null;
    const latitude = geometry?.location?.lat;
    const longitude = geometry?.location?.lng;
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return { latitude: null, longitude: null, precisao: null };
    }

    return {
      latitude: Number(latitude),
      longitude: Number(longitude),
      precisao: geometry?.location_type ?? null,
    };
  }
}

function somenteCep(valor: string): string {
  const cep = valor.replace(/\D/g, '');
  if (!/^\d{8}$/.test(cep)) {
    throw new BadRequestException({
      code: 'CEP_INVALIDO',
      message: 'Informe um CEP com 8 números.',
    });
  }
  return cep;
}

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor.trim() : '';
}

function textoOpcional(valor: unknown): string | null {
  const resultado = texto(valor);
  return resultado.length === 0 ? null : resultado;
}
