# dsh-http-proxy

HTTP + SSE bridge بين الـ iOS app وجهاز البيت الذي يُشغّل DeepSeek Harness.

```
iPhone (SwiftUI)
  │  HTTP + SSE  via Tailscale
  ▼
dsh-http-proxy:3090  ← هذا المشروع
  │  JSON-RPC stdio
  ▼
dsh-jsonrpc-agent
  │
  ▼
DeepSeek API
```

## الإعداد

```bash
# 1. انسخ env template
cp .env.example .env
# 2. عبّئ المتغيرات في .env
#    - DEEPSEEK_API_KEY
#    - DSH_PROXY_TOKEN  (سر عشوائي طويل)
#    - DSH_BIN_PATH     (مسار bin.ts)
#    - DSH_CORDIS_CONFIG (مسار cordis.yml)
#    - DSH_CWD          (مجلد العمل)

# 3. ثبّت dependencies (من داخل deepseek-harness workspace أو standalone)
npm install

# 4. شغّل
npm start
```

## الاختبار بالـ curl

```bash
TOKEN=your_token_here
BASE=http://localhost:3090

# Health check
curl -H "Authorization: Bearer $TOKEN" $BASE/health

# إنشاء session
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{}' $BASE/api/sessions

# إرسال prompt (استبدل SESSION_ID)
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"text": "اكتب hello world بـ Python"}' \
     $BASE/api/sessions/SESSION_ID/prompt

# Stream الأحداث (SSE)
curl -N -H "Authorization: Bearer $TOKEN" \
     $BASE/api/sessions/SESSION_ID/stream

# حالة الجلسة
curl -H "Authorization: Bearer $TOKEN" \
     $BASE/api/sessions/SESSION_ID/status
```

## الـ API

| Method | Path | الوصف |
|---|---|---|
| GET | `/health` | liveness check |
| GET | `/api/sessions` | قائمة الجلسات |
| POST | `/api/sessions` | إنشاء/استرجاع session |
| POST | `/api/sessions/:id/prompt` | إرسال رسالة |
| GET | `/api/sessions/:id/stream` | SSE stream (param: `?from=N`) |
| GET | `/api/sessions/:id/status` | حالة فورية |
| GET | `/api/sessions/:id/events?from=N` | أحداث مفقودة |
| POST | `/api/sessions/:id/approve` | قرار approval |

## الأحداث (SSE)

كل event له الشكل:
```json
{ "method": "session.event", "params": { "sessionId": "...", "event": { "type": "...", "data": {...} } } }
```

أنواع `event.type` المهمة للـ iOS:
- `assistant/chunk` — نص streaming (أضف كل chunk للـ UI فوراً)
- `assistant/message` — الرسالة الكاملة
- `tool/call` — الـ agent يستدعي tool
- `tool/result` — نتيجة الـ tool
- `approval/asked` — يطلب إذناً (اعرض Allow/Reject)
- `turn/end` — نهاية الـ turn

`session.status` notification:
```json
{ "method": "session.status", "params": { "sessionId": "...", "status": "idle" } }
```

## Reconnect

عند عودة الـ app من background:
```
GET /api/sessions/:id/status           ← اعرف آخر seq
GET /api/sessions/:id/stream?from=N    ← استقبل ما فاتك
```
