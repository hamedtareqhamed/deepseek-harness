# DshMobile — iOS Client for DeepSeek Harness

تطبيق iOS أصيل مبني بـ **SwiftUI** يتصل بجهازك المشغّل لـ **DeepSeek Harness** عبر شبكة **Tailscale**.

---

## الميزات

- ⚡ **Real-time SSE Streaming**: عرض ردود النموذج مباشرةً كلمة بكلمة (`assistant/chunk`).
- 🛠️ **Tool Execution Cards**: بطاقات تفاعلية قابلة للطي تُظهر اسم الـ Tool والمعاملات والنتائج وحالة التنفيذ.
- 🛡️ **Interactive Approvals**: واجهة منبثقة فورية لقبول أو رفض العمليات الحساسة (`approval/asked`).
- 🔄 **Auto-reconnection**: استرجاع الأحداث الفائتة عبر تسلسل `seq` بعد انقطاع الاتصال أو خروج التطبيق من الخلفية.
- ⚙️ **Configurable Endpoint**: إدخال عنوان IP الخاص بجهازك عبر Tailscale مع الـ Bearer Token.

---

## بنية المشروع

```
dsh-ios-client/
├── Package.swift
└── DshMobile/
    └── Sources/
        ├── App/
        │   └── DshMobileApp.swift       # نقطة انطلاق التطبيق (@main)
        ├── Models/
        │   └── Models.swift             # نماذج البيانات لبروتوكول JSON-RPC و SSE
        ├── Network/
        │   ├── ProxyClient.swift        # كائن Actor لإرسال الطلبات وفتح قناة SSE
        │   └── SSEParser.swift          # معالج قراءة خطوط SSE عبر AsyncSequence
        ├── ViewModels/
        │   └── AppState.swift           # إدارة الحالة العامة للتطبيق والرسائل
        └── Views/
            ├── SessionListView.swift    # قائمة الجلسات مع إمكانية إنشاء جلسة جديدة
            ├── ChatView.swift           # شاشة المحادثة الرئيسية والتمرير التلقائي
            ├── MessageRow.swift         # عرض فقاعات الرسائل ومؤشرات التفكير
            ├── ToolCallRow.swift        # بطاقة تنفيذ الأدوات
            ├── InputBar.swift           # حقل إدخال الرسائل
            ├── ApprovalSheet.swift      # نافذة الموافقة أو الرفض
            └── SettingsView.swift       # إعدادات عنوان السيرفر والرمز السري
```

---

## كيفية التشغيل على iPhone / Xcode

1. **تشغيل الـ Proxy على الجهاز الرئيسي (البيت):**
   ```bash
   cd /home/hamed/projectes/cloned/deepseek-harness/apps/http-proxy
   pnpm start
   ```

2. **فتح المشروع في Xcode:**
   - افتح مجلد `dsh-ios-client` في **Xcode** (File -> Open -> اختر المجلد).
   - أو أنشئ تطبيق iOS جديد في Xcode وأضف مجلد `DshMobile/Sources` إليه.

3. **إعداد الاتصال داخل التطبيق:**
   - تأكد من تفعيل **Tailscale** على هاتف الـ iPhone.
   - افتح إعدادات التطبيق ⚙️ وضع:
     - **Server URL**: `http://<Tailscale-IP-Of-Your-PC>:3090`
     - **Bearer Token**: الرمز المحدد في ملف `.env` (`DSH_PROXY_TOKEN`).
   - اضغط **Test Connection** ثم **Done**.
