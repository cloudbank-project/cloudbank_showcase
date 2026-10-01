---
title: Contributing
sidebar_position: 2
---

# Contributing

## Adding or updating a tutorial

1. Edit the tutorial's markdown guides and notebooks in their source folder
   (e.g. `gpu_computing_oceanography/`).
2. Rebuild the site and check the rendered output:

   ```bash
   cd website
   npm run build
   ```

3. If you add a new guide file, extend the `files` list for that tutorial in
   `website/scripts/sync.mjs`, then re-run `npm run sync`.

The generated pages under `website/docs/tutorials/` are **not** committed —
they are produced by `npm run sync`. Never edit them by hand.

## Adding a new tutorial top-level

If you add a top-level tutorial directory to the repository (e.g.
`climate_analysis/`), also:
- add an entry in `website/scripts/sync.mjs` (`TUTORIALS`),
- add a category to `website/sidebars.js`,
- add it to the table in `website/docs/intro.md` and the repository
  `README.md`.
