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

# Design Context

## Register
brand, product — both equally important.

## Key Files
- `PRODUCT.md` — strategic: users, purpose, brand personality, design principles
- `DESIGN.md` — visual: color palette, typography, elevation, components, do's/don'ts
- `.impeccable/design.json` — machine-readable token sidecar
- `client/app/globals.css` — all CSS custom properties and Tailwind v4 theme tokens
- `client/components/ui/` — 65+ shadcn/ui-style components built on Radix primitives

## Brand
Yamada — women's fashion e-commerce. Elegant, warm, confident. Curated feminine aesthetic.

## Core Rules
- One type family (Poppins) for everything
- Rosewood (#c97a8c) is the sole primary accent, used sparingly (~10% of any screen)
- Mostly flat — tonal layering over shadows
- No #000 text or #fff backgrounds — use charcoal (#2e2e2e) and off-white (#faf7f9)
- No gradient text, glassmorphism, side-stripe borders, or em dashes
- WCAG 2.1 AAA where possible
