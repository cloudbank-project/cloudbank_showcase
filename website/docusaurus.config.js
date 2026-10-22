// Build timestamp: captured once when the site is built so the footer can
// show exactly when the published pages were generated, in Pacific time
// (America/Los_Angeles, with PDT/PST abbreviation handled by Intl so DST
// transitions stay correct).
const buildTime = new Date();
const timeParts = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/Los_Angeles',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
  timeZoneName: 'short',
}).formatToParts(buildTime);
const part = (type) => timeParts.find((p) => p.type === type)?.value;
const buildTimeLabel = (
  `${part('year')}-${part('month')}-${part('day')} ${part('hour')}:${part('minute')} ${part('timeZoneName')}`
);

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
        src: 'img/cloudbank-logo.png',
        alt: 'CloudBank',
        height: 30,
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
      logo: {
        src: 'img/cloudbank-logo.png',
        alt: 'CloudBank logo',
        height: 34,
      },
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
      copyright: `<span class="last-build">Last site build: ${buildTimeLabel}</span> · Copyright © ${new Date().getFullYear()} CloudBank Showcase. Built with Docusaurus.`,
    },
  },
};

module.exports = config;
