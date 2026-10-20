# 2 - Access Jupyter Notebook via Browser

Goal: Configure firewall rules and access the Jupyter notebook running on your GPU instance through a web browser. This provides the simplest access method and works in any web browser.

**Advantages of browser-based Jupyter:**
- No local software installation required
- Works on any device with a web browser
- Quick setup - just open firewall and access via URL
- Perfect for Chromebooks and mobile devices

## Prerequisites
- Completed tutorial 1 (GPU instance created, Julia packages installed, Jupyter kernels registered)
- Jupyter not yet running on the server

### Step 1: Launch Jupyter notebook securely
First, make sure the notebook server is installed on the instance (tutorial 1 installs it, but
if you skipped that part of the setup, install it now):
```bash
sudo apt-get install -y jupyter-nbconvert jupyter-notebook
```
`jupyter-notebook` (6.4.8 on Ubuntu 22.04) provides the notebook server; `jupyter-nbconvert`
alone is NOT sufficient because IJulia's `notebook(...)` launch requires the `notebook`
subcommand.

> **Kernel name for nbconvert:** if you execute the notebook headless with
> `jupyter nbconvert --execute`, pass `--ExecutePreprocessor.kernel_name=julia-1.11` so it
> matches the installed kernel (`jupyter kernelspec list`). If the notebook metadata and
> the installed kernel name differ, fix the metadata or pass the name that is actually
> installed.

Then ask Gemini to start Jupyter with authentication enabled:
```
SSH into the server and launch Jupyter notebook using IJulia so it is accessible over the network and runs in the background.
```

**Julia command:**
```bash
julia -e 'using IJulia; notebook(`--ip=0.0.0.0 --no-browser`, dir=pwd(), detached=true)'
```

Then ask Gemini to retrieve the Jupyter URL with token:
```
Show me the Jupyter server URL including the token from the running Jupyter process logs.
```

**Security note:** Jupyter auto-generates a secure token. The full URL including the token will be printed in the logs — only share it with trusted users.

## Open firewall port for Jupyter

### Step 2: Allow Jupyter port access
Ask Gemini to create a firewall rule to allow access to Jupyter:
```
Create a firewall rule to allow access to port 8888 for Jupyter notebook. The rule should allow TCP traffic from any IP address.
Then show the full connection URL for Jupyter including the external IP and the token.
```

**Expected firewall rule creation:**
```bash
gcloud compute firewall-rules create allow-jupyter \
  --allow tcp:8888 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow Jupyter notebook access"
```

Gemini will also provide the connection URL with a token, typically looking like:
```
http://xxx.xxx.xxx.xxx:8888/?token=abcdef1234567890...
```

> **Note:** If the firewall creation says the rule `allow-jupyter` already exists, that is
> fine: the project already has the rule, so just continue (do not create a duplicate).

### Step 3: Open in the browser
Paste the URL from the previous step into your web browser to access the Jupyter notebook interface.

**Important:** Don't share the token URL with others. The token provides secure access to your Jupyter notebook and GPU instance.

### Step 4: Verify GPU access
In Jupyter, create a new Julia notebook and run:

```julia
using CUDA
CUDA.versioninfo()
```

Expected output should show:
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

## Upload the tutorial notebook
If you followed tutorial 1, the repo is already cloned on the server (in
`~/cloudbank_showcase/gpu_computing_oceanography/`) and you can skip this section. If you did
not clone it, upload the notebook files from your local machine:

1. In Jupyter, click **Upload** in the top right corner
2. Select the `ocean_gpu_tutorial.ipynb`, `ocean_utils.jl`, and `Project.toml` files from your local machine
3. Click **Upload** to confirm
4. Open the tutorial notebook to begin the ocean modeling tutorial

## Security considerations
**Important:** The firewall rule allows access from any IP address. When you're done working:
1. Delete the firewall rule:
   ```bash
   gcloud compute firewall-rules delete allow-jupyter
   ```
2. Stop the instance if not needed:
   ```bash
   gcloud compute instances stop julia-ocean-gpu --zone=us-west1-b
   ```

## Troubleshooting
- **Connection refused:** Ensure Jupyter is running and the firewall rule is in place
- **Token not found:** Ask Gemini to show the latest Jupyter logs to find the correct token
- **Slow performance:** This is normal during first GPU compilation; subsequent runs will be much faster

## Alternative access method
If you prefer using VS Code instead of browser-based Jupyter for a full IDE experience, see tutorial [`3_access_jupyter_vscode.md`](3_access_jupyter_vscode.md).
