# Traevy Landing Page

Marketing landing page for Traevy — a commute tracker that shows you exactly what traffic costs you.

Built with **Vite + React 18**. Static output, no server required.

## Getting started

```bash
npm install
npm run dev      # dev server at http://localhost:5173
npm run build    # production build → dist/
npm run preview  # preview the production build locally
```

## Deployment

`npm run build` outputs a static `dist/` directory deployable to any static host:

- **AWS**: S3 bucket + CloudFront distribution
- **Netlify**: drag-and-drop `dist/` or connect the repo
- **Vercel**: `vite build` is auto-detected

## Known follow-ups

- The **"Install for Android"** button links to `#` pending a real Google Play Store URL.
- The **iOS waitlist form** is client-only — form submissions are not wired to a backend yet.
