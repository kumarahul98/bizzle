import type { Response } from 'express';

/**
 * Send a successful JSON response in the canonical shape (D-06):
 * `{ statusCode, body: { data } }`. The HTTP status mirrors `statusCode`.
 */
export function sendSuccess<T>(res: Response, statusCode: number, data: T): void {
  res.status(statusCode).json({ statusCode, body: { data } });
}

/**
 * Send an error JSON response in the canonical shape (D-06):
 * `{ statusCode, body: { error } }`. `error` is a plain message — never a
 * stack trace or token (D-06).
 */
export function sendError(res: Response, statusCode: number, error: string): void {
  res.status(statusCode).json({ statusCode, body: { error } });
}
