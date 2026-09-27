# Vivobody app preview

`vivobody-app-preview.mp4` is the 20-second portrait edit. `poster.jpg` is the suggested poster at 1.5 seconds. The contact sheet shows representative exported frames.

All app footage was recorded on 26 September 2026 from the running iPhone 18 Pro simulator with the existing two-year `-years` archive and the screenshot campaign demo data. The five scenes are Today, set logging, Bench Press anatomy, Training Shape, and Me. The temporary recording workout was discarded afterwards; the archive remains at 417 workouts and 6,231 sets.

Body/anatomy motion and insight/progress clips play at 1.25x; logging plays at 1x. The edit trims idle time and uses direct cuts. Titles occupy their own band. Only the OS status-bar area is cropped; no app values or interface pixels are repainted. Training Shape begins with Exercise mix fully visible.

Audio is an original synthesized electronic pulse with edit accents, not a recording of native app sounds. The visual story also works muted.

Export: 886 x 1920, 30 fps, 20 seconds, H.264 High Level 4.0 at 10 Mbps, Rec.709, stereo AAC. Every frame and the full audio track decoded without errors. App Store upload/review has not been attempted.

Production files: `.verify/app-store-video/` in this repository. Rebuild with `python3 .verify/app-store-video/edit/render.py`; edit `SCENES` there to change headlines, trims, or timing. Original takes remain in `raw/`, with capture checksums in `capture-manifest.json` here.

Apple specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
