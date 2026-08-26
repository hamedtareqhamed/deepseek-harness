/**
 * Session state tracked by the proxy for each active dsh session.
 * Keeps the full event log (for reconnect replay) and pending approval resolvers.
 */

export type SessionStatus = 'idle' | 'running'

export interface ProxyEvent {
  /** Sequential index within this session (0-based). */
  seq: number
  /** Raw HarnessSdkNotification JSON. */
  method: string
  params: Record<string, unknown>
}

export interface PendingApproval {
  resolve: (decision: 'allow' | 'reject') => void
  timer: ReturnType<typeof setTimeout> | undefined
}

export interface SessionState {
  id: string
  createdAt: number
  status: SessionStatus
  /** All notifications received for this session, in order. */
  events: ProxyEvent[]
  /** SSE response objects waiting for new events. */
  listeners: Set<SseListener>
  /** Pending approval request, if any. */
  pendingApproval: PendingApproval | undefined
}

export interface SseListener {
  /** Called with each new event. Returns false if the connection closed. */
  push(event: ProxyEvent): boolean
}

/**
 * In-memory store for all proxy sessions.
 * A session is created on first prompt and lives until the proxy restarts.
 */
export class SessionStore {
  private readonly sessions = new Map<string, SessionState>()

  get(id: string): SessionState | undefined {
    return this.sessions.get(id)
  }

  getAll(): SessionState[] {
    return [...this.sessions.values()]
  }

  create(id: string): SessionState {
    const state: SessionState = {
      id,
      createdAt: Date.now(),
      status: 'idle',
      events: [],
      listeners: new Set(),
      pendingApproval: undefined,
    }
    this.sessions.set(id, state)
    return state
  }

  getOrCreate(id: string): SessionState {
    return this.sessions.get(id) ?? this.create(id)
  }

  /**
   * Append a notification to the session log, fan it out to all live SSE
   * listeners, and update status if this is a session.status notification.
   */
  append(id: string, method: string, params: Record<string, unknown>): void {
    const state = this.getOrCreate(id)
    const event: ProxyEvent = { seq: state.events.length, method, params }
    state.events.push(event)

    // Update status from session.status notifications
    if (method === 'session.status' && typeof params.status === 'string') {
      state.status = params.status as SessionStatus
    }

    // Fan out to live SSE listeners; remove dead ones
    const dead: SseListener[] = []
    for (const listener of state.listeners) {
      if (!listener.push(event)) dead.push(listener)
    }
    for (const d of dead) state.listeners.delete(d)
  }
}
