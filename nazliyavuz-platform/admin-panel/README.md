## NazlıYavuz Admin Paneli

Next.js 16 tabanlı yönetim paneli; rezarvasyon, finans, bildirim ve deney (A/B testing) ekranları içerir.

### 1. Gereksinimler

- Node.js 20+
- npm 10+ (veya `pnpm`/`yarn`)
- Ayakta çalışan backend API (`nazliyavuz-platform/backend`)

### 2. Ortam Değişkenleri

`.env.local` dosyası oluşturun:

```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000/api/v1
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3100
PLAYWRIGHT_API_BASE_URL=http://localhost:8000/api/v1
```

> Backend JWT endpoint’leri için `NEXT_PUBLIC_API_BASE_URL` zorunlu. Test senaryoları Playwright config’ine ait diğer değişkenleri kullanır.

### 3. Kurulum ve Çalıştırma

```bash
npm install --legacy-peer-deps   # proje peer bağımlılıkları için
npm run dev                      # http://localhost:3000
```

Prod build:

```bash
npm run build
npm run start
```

### 4. Kalite Kontrolleri

- Lint: `npm run lint`
- Playwright E2E: `npm run test:e2e`
- Playwright UI mode: `npm run test:e2e:ui`

Playwright testleri otomatik olarak Next.js dev sunucusunu 3100 portunda ayağa kaldırır ve backend çağrılarını `PLAYWRIGHT_API_BASE_URL` üzerinden stub’lar.

### 5. Önemli Scriptler

- `npm run dev` : Local geliştirme
- `npm run build && npm run start` : Production
- `npm run lint` : ESLint
- `npm run test:e2e` : Headless e2e
- `npm run test:e2e:ui` : Playwright UI runner

### 6. Geliştirme İpuçları

- API çağrıları `src/lib/api/*` içinde toplandı (axios + React Query).
- Bildirim / finans paneli bileşenleri `src/components/admin` klasöründe.
- Oturum yönetimi `src/store/auth-store.ts` (Zustand + JWT).
- Test doubles Playwright route interception ile `tests/e2e/*.spec.ts` dosyalarında.
