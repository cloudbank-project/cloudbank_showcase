# 0 - The Cloud Resources in This Tutorial

This is the resource map for the whole tutorial: what each cloud resource is, why
we need it, and how several resources work **together**. Science is one short
sentence per step at most; the notebook is where the oceanography lives.

## The short version

| Step | Cloud resource | Why (one line) |
| --- | --- | --- |
| Log in | CloudBank billing account (federated login) | Research funding pays the bill, not your credit card. |
| Open the workspace | Google Cloud project | Isolates and accounts for everything you create. |
| Build the machine | Cloud Shell + Compute Engine GPU VM | Cloud Shell runs `gcloud`; the VM holds the GPU. |
| Open the door | Firewall rule `allow-jupyter` (TCP 8888) | Lets your browser reach Jupyter on the VM. |
| Use the notebook | Jupyter server on the VM (token URL) | The GPU and packages are on the VM; the browser is just a window. |
| Run the model | Julia + CUDA in the notebook | The simulation runs where the GPU is. |
| Alternative route | VS Code Remote-SSH | Same VM, different door: SSH key, no firewall port. |
| Finish | Delete the firewall rule and the VM | Stops the bill and closes the open port. |

No single resource does the job: CloudBank gives access, the project organizes the
resources, the VM computes, and the firewall plus Jupyter (or VS Code) are how you reach it.

## CloudBank billing account and federated login

CloudBank is an NSF-funded gateway that lets academic researchers use commercial
cloud without signing up themselves or paying out of pocket. CloudBank holds the
funding allocation, so the provider bills CloudBank, not you. **Why we use it:**
the tutorial's cloud cost is covered by the CloudBank allocation; no personal
credit card, no separate cloud signup, no reimbursement paperwork. **How login
works:** open `https://www.cloudbank.org/billing-account-access` and click
**Login** in the Google Cloud row (guide 1). CloudBank uses CILogon, a federated
identity service, so you sign in with your institutional identity and CloudBank
takes you to the Google account it created for you.

## Google Cloud project

A project is the container for all Google Cloud resources. The VM, its disk and
the firewall rule all live inside one project, and billing, permissions and quotas
are tracked per project. **Why we use it:** exactly one project, so you always
know which resources are yours, what they cost and what to clean up; CloudBank
points you at a specific project, which is why guide 1 says to note its name.

## Compute Engine GPU VM

The GPU VM (`julia-ocean-gpu`) is the one resource that actually does the work. A
GPU is a chip with thousands of simple cores that run arithmetic in parallel, which
is exactly what numerical ocean modeling needs. **Why a GPU VM:** the tutorial
simulates a small ocean flow over time (one sentence of science below); on the GPU
this takes minutes instead of hours. **Why 1x Tesla T4 (16 GB):** the model grid is
small (48 x 96 x 32 cells), so one T4 has plenty of memory and is one of the
cheapest GPU options; a bigger GPU would only cost more. **Why n1-standard-4 (4
vCPU, 15 GB RAM):** enough CPU and RAM to feed the GPU and run Julia, Jupyter and
the OS; more would only raise the hourly price. **Why Ubuntu 22.04 LTS:** long-term
support, and the whole stack here (NVIDIA driver, Jupyter, Julia packages) is
verified on this image. **Why 200 GB pd-ssd:** Julia packages and notebook outputs
take many GB, and an SSD loads and precompiles them far faster than a standard
disk.

One sentence of science: the notebook solves the ocean fluid equations on that
small 3D grid and computes sensitivities with adjoint methods.

## Cloud Shell

Cloud Shell is a terminal inside a browser tab, with the `gcloud` CLI already
installed and authenticated as your project identity. **Why we use it:** nothing
to install locally, it works on any machine including a Chromebook, and it can act
on your Google project immediately. **Why not for long-running work:** it is an
ephemeral VM that resets after inactivity; we only use it to create the GPU VM and
SSH into it.

## Firewall rules

A firewall rule decides which inbound traffic a VM accepts. By default a VM
accepts almost nothing, so Jupyter is unreachable until you open its port. **Why
`allow-jupyter` (TCP 8888 from 0.0.0.0/0):** it opens exactly the Jupyter port from
anywhere, so you can connect from your laptop, Chromebook or phone. **The
tradeoff:** anyone who finds the URL could try it; the Jupyter token in the URL and
deleting the rule when done protect you. Restricting the rule to your own IP is
stricter, but breaks as soon as you switch networks. **Why SSH keys in instance
metadata instead:** for shell access we use `gcloud compute ssh`, which stores SSH
keys in the instance metadata; only a key present there can log in, so we never
open port 22 to the whole internet.

## Jupyter notebook server on the VM

Jupyter runs on the VM, not on your laptop. **Why on the VM:** the GPU, the
driver, the Julia packages and the notebook files are all on the VM; that is
where the code must run. Your browser only draws the UI and sends commands.
**Why token auth:** Jupyter generates a secret token on startup and prints the
full URL with it; only someone with that URL can use your notebook.

## VS Code Remote-SSH (alternative route)

VS Code adds no new cloud resource; it is a second door into the same VM. **Why it
is an alternative route, not another resource:** the VM, the GPU and the packages
are identical; only the way you reach them changes. **Why nothing but an SSH key
is needed locally:** the connection uses the same instance-metadata SSH key as
`gcloud compute ssh`; VS Code installs Julia, Python and Jupyter support on the
server side, so you install nothing on your laptop.

## Ephemeral external IP and cleanup

The VM gets a temporary (ephemeral) external IP. It is free, but it can change
whenever the VM is restarted, so the Jupyter URL may change too. **Why costs
accrue:** the GPU, vCPUs, RAM and disk are billed while the VM exists, and the GPU
is the biggest line item. **Why cleanup matters:** deleting the firewall rule and
the VM (guide 1, last section) stops the charges and closes the open port.

## How it all fits together

1. Federated login to CloudBank, click through to the Google project.
2. Cloud Shell runs `gcloud` to create the GPU VM and install driver, Julia and
   packages on it.
3. The firewall rule opens TCP 8888 so the browser can reach Jupyter.
4. Jupyter runs on the VM; you open its token URL in any browser.
5. The notebook runs Julia + CUDA on the T4: the actual ocean simulation.
6. Cleanup: delete the firewall rule and the VM.

Each step depends on the one before it: no CloudBank login, no project; no
firewall rule, no Jupyter; no VM, no GPU. Several small cloud resources,
orchestrated together, give you a GPU-accelerated notebook in about an hour.
