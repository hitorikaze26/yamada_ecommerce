# Build Commands

## Client (Next.js)
- `cd client && npm run build` — TypeScript + Next.js production build
- `cd client && npm run dev` — Development server
- `cd client && npm run lint` — ESLint
- `cd client && npm start` — Production server

## Server (Flask)
- `cd server && python app.py` — Run Flask dev server

## Verify no TypeScript errors
- `npx tsc --noEmit` (from client/)

Note: Client has `ignoreBuildErrors: true` in next.config.mjs, so `npm run build` will succeed even with TS errors. Run `npx tsc --noEmit` for strict checking.
