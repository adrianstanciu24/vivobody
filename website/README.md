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

## Formatting

Prettier with `prettier-plugin-astro` keeps the markup, styles, and inline
scripts consistent. Format all files or check without modifying:

```bash
npm run format
npm run format:check
```

## Linting

ESLint enforces the repository naming standard — camelCase for variables,
functions, and parameters; PascalCase for classes and type-like
declarations — across standalone scripts and the frontmatter and inline
`<script>` blocks of `.astro` components:

```bash
npm run lint
```

The rule set lives in `eslint.config.mjs` and mirrors the Swift conventions
documented in `../engineering/quality.md`.

## Dead code

[knip](https://knip.dev) detects unused files, exports, and dependencies
across the site sources. It auto-detects the Astro project (entry
`astro.config.mjs`, routes in `src/pages/`) and respects `.gitignore` to
exclude generated output. The checked-in `knip.json` pins the schema:

```bash
npm run lint:dead
```

The same check runs in `Scripts/check.sh` and on every commit through the
`website-knip` pre-commit hook.

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

| Setting                | Value           |
| ---------------------- | --------------- |
| Production branch      | `main`          |
| Root directory         | `website`       |
| Build command          | `npm run build` |
| Build output directory | `dist`          |

Set the build watch include path to `website/*` so iOS-only commits do not
trigger website deployments.

The production site URL is configured in `astro.config.mjs`. Astro uses it to
generate absolute canonical and social-preview URLs for every page.

The current App Store call to action deliberately says “Soon” until a live
product-page URL exists.
