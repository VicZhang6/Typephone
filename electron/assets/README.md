# Application and menu bar icons

## Application icon

`app-icon.png` is the 1024×1024 dark Typephone source export. `app-icon.icns` is generated from the standard macOS icon sizes and is used by Electron Builder. Electron also sets `app-icon.png` as the Dock icon explicitly so `npm run dev` does not show the default Electron icon.

The same artwork is exported into `Resources/Assets.xcassets/AppIcon.appiconset` for the native Swift helper so Finder, Dock, and macOS privacy settings show a consistent identity.

## Menu bar icon

The menu bar asset must be a macOS Template Image:

- monochrome black artwork on a transparent background;
- no baked-in color, background tile, gradient, glow, or drop shadow;
- a simple silhouette that remains legible at 16×16 points;
- `trayTemplate.png` at 16×16 pixels;
- `trayTemplate@2x.png` at 32×32 pixels;
- optional `trayTemplate@3x.png` at 48×48 pixels;
- filenames retain the `Template` suffix;
- Electron calls `setTemplateImage(true)` so macOS supplies light, dark, disabled, and pressed-state coloring.

Prefer a compact 1.5–2 px stroke at 1× scale, generous internal spacing, and an optical artwork height of roughly 14–16 px. Avoid copying the full-color rounded application icon into the menu bar.

The current template artwork is derived from the supplied `statusbar.png` export.
