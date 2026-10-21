# 🌊 GPU Computing in Oceanography on Google Cloud

> **Why this guide's resources?** The whole tutorial is a chain of small cloud
> resources: a CloudBank billing account (federated login) opens the Google Cloud
> project, Cloud Shell drives `gcloud`, a Compute Engine GPU VM (1x T4) hosts the
> simulation, a firewall rule exposes Jupyter, and Jupyter or VS Code gives you
> access to the notebook. Read
> [0 - The Cloud Resources in This Tutorial](0_cloud_resources_overview.md) first;
> the guides then follow the sequence 0 -> 4.

This showcase demonstrates the power of GPU-accelerated, differentiable ocean modeling using Julia. By leveraging **Reactant.jl (XLA)** and **Enzyme.jl (Automatic Differentiation)**, we can simulate complex ocean dynamics and calculate sensitivities with unprecedented speed.

## 📁 Showcase Track: Interactive Exploration (Single GPU)

Learn the fundamentals of differentiable oceanography in an interactive Jupyter environment.

*   **Main File:** [ocean_gpu_tutorial.ipynb](ocean_gpu_tutorial.ipynb)
*   **Shared Logic:** [ocean_utils.jl](ocean_utils.jl) (Modular physics engine)
*   **Key Concepts:** Ocean physics, topography (ridges), and calculating cause-and-effect (adjoint gradients).
*   **Setup Guides:**
    *   [0 - Cloud Resources Overview](0_cloud_resources_overview.md)
    *   [1 - Create a GPU Instance](1_create_gpu_instance.md)
    *   [2 - Access via Browser](2_access_jupyter_browser.md)
    *   [3 - Access via VS Code](3_access_jupyter_vscode.md)
    *   [4 - Execute the Tutorial Notebook](4_execute_tutorial_notebook.md)

---

## 🚀 Getting Started

If you are new to this showcase, start with **[Step 1: Create a GPU Instance](1_create_gpu_instance.md)** to set up your environment on Google Cloud.
