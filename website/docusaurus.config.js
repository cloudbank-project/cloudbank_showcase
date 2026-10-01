const config = {
  title: 'CloudBank Showcase',
  tagline: 'Cloud computing tutorials for real-world scientific applications',
  url: 'https://cloudbank-project.github.io',
  baseUrl: '/cloudbank_showcase/',
  onBrokenLinks: 'warn',
  markdown: {
    // Tutorial guides are CommonMark markdown (e.g. they use `<https://...>`
    // autolinks); parse them as MD to avoid MDX JSX parsing issues.
    format: 'md',
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },
  favicon: 'img/favicon.svg',
  organizationName: 'cloudbank-project',
  projectName: 'cloudbank_showcase',
  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          routeBasePath: '/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],
  themeConfig: {
    image: 'img/favicon.svg',
    navbar: {
      title: 'CloudBank Showcase',
      logo: {
        src: 'img/favicon.svg',
        href: '/cloudbank_showcase/',
      },
      items: [
        {
          to: '/',
          position: 'left',
          label: 'Home',
        },
        {
          href: 'https://github.com/cloudbank-project/cloudbank_showcase',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Home',
              to: '/',
            },
            {
              label: 'About this site',
              to: '/about',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'CloudBank',
              href: 'https://www.cloudbank.org/',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} CloudBank Showcase. Built with Docusaurus.`,
    },
  },
};

module.exports = config;
