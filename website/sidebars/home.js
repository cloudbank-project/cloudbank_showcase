/**
 * Left sidebar of the site pages (Home, About, Contributing): lists every
 * tutorial so you can pick the one you want. Each tutorial's own sidebar
 * (generated in this same folder by scripts/sync.mjs) shows only that
 * tutorial's tree.
 *
 * @type {import('@docusaurus/plugin-content-docs').SidebarsConfig}
 */
const homeSidebar = [
  { type: 'doc', id: 'index', label: 'Home' },
  {
    type: 'category',
    label: 'Tutorials',
    collapsed: false,
    items: [
      {
        type: 'link',
        label: 'GPU Computing in Oceanography (Google Cloud)',
        href: '/tutorials/gpu-oceanography/overview',
      },
      {
        type: 'link',
        label: 'Knowledge Graphs for Chemistry (AWS)',
        href: '/tutorials/knowledge-graphs-chemistry/overview',
      },
      {
        type: 'link',
        label: 'Cloud Seismology Analysis (AWS)',
        href: '/tutorials/cloud-seismology/overview',
      },
      {
        type: 'link',
        label: 'Toy Data Portal for Hydrology (Google Cloud)',
        href: '/tutorials/toy-data-portal/overview',
      },
    ],
  },
  { type: 'doc', id: 'about', label: 'About this site' },
  { type: 'doc', id: 'contributing', label: 'Contributing' },
];

module.exports = { homeSidebar };
