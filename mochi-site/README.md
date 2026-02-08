# mochi landing page

Simple static landing page for mochi. No build step or package install is required.

## Prerequisites
- Python 3 (for local static file serving)
- Optional: Vercel CLI (`npm i -g vercel`) for deployment

## Local preview
```bash
cd mochi-site
python3 -m http.server 8080
```

Open `http://localhost:8080`.

## Add your hero video
1. Place your file at `assets/main_demo_web.mp4` (or update the `<source>` path in `index.html`).
2. Refresh the page.

Note:
- Vercel file uploads are limited to 100MB per file.
- This project ignores `assets/main_demo.mp4` during deploy via `.vercelignore`.

## Deploy to Vercel (preview)
```bash
cd mochi-site
vercel deploy . -y
```

## Deploy to Vercel (production)
```bash
cd mochi-site
vercel deploy . --prod -y
```
