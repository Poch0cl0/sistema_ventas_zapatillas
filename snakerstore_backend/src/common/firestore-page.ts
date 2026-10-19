import { FieldPath } from 'firebase-admin/firestore';
import type { DocumentData, Query } from 'firebase-admin/firestore';
import type { PaginationDto } from './dto/pagination.dto.js';

export async function firestorePage(query: Query, pagination: PaginationDto) {
  let ordered = query.orderBy(FieldPath.documentId());
  if (pagination.after) ordered = ordered.startAfter(pagination.after);
  const snapshot = await ordered.limit(pagination.limit + 1).get();
  const docs = snapshot.docs.slice(0, pagination.limit);
  return {
    docs,
    nextCursor:
      snapshot.docs.length > pagination.limit ? docs.at(-1)!.id : null,
  };
}

export function publicProduct(id: string, data: DocumentData) {
  return {
    id,
    name: data.name,
    description: data.description,
    priceCents: data.priceCents,
    category: data.category,
    brand: data.brand,
    active: data.active,
    images: Array.isArray(data.images)
      ? data.images.map((image: Record<string, unknown>) => ({
          secure_url: image.secure_url,
        }))
      : [],
  };
}
