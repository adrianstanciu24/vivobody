# Vivobody website

Static Astro marketing site for Vivobody. It has no backend, analytics,
cookies, or runtime JavaScript.

## Local development

```bash
npm install
npm run dev
```

Create the production output with:

```bash
npm run build
```

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
