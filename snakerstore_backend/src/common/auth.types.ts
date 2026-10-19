import type { Request } from 'express';

export type Role = 'CLIENTE' | 'ADMINISTRADOR';

export interface UserProfile {
  uid: string;
  email: string | null;
  name: string | null;
  role: Role;
}

export interface AuthenticatedRequest extends Request {
  user: UserProfile;
}
