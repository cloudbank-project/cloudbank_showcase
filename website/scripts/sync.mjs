// Syncs the canonical tutorial sources (markdown guides + Jupyter notebooks)
// from the repository root into the Docusaurus docs tree at website/docs/tutorials.
//
// - Markdown guides are copied as-is (original filenames kept, so relative
//   links between guides keep working) with a small injected frontmatter block
//   (title / sidebar_position).
// - Jupyter notebooks are converted to static markdown (code cells + text
//   outputs + rendered PNG outputs) so no Python/Jupyter tooling is needed to
//   build the site.
//
// Run with `npm run sync` (also runs automatically before start/build/serve).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const DOCS_DIR = path.join(__dirname, '..', 'docs', 'tutorials');

const GITHUB_BASE =
  'https://github.com/cloudbank-project/cloudbank_showcase/blob/main';

const TUTORIALS = [
  {
    slug: 'gpu-oceanography',
    sourceDir: 'gpu_computing_oceanography',
    linkRewrites: [
      {
        from: '[ocean_utils.jl](ocean_utils.jl)',
        to: `[ocean_utils.jl](${GITHUB_BASE}/gpu_computing_oceanography/ocean_utils.jl)`,
      },
    ],
    files: [
      { from: 'README.md', title: 'Overview', position: 0 },
      { from: '1_create_gpu_instance.md', title: '1. Create a GPU Instance', position: 1 },
      { from: '2_access_jupyter_browser.md', title: '2. Access via Browser', position: 2 },
      { from: '3_access_jupyter_vscode.md', title: '3. Access via VS Code', position: 3 },
      { from: '4_execute_tutorial_notebook.md', title: '4. Execute the Tutorial Notebook', position: 4 },
      { from: 'ocean_gpu_tutorial.ipynb', title: 'Notebook: Ocean GPU Tutorial', position: 5 },
      { from: 'ocean_gpu_tutorial_executed.ipynb', title: 'Notebook: Executed with Outputs', position: 6 },
    ],
  },
  {
    slug: 'knowledge-graphs-chemistry',
    sourceDir: 'knowledge_graphs_chemistry',
    fileBaseDir: 'docs',
    stripDocsPrefix: true,
    linkRewrites: [
      {
        from: '[.tools/aws/README.md](../.tools/aws/README.md)',
        to: '[AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)',
      },
    ],
    files: [
      { from: 'README.md', title: 'Overview', position: 0 },
      { from: 'docs/step_01_aws_auth.md', title: 'Step 1. Connect Your Terminal to AWS', position: 1 },
      { from: 'docs/step_02_neptune_setup.md', title: 'Step 2. Create the Database Infrastructure', position: 2 },
      { from: 'docs/step_03_load_and_query.md', title: 'Step 3. Load Data and Run Queries', position: 3 },
      { from: 'docs/step_04_fargate_web_interface.md', title: 'Step 4. Deploy a Web Interface', position: 4 },
    ],
  },
  {
    slug: 'cloud-seismology',
    sourceDir: 'cloud_analysis_seismology',
    files: [
      { from: 'README.md', title: 'Overview', position: 0 },
      { from: '1_setup_instance.md', title: '1. Set Up the Instance', position: 1 },
      { from: '2_read_write_object_storage.md', title: '2. Read/Write Object Storage', position: 2 },
      { from: '3_tutorial_noisepy_scedc_s3_explained.ipynb', title: 'Notebook: NoisePy SCEDC on S3', position: 3 },
    ],
  },
  {
    slug: 'toy-data-portal',
    sourceDir: 'toy_data_portal_hydrology',
    files: [
      { from: 'README.md', title: 'Overview', position: 0 },
      { from: '1_access_gcp.md', title: '1. Access CloudBank and GCP', position: 1 },
      { from: '2_deploy_jupyterhub.md', title: '2. Deploy JupyterHub', position: 2 },
      { from: '3_deploy_portal.md', title: '3. Deploy the Data Portal', position: 3 },
      { from: '4_analyze_portal_data.ipynb', title: 'Notebook: Analyze Portal Data', position: 4 },
    ],
    copyDirs: [{ from: 'img', to: 'img' }],
  },
];

// --- helpers ---------------------------------------------------------------

function stripDocsPrefix(text) {
  // Rewrites link targets like [label](docs/step_01_aws_auth.md)
  // (used by the knowledge-graphs README) once the guides are flattened.
  return text
    .replace(/(\]\(\.?\/?)docs\/([^()\s]+\.md)(\))/g, '$1$2$3')
    .replace(/\[docs\/([^\]()\s]+\.md)\]/g, '[$1]');
}

function rewriteLinks(text) {
  // Convert markdown links to .ipynb files so they point to the rendered
  // notebook pages in the generated docs tree.
  return text.replace(/(\]\([^)]*\.)ipynb(\))/g, '$1md$2');
}

