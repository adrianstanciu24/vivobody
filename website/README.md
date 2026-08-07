# Vivobody website

Static Astro marketing site for Vivobody. It has no backend, analytics,
or cookies. A small inline script keeps the landing video's four chapters in
sync with the surrounding typography and chapter controls.

## Local development

```bash
npm install
npm run dev
```

Create the production output with:

```bash
npm run build
```

## Refreshing the simulator demo

The landing video is generated from deterministic app fixtures rather than
edited by hand. With an iPhone 17 Pro simulator booted, install a current debug
build and run the recorder from the repository root:

```bash
Scripts/verify.sh
Scripts/record-landing-demo.sh
```

The recorder uses Baguette for gestures and FFmpeg/FFprobe from Homebrew. It
captures the Start, Log, Rest, and See beats, then writes the optimized H.264
loop and poster to `website/public/video/`. Raw captures stay under the ignored
`.verify/landing-video/` directory.

## Cloudflare Pages

Connect the existing `vivobody` GitHub repository with these settings:

| Setting | Value |
|---|---|
| Production branch | `main` |
| Root directory | `website` |
| Build command | `npm run build` |
| Build output directory | `dist` |

Set the build watch include path to `website/*` so iOS-only commits do not
trigger website deployments.

After the permanent Pages or custom-domain URL is known, add a build variable
named `PUBLIC_SITE_URL` containing the origin without a trailing slash, for
example `https://vivobody.example`. This makes canonical and social-preview
URLs absolute.

The current App Store call to action deliberately says “Soon” until a live
product-page URL exists.
