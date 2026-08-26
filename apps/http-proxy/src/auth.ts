/**
 * Bearer-token auth middleware.
 * Every request must carry: Authorization: Bearer <DSH_PROXY_TOKEN>
 */

import type { Request, Response, NextFunction } from 'express'

const token = process.env['DSH_PROXY_TOKEN']

if (!token) {
  console.error('[auth] FATAL: DSH_PROXY_TOKEN is not set. Set it in .env.')
  process.exit(1)
}

export function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const header = req.headers.authorization
  if (!header || !header.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing Authorization header' })
    return
  }
  const provided = header.slice(7)
  if (provided !== token) {
    res.status(403).json({ error: 'Invalid token' })
    return
  }
  next()
}
