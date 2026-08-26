/**
 * Main Express server — all HTTP and SSE endpoints for the iOS client.
 *
 * Endpoints:
 *   GET  /health                           — liveness check
 *   GET  /api/sessions                     — list all sessions
 *   POST /api/sessions                     — create/retrieve a session
 *   POST /api/sessions/:id/prompt          — send a user message
 *   GET  /api/sessions/:id/stream          — SSE event stream
 *   GET  /api/sessions/:id/status          — current status + seq
 *   GET  /api/sessions/:id/events?from=N   — missed events after reconnect
 *   POST /api/sessions/:id/approve         — answer a pending approval
 */

import 'dotenv/config'
import express from 'express'
import { randomUUID } from 'node:crypto'
import { SessionStore } from './sessions.ts'
import type { SseListener, ProxyEvent } from './sessions.ts'
import { initHarness, sendPrompt } from './harness.ts'
import { authMiddleware } from './auth.ts'

const app = express()
app.use(express.json())
app.use(authMiddleware)

const store = new SessionStore()

// ── Health ────────────────────────────────────────────────────────────────────

app.get('/health', (_req, res) => {
  res.json({ ok: true, uptime: process.uptime() })
})

// ── Sessions list ─────────────────────────────────────────────────────────────

app.get('/api/sessions', (_req, res) => {
  const sessions = store.getAll().map(s => ({
    id: s.id,
    status: s.status,
    createdAt: s.createdAt,
    eventCount: s.events.length,
  }))
  res.json({ sessions })
})

// ── Create / retrieve session ─────────────────────────────────────────────────

app.post('/api/sessions', (req, res) => {
  const id: string = (req.body as { sessionId?: string }).sessionId
    ?? `session-${randomUUID().replaceAll('-', '')}`
  store.getOrCreate(id)
  res.json({ sessionId: id })
})

// ── Send prompt ───────────────────────────────────────────────────────────────

app.post('/api/sessions/:id/prompt', async (req, res) => {
  const { id } = req.params
  const body = req.body as { text?: string }
  if (!body.text || typeof body.text !== 'string' || body.text.trim() === '') {
    res.status(400).json({ error: 'body.text is required' })
    return
  }
  try {
    store.getOrCreate(id)
    const messageId = await sendPrompt(id, body.text)
    res.json({ messageId })
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error(`[prompt] ${id}: ${msg}`)
    res.status(500).json({ error: msg })
  }
})

// ── SSE stream ────────────────────────────────────────────────────────────────

app.get('/api/sessions/:id/stream', (req, res) => {
  const { id } = req.params
  const fromSeq = Number(req.query['from'] ?? -1)

  // SSE headers — disable all buffering for real-time delivery
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache, no-transform')
  res.setHeader('Connection', 'keep-alive')
  res.setHeader('X-Accel-Buffering', 'no')  // nginx: disable proxy buffering
  res.flushHeaders()

  const state = store.getOrCreate(id)

  /**
   * Write one ProxyEvent as an SSE data frame.
   * Returns false when the response is no longer writable.
   */
  const write = (event: ProxyEvent): boolean => {
    if (res.writableEnded) return false
    const payload = JSON.stringify({ method: event.method, params: event.params })
    res.write(`id: ${event.seq}\ndata: ${payload}\n\n`)
    return true
  }

  // Replay missed events (from > -1 means reconnect with known seq)
  if (fromSeq >= 0) {
    for (const event of state.events) {
      if (event.seq > fromSeq) {
        if (!write(event)) return
      }
    }
  }

  // If already idle and no fromSeq, send a synthetic status event so the
  // iOS client knows the agent isn't running without waiting
  if (fromSeq < 0 && state.status === 'idle') {
    const synthetic: ProxyEvent = {
      seq: -1,
      method: 'session.status',
      params: { sessionId: id, status: 'idle' },
    }
    write(synthetic)
  }

  // Register as a live listener for future events
  const listener: SseListener = { push: write }
  state.listeners.add(listener)

  // Clean up on disconnect
  req.on('close', () => {
    state.listeners.delete(listener)
  })
})

// ── Status (instant, no streaming) ───────────────────────────────────────────

app.get('/api/sessions/:id/status', (req, res) => {
  const { id } = req.params
  const state = store.get(id)
  if (!state) {
    res.status(404).json({ error: 'session not found' })
    return
  }
  res.json({ status: state.status, seq: state.events.length - 1 })
})

// ── Missed events after reconnect ─────────────────────────────────────────────

app.get('/api/sessions/:id/events', (req, res) => {
  const { id } = req.params
  const state = store.get(id)
  if (!state) {
    res.status(404).json({ error: 'session not found' })
    return
  }
  const from = Number(req.query['from'] ?? 0)
  const events = state.events
    .filter(e => e.seq >= from)
    .map(e => ({ seq: e.seq, method: e.method, params: e.params }))
  res.json({ events, status: state.status })
})

// ── Approval decision ─────────────────────────────────────────────────────────

app.post('/api/sessions/:id/approve', (req, res) => {
  const { id } = req.params
  const body = req.body as { decision?: string }
  const decision = body.decision

  if (decision !== 'allow' && decision !== 'reject') {
    res.status(400).json({ error: 'decision must be "allow" or "reject"' })
    return
  }

  const state = store.get(id)
  if (!state) {
    res.status(404).json({ error: 'session not found' })
    return
  }

  const pending = state.pendingApproval
  if (!pending) {
    res.status(409).json({ error: 'no pending approval for this session' })
    return
  }

  if (pending.timer !== undefined) clearTimeout(pending.timer)
  state.pendingApproval = undefined
  pending.resolve(decision)

  res.json({ ok: true, decision })
})

// ── Boot ──────────────────────────────────────────────────────────────────────

const port = Number(process.env['DSH_PROXY_PORT'] ?? 3090)

initHarness(store)

app.listen(port, '0.0.0.0', () => {
  console.log(`[proxy] listening on http://0.0.0.0:${port}`)
  console.log(`[proxy] Tailscale: http://<your-100.x.x.x>:${port}`)
  console.log(`[proxy] health: curl -H "Authorization: Bearer $DSH_PROXY_TOKEN" http://localhost:${port}/health`)
})
