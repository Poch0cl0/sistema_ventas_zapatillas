import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Matches, Max, Min } from 'class-validator';

export const DOCUMENT_ID = /^[A-Za-z0-9_-]{1,128}$/;

export class PaginationDto {
  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;

  @ApiPropertyOptional({
    description: 'ID devuelto como nextCursor en la página anterior.',
  })
  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{1,160}$/)
  after?: string;
}

export class DocumentIdDto {
  @ApiProperty({ type: String, description: 'ID del recurso.' })
  @Matches(DOCUMENT_ID)
  id: string;
}