function prependFrontmatter(content, title, position) {
  const frontmatter = `---\ntitle: ${JSON.stringify(title)}\nsidebar_position: ${position}\n---\n\n`;
  if (content.startsWith('---\n')) {
    const end = content.indexOf('\n---', 4);
    if (end !== -1) {
      return content.slice(0, end + 4) + '\n' + frontmatter + content.slice(end + 5);
    }
  }
  return frontmatter + content;
}

function joinSource(source) {
  return Array.isArray(source) ? source.join('') : source ?? '';
}

let imgCounter = 0;

function notebookToMarkdown(srcPath, destDir, stem) {
  const notebook = JSON.parse(fs.readFileSync(srcPath, 'utf8'));
  const language =
    notebook.metadata?.kernelspec?.language ??
    notebook.metadata?.language_info?.name ??
    'python';
  const parts = [];

  for (const cell of notebook.cells ?? []) {
    if (cell.cell_type === 'markdown') {
      parts.push(joinSource(cell.source).trim());
    } else if (cell.cell_type === 'code') {
      parts.push('```' + language + '\n' + joinSource(cell.source).trimEnd() + '\n```');
      for (const output of cell.outputs ?? []) {
        if (output.output_type === 'stream') {
          parts.push('```text\n' + joinSource(output.text).trimEnd() + '\n```');
        } else if (output.output_type === 'error') {
          parts.push(
            '```text\n' + joinSource(output.traceback ?? []).trimEnd() + '\n```',
          );
        } else {
          const data = output.data ?? {};
          if (data['image/png']) {
            imgCounter += 1;
            const imageName = `${stem}-output-${imgCounter}.png`;
            fs.writeFileSync(
              path.join(destDir, imageName),
              Buffer.from(joinSource(data['image/png']), 'base64'),
            );
            parts.push(`![](${imageName})`);
          } else if (data['text/html']) {
            parts.push(joinSource(data['text/html']).trim());
          } else if (data['text/plain']) {
            parts.push('```text\n' + joinSource(data['text/plain']).trimEnd() + '\n```');
          }
        }
      }
    }
  }

  return parts.join('\n\n') + '\n';
}

// --- main ------------------------------------------------------------------

fs.rmSync(DOCS_DIR, { recursive: true, force: true });
fs.mkdirSync(DOCS_DIR, { recursive: true });

let copied = 0;
let notebooks = 0;

for (const tutorial of TUTORIALS) {
  const sourceDir = path.join(REPO_ROOT, tutorial.sourceDir);
  const destDir = path.join(DOCS_DIR, tutorial.slug);
  fs.mkdirSync(destDir, { recursive: true });

  for (const file of tutorial.files) {
    const srcRel = file.from;
    const srcPath = path.join(sourceDir, srcRel);
    if (!fs.existsSync(srcPath)) {
      console.warn(`[sync] WARNING: missing source file ${srcRel} in ${tutorial.sourceDir}`);
      continue;
    }
    const base = path.basename(srcRel, path.extname(srcRel));
    const isNotebook = srcRel.endsWith('.ipynb');

    let content;
    if (isNotebook) {
      notebooks += 1;
      const note =
        `:::note\n\nThis page is a static rendering of the Jupyter notebook ` +
        `\`${path.basename(srcRel)}\`. The raw notebook is available at ` +
        `[${GITHUB_BASE}/${tutorial.sourceDir}/${path.basename(srcRel)}]` +
        `(${GITHUB_BASE}/${tutorial.sourceDir}/${path.basename(srcRel)}).\n\n:::\n\n`;
      content = note + notebookToMarkdown(srcPath, destDir, base);
    } else {
      content = fs.readFileSync(srcPath, 'utf8');
      if (tutorial.stripDocsPrefix) {
        content = stripDocsPrefix(content);
      }
      content = rewriteLinks(content);
      for (const rewrite of tutorial.linkRewrites ?? []) {
        content = content.split(rewrite.from).join(rewrite.to);
      }
    }

    const outName =
      isNotebook
        ? `${base}.md`
        : path.basename(srcRel) === 'README.md'
          ? 'overview.md'
          : path.basename(srcRel);
    const outPath = path.join(destDir, outName);
    fs.writeFileSync(outPath, prependFrontmatter(content, file.title, file.position));
    copied += 1;
  }

  for (const dir of tutorial.copyDirs ?? []) {
    const fromPath = path.join(sourceDir, dir.from);
    if (fs.existsSync(fromPath)) {
      fs.cpSync(fromPath, path.join(destDir, dir.to), { recursive: true });
    }
  }
}

console.log(
  `[sync] OK: ${copied} files (${notebooks} notebooks converted) -> docs/tutorials/`,
);
