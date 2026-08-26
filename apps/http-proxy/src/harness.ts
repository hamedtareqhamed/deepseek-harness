/**
 * HarnessClient singleton — owns the dsh-jsonrpc-agent subprocess and
 * fans all notifications into the SessionStore.
 */

import { HarnessClient } from '@deepseek-ai/dsh-sdk-client'
import type { SessionStore } from './sessions.ts'

let client: HarnessClient | undefined
let started = false

/** Read required env var or throw. */
function requireEnv(key: string): string {
  const val = process.env[key]
  if (!val) throw new Error(`Missing required environment variable: ${key}`)
  return val
}

/**
 * Initialize the HarnessClient singleton. Call once at server startup.
 * The client spawns dsh-jsonrpc-agent as a subprocess and routes all
 * session notifications into the shared SessionStore.
 */
export function initHarness(sessionStore: SessionStore): void {

  const cordisConfig = requireEnv('DSH_CORDIS_CONFIG')
  const apiKey = requireEnv('DEEPSEEK_API_KEY')
  const agentCwd = process.env['DSH_CWD'] ?? process.cwd()

  // Repository root (where tsx, packages, and examples are resolvable)
  const repoRoot = new URL('../../..', import.meta.url).pathname

  // DSH_BIN_PATH: absolute path to dsh-jsonrpc-demo/src/bin.ts (or built lib/bin.js)
  const binPath = process.env['DSH_BIN_PATH']
    ?? `${repoRoot}/packages/examples/jsonrpc-demo/src/bin.ts`

  const tsxImport = import.meta.resolve('tsx/esm')

  client = new HarnessClient({
    command: process.execPath,
    args: ['--import', tsxImport, binPath, cordisConfig],
    cwd: repoRoot,
    env: {
      ...process.env,
      DEEPSEEK_API_KEY: apiKey,
      DSH_CORDIS_CONFIG: cordisConfig,
      DSH_CWD: agentCwd,
    },
    // Long-running turns are normal — no request timeout on prompts
    requestTimeoutMs: undefined,
    shutdownTimeoutMs: 5_000,
  })

  client.start()

  // Subscribe to ALL notifications and route them to the session store
  const sub = client.subscribe()
  void (async () => {
    for await (const notification of sub) {
      const params = notification.params
      // Determine which session this notification belongs to
      const sessionId = resolveSessionId(notification.method, params)
      if (sessionId) {
        sessionStore.append(sessionId, notification.method, params)
      }
    }
  })()

  console.log('[harness] dsh-jsonrpc-agent subprocess started')
}

/**
 * Extract the session id from a notification's params.
 * Different notification types carry the session id in different fields.
 */
function resolveSessionId(
  method: string,
  params: Record<string, unknown>,
): string | undefined {
  if (method === 'session.event' || method === 'session.status') {
    return typeof params.sessionId === 'string' ? params.sessionId : undefined
  }
  if (method === 'subagent.started' || method === 'subagent.finished') {
    // Route to parent session so the iOS app sees child activity
    return typeof params.parentSessionId === 'string' ? params.parentSessionId : undefined
  }
  return undefined
}

/** Send a prompt to a session. Creates the session in dsh if it doesn't exist yet. */
export async function sendPrompt(
  sessionId: string,
  text: string,
): Promise<string> {
  if (!client) throw new Error('Harness not initialized')
  const messageId = await client.prompt(sessionId, [{ type: 'text', text }])
  return messageId
}

/** Whether the underlying subprocess is alive. */
export function isHarnessAlive(): boolean {
  return client !== undefined && started
}

/** Initialize the harness once startup is confirmed. */
export function markStarted(): void {
  started = true
}
