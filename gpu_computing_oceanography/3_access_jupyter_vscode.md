# 3 - Access with VS Code Remote

> **Why this guide's resources?** Nothing new is created here: VS Code Remote-SSH
> is a different door into the same GPU VM, using the SSH key stored in the
> instance metadata. Your laptop only needs VS Code and the Remote-SSH extension,
> because the Julia, Python and Jupyter tooling installs itself on the VM, where
> the GPU is. See [0 - The Cloud Resources in This Tutorial](0_cloud_resources_overview.md)
> for the resource map.

Goal: Use VS Code Remote SSH to connect to your GPU instance and run Jupyter notebooks with full IDE capabilities.

**Advantages of VS Code over browser Jupyter:**
- Full IDE with debugging, IntelliSense, and advanced editing
- Better performance for large notebooks
- Integrated terminal and Git integration
- Extensions marketplace for additional functionality
- Syntax highlighting and code navigation for Julia

## Prerequisites
- Completed tutorial 1 (GPU instance created and Julia packages installed)
- VS Code installed on your local machine
- VS Code Remote - SSH extension installed

**Note:** You do NOT need Julia or Python installed locally. VS Code will install the Julia and Python extensions on the remote server automatically when you connect.

## Access from local VS Code

### Step 1: Get SSH connection details
Ask Gemini for the SSH connection information:
```
Show me the SSH connection command for the server.
```

**Expected command:**
```bash
gcloud compute ssh julia-ocean-gpu --zone=us-west1-b
```

### Step 2: Open VS Code Remote SSH

**In your local VS Code:**
1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "Remote-SSH: Connect to Host" and select it
3. Choose "Add New SSH Host"
4. Paste the SSH command above
5. Choose the SSH config file location (usually default)
6. Press Enter to confirm

**Alternative method - use gcloud integration:**
1. Install the "Cloud Code" extension in VS Code
2. Click the Cloud Code icon in the sidebar
3. Navigate to your Google Cloud project
4. Right-click on `julia-ocean-gpu` instance
5. Select "SSH in terminal" and then "Open in VS Code"

### Step 3: Connect to the server
1. In the Remote-SSH panel, click the new host (`julia-ocean-gpu`)
2. Wait for VS Code to connect to the server
3. A new VS Code window will open with the server's files

### Step 4: Install VS Code extensions on server
Once connected, VS Code will prompt you to install extensions on the server. Install:

**Required extensions:**
- **Julia** - Julia language support and notebook rendering
- **Python** - For Jupyter support
- **Jupyter** - For notebook integration

**Optional but recommended:**
- **GitLens** - Enhanced Git capabilities
- **Remote Development** - Additional remote tools

### Step 5: Verify Julia environment

**In VS Code remote terminal:**
```bash
julia --version
```

Expected output: `julia version 1.11.9`

### Step 6: Upload the tutorial notebook

**Option A - Clone repository:**
```bash
git clone https://github.com/cloudbank-project/cloudbank_showcase.git
cd cloudbank_showcase/gpu_computing_oceanography
```

**Option B - Upload notebook:**
1. In VS Code's file explorer, right-click and select "Upload Files"
2. Select `ocean_gpu_tutorial.ipynb`, `ocean_utils.jl`, and `Project.toml` from your local machine
3. Wait for the upload to complete

### Step 7: Open the notebook

**Open the Julia notebook:**
1. Navigate to `gpu_computing_oceanography/ocean_gpu_tutorial.ipynb`
2. Right-click the file and select "Open with VS Code"
3. Select Julia as the kernel when prompted
4. VS Code will render the notebook beautifully with inline plots

### Step 8: Verify GPU access

**In the first code cell of the notebook, run:**
```julia
using CUDA
CUDA.versioninfo()
```

Expected output:
```
CUDA toolchain: 
- runtime 13.2, artifact installation
- driver 580.178.4 for 13.3
- compiler 13.3, artifact installation

CUDA libraries: 
- CUBLAS: 13.4.0
- CURAND: 10.4.2
- CUFFT: 12.2.0
- CUSOLVER: 12.2.0
- CUSPARSE: 12.7.10
- CUPTI: 2026.1.1 (API 13.2.1)
- NVML: 13.0.0+580.178.4

Julia packages: 
- CUDA: 5.11.3
- GPUArrays: 11.5.16
- GPUCompiler: 1.17.1
- KernelAbstractions: 0.9.45
- CUDA_Driver_jll: 13.3.5+0
- CUDA_Compiler_jll: 0.4.4+1
- CUDA_Runtime_jll: 0.21.0+1

Toolchain:
- Julia: 1.11.9
- LLVM: 16.0.6

1 device:
  0: Tesla T4 (sm_75, 14.559 GiB / 15.000 GiB available)
```

(These are the versions observed on Ubuntu 22.04 LTS as of October 2026; exact patch
versions of CUDA.jl and friends may differ slightly on a fresh install, which is fine.)

## Troubleshooting

**Connection issues:**
- Ensure `gcloud compute ssh` works from your local terminal
- Check your VS Code Remote-SSH extension is installed
- Try restarting the remote connection

**Julia kernel issues:**
- Run `julia -e 'using IJulia; installkernel("Julia")'` in the remote terminal
- Ensure Julia 1.11.9 is the default version
- Check that IJulia is properly installed

**GPU not detected:**
- Verify `nvidia-smi` shows the GPU
- Check CUDA is working in Julia
- Ensure drivers are properly installed

## Next steps
Now you're ready to run the Julia ocean modeling tutorial:
1. Open `ocean_gpu_tutorial.ipynb` in VS Code
2. Run cells sequentially to set up the environment
3. Execute the differentiable ocean dynamics simulation
4. Visualize results with GPU-accelerated rendering

## Cleanup
When you're done:
```bash
# From Cloud Shell (not inside the instance)
gcloud compute instances stop julia-ocean-gpu --zone=us-west1-b
gcloud compute instances delete julia-ocean-gpu --zone=us-west1-b
```

## Alternative access method
If you prefer using browser-based Jupyter instead of VS Code, see tutorial [`2_access_jupyter_browser.md`](2_access_jupyter_browser.md).
