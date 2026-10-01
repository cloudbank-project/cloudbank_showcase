/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  tutorialSidebar: [
    { type: 'link', label: 'Home', href: '/' },
    {
      type: 'category',
      label: 'GPU Computing in Oceanography (Google Cloud)',
      link: { type: 'doc', id: 'tutorials/gpu-oceanography/overview' },
      collapsed: false,
      items: [
        'tutorials/gpu-oceanography/overview',
        'tutorials/gpu-oceanography/create_gpu_instance',
        'tutorials/gpu-oceanography/access_jupyter_browser',
        'tutorials/gpu-oceanography/access_jupyter_vscode',
        'tutorials/gpu-oceanography/execute_tutorial_notebook',
        'tutorials/gpu-oceanography/ocean_gpu_tutorial',
        'tutorials/gpu-oceanography/ocean_gpu_tutorial_executed',
      ],
    },
    {
      type: 'category',
      label: 'Knowledge Graphs for Chemistry (AWS)',
      link: { type: 'doc', id: 'tutorials/knowledge-graphs-chemistry/overview' },
      collapsed: false,
      items: [
        'tutorials/knowledge-graphs-chemistry/overview',
        'tutorials/knowledge-graphs-chemistry/step_01_aws_auth',
        'tutorials/knowledge-graphs-chemistry/step_02_neptune_setup',
        'tutorials/knowledge-graphs-chemistry/step_03_load_and_query',
        'tutorials/knowledge-graphs-chemistry/step_04_fargate_web_interface',
      ],
    },
    {
      type: 'category',
      label: 'Cloud Seismology Analysis (AWS)',
      link: { type: 'doc', id: 'tutorials/cloud-seismology/overview' },
      collapsed: false,
      items: [
        'tutorials/cloud-seismology/overview',
        'tutorials/cloud-seismology/setup_instance',
        'tutorials/cloud-seismology/read_write_object_storage',
        'tutorials/cloud-seismology/tutorial_noisepy_scedc_s3_explained',
      ],
    },
    {
      type: 'category',
      label: 'Toy Data Portal for Hydrology (Google Cloud)',
      link: { type: 'doc', id: 'tutorials/toy-data-portal/overview' },
      collapsed: false,
      items: [
        'tutorials/toy-data-portal/overview',
        'tutorials/toy-data-portal/access_gcp',
        'tutorials/toy-data-portal/deploy_jupyterhub',
        'tutorials/toy-data-portal/deploy_portal',
        'tutorials/toy-data-portal/analyze_portal_data',
      ],
    },
    {
      type: 'category',
      label: 'Project',
      collapsed: true,
      items: ['about', 'contributing'],
    },
  ],
};

module.exports = sidebars;
