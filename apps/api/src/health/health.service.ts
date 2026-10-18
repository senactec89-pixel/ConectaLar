import { Injectable, Optional } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { isAuthRuntimeConfigured } from '../config/runtime.js';

const probeTimeoutMs = 2_000;

@Injectable()
export class HealthService {
  private probe: Promise<boolean> | undefined;

  constructor(
    @Optional() @InjectDataSource() private readonly database?: DataSource,
  ) {}

  async isReady(): Promise<boolean> {
    if (!isAuthRuntimeConfigured() || !this.database?.isInitialized) {
      return false;
    }

    // Share an outstanding query so repeated probes cannot fill the pool when
    // MySQL stops responding. The HTTP probe still has a bounded response time.
    if (this.probe === undefined) {
      this.probe = this.database.query('SELECT 1').then(
        () => true,
        () => false,
      ).finally(() => {
        this.probe = undefined;
      });
    }

    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([
        this.probe,
        new Promise<boolean>((resolve) => {
          timer = setTimeout(() => resolve(false), probeTimeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  }
}
