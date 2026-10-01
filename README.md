# Cloudbank Showcase

Tutorials that demonstrate how to use cloud resources provided by [CloudBank](https://www.cloudbank.org/) in real-world scientific applications.

## Tutorials

| Tutorial | Domain | Cloud Provider | Resources Used |
|----------|--------|---------------|----------------|
| [Cloud Seismology Analysis](cloud_analysis_seismology/) | Seismology | AWS | EC2, S3, Docker/Jupyter |
| [GPU Computing in Oceanography](gpu_computing_oceanography/) | Oceanography | Google Cloud | GPU instance (A100), Jupyter |
| [Knowledge Graphs for Chemistry](knowledge_graphs_chemistry/) | Chemistry / Bioinformatics | AWS | S3, Neptune, EC2, ECS/Fargate |
| [Toy Data Portal for Hydrology](toy_data_portal_hydrology/) | Hydrology | Google Cloud | GKE Autopilot, JupyterHub, Cloud Storage |

### Cloud Seismology Analysis

Step-by-step guides to stand up an AWS environment for seismic noise studies and run the SCEDC NoisePy workflow against S3-hosted data. Covers EC2 + Docker + Jupyter setup, S3 access configuration, and an end-to-end ambient noise cross-correlation notebook.

### GPU Computing in Oceanography

An interactive Jupyter tutorial demonstrating GPU-accelerated, differentiable ocean modeling using Julia (Reactant.jl / Enzyme.jl) on a Google Cloud GPU instance.

### Knowledge Graphs for Chemistry

Build a knowledge graph on AWS from scratch: upload the OREGANO dataset to S3, load it into Amazon Neptune, run SPARQL queries, and optionally deploy a Streamlit web interface on Fargate. ~1–2 hours end-to-end.

### Toy Data Portal for Hydrology

Stand up a hydrology stack on Google Cloud: a GKE Autopilot cluster, JupyterHub for notebooks, and a toy data portal for NetCDF uploads and metadata extraction.

---

## 📖 Documentation Site

All tutorials are also published as a browsable docs site built with [Docusaurus](https://docusaurus.io):

**Live:** <https://cloudbank-project.github.io/cloudbank_showcase/>

The site is **generated from the tutorial sources** — the markdown guides stay in their folders (e.g. `gpu_computing_oceanography/`) and are the single source of truth. There is no duplicated content to maintain.

### How it works

- `website/` — the Docusaurus app (config, sidebar, site pages).
- `website/scripts/sync.mjs` (run automatically before `start`/`build`/`serve`, or manually via `npm run sync`):
  - copies each tutorial's guides into `website/docs/tutorials/<slug>/` (original filenames kept, so relative links and `img/` assets resolve),
  - converts every `*.ipynb` notebook to **static markdown** (code cells, text outputs, PNG outputs embedded as images) — no Python/Jupyter needed to build.
- Generated pages under `website/docs/tutorials/` are git-ignored; never edit them by hand.

### Build and run locally

```bash
cd website
npm install
npm run sync     # (re)generate docs/tutorials from the tutorial sources
npm run start    # local dev server (http://localhost:3000)
npm run build    # production build -> website/build/
npm run serve    # serve the production build locally
```

### Deploy

`.github/workflows/docs.yml` builds the site and publishes it to GitHub Pages on every push to `main` (source: **GitHub Actions**). The Docusaurus `baseUrl` in `website/docusaurus.config.js` is `/cloudbank_showcase/`; adjust `url`/`baseUrl` there if the site is hosted elsewhere.

### Adding/updating a tutorial

1. Edit the guides/notebooks in their source folder.
2. Rebuild with `cd website && npm run build` to verify.
3. When adding a new guide, add it to the `files` list for that tutorial in `website/scripts/sync.mjs`. For a brand-new top-level tutorial, also add a category to `website/sidebars.js` and a row to `website/docs/index.md`.

Full details: [website/README.md](website/README.md).
