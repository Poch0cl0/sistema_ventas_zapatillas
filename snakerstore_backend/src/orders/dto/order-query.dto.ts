import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, Matches } from 'class-validator';
import { BadRequestException } from '@nestjs/common';
import { PaginationDto } from '../../common/dto/pagination.dto.js';

export class OrderQueryDto extends PaginationDto {
  @ApiPropertyOptional({
    example: '2026-10-01',
    description: 'Fecha inicial inclusiva, America/Lima.',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  from?: string;
  @ApiPropertyOptional({
    example: '2026-10-31',
    description: 'Fecha final inclusiva, America/Lima.',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  to?: string;
}

export function dateBounds(input: { from?: string; to?: string }) {
  function parse(value: string | undefined) {
    if (value === undefined) return undefined;
    const ms = Date.parse(`${value}T00:00:00-05:00`);
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      !Number.isFinite(ms) ||
      new Date(ms - 5 * 3600000).toISOString().slice(0, 10) !== value
    )
      throw new BadRequestException('Fecha inválida. Usa AAAA-MM-DD.');
    return ms;
  }
  const from = parse(input.from),
    end = parse(input.to);
  if (from !== undefined && end !== undefined && from > end)
    throw new BadRequestException(
      'La fecha inicial no puede ser posterior a la final.',
    );
  return { from, to: end === undefined ? undefined : end + 86400000 };
}
