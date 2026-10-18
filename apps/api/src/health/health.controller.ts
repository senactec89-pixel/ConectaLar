import { Controller, Get, Res } from '@nestjs/common';
import { HealthService } from './health.service.js';

@Controller('health')
export class HealthController {
  constructor(private readonly health: HealthService) {}

  @Get()
  getHealth(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Get('live')
  getLiveness(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Get('ready')
  async getReadiness(
    @Res({ passthrough: true }) response: { status(code: number): unknown },
  ): Promise<{ status: 'ready' | 'not_ready' }> {
    const ready = await this.health.isReady();
    response.status(ready ? 200 : 503);
    return { status: ready ? 'ready' : 'not_ready' };
  }
}
