import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
} from '@nestjs/common';

interface SafeHttpResponse {
  status(code: number): this;
  json(body: { statusCode: number; message: string }): void;
}

const publicErrors: Readonly<Record<string, string>> = {
  HORARIO_OCUPADO:
    'Este horário já tem um atendimento agendado. Escolha outro horário.',
  HORARIO_INDISPONIVEL:
    'Este horário não está mais disponível. Atualize a disponibilidade.',
  TRANSICAO_INVALIDA:
    'Esta solicitação já foi atualizada. Recarregue para conferir o estado atual.',
  OFERTA_INDISPONIVEL:
    'Este serviço não está mais disponível. Atualize o perfil do profissional.',
  OFERTA_INVALIDA:
    'Não foi possível atualizar esta oferta. Recarregue os serviços.',
  DISPONIBILIDADE_NAO_CADASTRADA:
    'O profissional ainda não cadastrou disponibilidade para receber solicitações.',
  DATA_INVALIDA: 'Informe uma data válida para o atendimento.',
  HORARIO_INVALIDO: 'Informe o horário no formato HH:MM.',
  INTERVALO_INVALIDO:
    'O horário inicial deve ser menor que o horário final.',
  DISPONIBILIDADE_INVALIDA:
    'Confira os horários cadastrados e tente novamente.',
  DISPONIBILIDADE_SOBREPOSTA:
    'Existem horários sobrepostos no mesmo dia. Ajuste antes de salvar.',
  ENDERECO_INVALIDO: 'Selecione um endereço cadastrado válido.',
  CATEGORIA_INVALIDA: 'Selecione uma categoria ativa.',
  CAMPO_INVALIDO: 'Confira os campos preenchidos e tente novamente.',
  EMAIL_INVALIDO: 'Informe um e-mail valido.',
  TELEFONE_INVALIDO: 'Informe um telefone valido com DDD.',
  CONTA_NAO_CRIADA:
    'Nao foi possivel criar ou atualizar a conta com estes dados.',
  SENHA_ATUAL_INVALIDA: 'Senha atual invalida.',
  SENHA_INVALIDA:
    'Use uma senha com pelo menos 8 caracteres, maiuscula, minuscula, numero e caractere especial.',
  CHAT_INDISPONIVEL: 'A conversa nao esta disponivel para este atendimento.',
  MENSAGEM_INVALIDA: 'Digite uma mensagem entre 1 e 1000 caracteres.',
  DENUNCIADO_INVALIDO: 'Nao foi possivel identificar quem sera denunciado.',
  AUTO_DENUNCIA_INVALIDA: 'Nao e possivel denunciar a propria conta.',
  AVALIACAO_JA_REGISTRADA: 'Você já enviou uma avaliação deste atendimento.',
  DOCUMENTO_OBRIGATORIO: 'Selecione um arquivo para enviar.',
  TIPO_ARQUIVO_INVALIDO: 'Envie um arquivo PDF, JPEG ou PNG.',
  NOME_ARQUIVO_INVALIDO:
    'O nome do arquivo precisa combinar com o tipo selecionado.',
  ARQUIVO_INVALIDO:
    'O arquivo está vazio, corrompido ou ultrapassa o limite de 5 MB.',
  ASSINATURA_ARQUIVO_INVALIDA:
    'O conteúdo do arquivo não corresponde ao tipo informado.',
  AMEACA_DOCUMENTO_DETECTADA:
    'O arquivo foi bloqueado pela verificação de segurança.',
  CEP_INVALIDO: 'Informe um CEP com 8 numeros.',
  CEP_NAO_ENCONTRADO: 'CEP nao encontrado.',
  SERVICO_CEP_INDISPONIVEL:
    'A consulta de CEP esta indisponivel. Tente novamente.',
  UF_INVALIDA: 'Informe uma UF valida.',
  RAIO_ATENDIMENTO_INVALIDO:
    'Escolha um raio de atendimento entre 1 e 200 km.',
  COORDENADA_INVALIDA: 'Nao foi possivel identificar esta localizacao.',
  VARREDURA_DOCUMENTO_OBRIGATORIA:
    'A verificação de segurança de documentos não está disponível agora.',
};

@Catch()
export class SafeExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<SafeHttpResponse>();
    const requestedStatus =
      exception instanceof HttpException ? exception.getStatus() : 500;
    const statusCode =
      requestedStatus >= 400 && requestedStatus <= 599 ? requestedStatus : 500;
    const errorType =
      exception instanceof HttpException
        ? 'HttpException'
        : exception instanceof Error
          ? 'Error'
          : 'UnknownException';

    // Deliberately omit exception messages, stacks, URLs, headers, and bodies.
    console.error(
      JSON.stringify({
        level: 'error',
        event: 'http_exception',
        statusCode,
        errorType,
      }),
    );

    const body =
      exception instanceof HttpException ? exception.getResponse() : null;
    const code =
      typeof body === 'object' && body !== null && 'code' in body
        ? body.code
        : null;
    const publicMessage =
      typeof code === 'string' ? publicErrors[code] : undefined;
    response.status(statusCode).json({
      statusCode,
      message:
        publicMessage ??
        (statusCode >= 500
          ? 'Internal server error'
          : 'Request could not be processed'),
    });
  }
}
