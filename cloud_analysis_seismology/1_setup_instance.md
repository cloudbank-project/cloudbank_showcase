# EC2 + Docker + Jupyter + S3

This tutorial walks you through setting up an AWS cloud instance from scratch.

## Log into AWS

1. Go to [CloudBank](https://cloudbank.org) and log in.
2. On the dashboard, click **Access CloudBank Billing Accounts**.
3. Find the **Amazon Web Services** billing account and click the `login` link under *Public Cloud Web Console Login* (the link text is lowercase).

> The first time, you may be routed through a CILogon page: select your institution and click **Log On** to continue.

You are now in the AWS Management Console.

## Choose a region

The region is where your cloud resources live. The seismic data we use is in the **US West (Oregon)** region, so use that one:

1. Check the region name in the top-right corner — the CloudBank federation usually drops you into **US West (Oregon)** already. If it shows a different region, click the region name and select **US West (Oregon)**.
2. All AWS resources you create will now be in this region.

## Create a security group

A security group is a firewall for your instance. We will open three ports:

- **22 (SSH)** to log in to the instance
- **80** and **443 (HTTP/HTTPS)** to reach Jupyter Lab

1. In the AWS console, go to **EC2** (use the search bar at the top).
2. In the left sidebar, click **Security Groups** (under *Network & Security*).
3. Click **Create security group**.
4. Fill in:
   - Security group name: `web-ssh-access`
   - Description: `Allow SSH and HTTP (for Jupyter)`
5. Under **Inbound rules**, click **Add rule** three times and set:

   | Type | Protocol | Port | Source |
   |------|----------|------|--------|
   | SSH  | TCP      | 22   | `0.0.0.0/0` |
   | HTTP | TCP      | 80   | `0.0.0.0/0` |
   | HTTPS| TCP      | 443  | `0.0.0.0/0` |

   > Each new rule starts as *Custom TCP* with port `0` and no source. Pick the **Type** (SSH/HTTP/HTTPS) and the port fills in automatically. For **Source**, choose **Anywhere-IPv4** (which represents `0.0.0.0/0`), or paste `0.0.0.0/0` into the source box and press Enter. The console shows a yellow warning about allowing all IP addresses — it is expected and can be ignored for this tutorial.

6. Leave everything else as default and click **Create security group**.

## Launch an instance

An *instance* is a virtual computer in the cloud. We will create one with enough memory and disk for our analysis.

1. In the EC2 dashboard, click **Launch instance**.
2. **Name**: give it a name, for example `seismology-tutorial`.
3. **Application and OS Image**: keep the default **Amazon Linux** (Amazon Linux 2023).
4. **Instance type**: click the instance-type box, type `t2.xlarge` into the search field that appears, and pick `t2.xlarge` from the list (4 vCPU, 16 GiB RAM).

   > **Note:** `t2.xlarge` is not free tier eligible. You pay per hour while the instance is running; stop it when you are done (see "Stop the instance" at the end).

5. **Key pair**: click **Create new key pair**, name it (for example `seismology-tutorial`), keep *RSA* and *.pem*, then click **Create key pair**. A modal opens inside the wizard; the `.pem` file is downloaded automatically and the wizard then selects the new key pair for you. Keep the file safe — you will not be able to download it again. If you have run this tutorial before, Chrome may save it as `seismology-tutorial (1).pem` (or `(2)`, …) — use the most recent file when connecting with SSH.
6. **Network settings**: click **Edit**, then select **Select existing security group**, and choose `web-ssh-access`.
7. **Configure storage**: change the default size to **20 GiB**.
8. Click **Launch instance** and wait until the instance shows *Running*.

## Connect to the instance

You can get a terminal in your browser — no SSH client needed:

1. In the Instances list, select your instance.
2. Wait until the status checks pass (usually a minute or two — look for "2/2 checks passed" next to the instance state) before connecting.
3. Click **Connect**.
4. Leave **EC2 Instance Connect** selected and click **Connect** (do not click the "Connect assist" button next to it).
5. A terminal opens in the same browser tab (it replaces the console page) and shows a prompt like `[ec2-user@ip-... ~]$`.

> The browser terminal may disconnect if it sits idle for a while — just click **Connect** → **Connect** again; anything you ran earlier is still there.

> **Prefer SSH from your own laptop?** On Linux/macOS:
> ```bash
> chmod 400 your-key.pem
> ssh -i your-key.pem ec2-user@your-instance-public-ip
> ```
> Replace `your-key.pem` with your downloaded key file and `your-instance-public-ip` with the *Public IPv4 address* shown in the instance details.

## Install Docker and Jupyter

The instance starts empty. We will run Jupyter Lab inside a Docker container that already has everything installed.

1. Install Docker and start it:

   ```bash
   sudo dnf install docker -y
   sudo systemctl enable --now docker
   sudo usermod -a -G docker ec2-user
   docker --version
   ```

   > Log out and back in (or run `newgrp docker`) before using `docker` commands, so your user is recognized as part of the docker group.

2. Pull the container image:

   ```bash
   docker pull ghcr.io/seisscoped/noisepy:centos7_jupyterlab
   ```

3. Create a self-signed certificate so Jupyter can serve HTTPS. In the EC2 console, select your instance and copy its **Public IPv4 address** (shown in the instance details), then use it in the first command:

   ```bash
   export URL="54.200.100.20"  # your Public IPv4 address

   mkdir -p /home/ec2-user/jupyter-cert
   cd /home/ec2-user/jupyter-cert

   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout jupyter.key -out jupyter.crt \
     -subj "/CN=${URL}"
   ```

   > Use the **Public IPv4 address**, not the *Private IP*: the certificate must match the address you type in the browser. (Some AWS accounts, including CloudBank's, do not assign a public DNS name to instances — the public IP address works the same way.)

4. Start Jupyter Lab in the container. This maps port 443 of the instance to Jupyter's port 8888 and uses the certificate we just made:

   ```bash
   docker run -p 443:8888 --rm -it \
     --user $(id -u ec2-user):$(id -g ec2-user) \
     -v /home/ec2-user:/home/scoped \
     -v /home/ec2-user/jupyter-cert:/home/scoped/jupyter-cert \
     -e HOME=/home/scoped \
     ghcr.io/seisscoped/noisepy:centos7_jupyterlab \
     jupyter lab --no-browser --ip=0.0.0.0 \
       --IdentityProvider.token=scoped \
       --certfile=/home/scoped/jupyter-cert/jupyter.crt \
       --keyfile=/home/scoped/jupyter-cert/jupyter.key
   ```

   > **S3 results:** the notebook saves its stacked results to an S3 bucket you own. If you already created the bucket (next guide), add this line to the command above, right after `-e HOME=/home/scoped`:
   > ```bash
   > -e STACK_STORE_PATH=s3://cloudbank-showcase-seismology/noisepy-stacks
   > ```
   > If you skip it, the notebook will ask you to set it before the stacking step (see the note at the end of guide 2).

   > **This terminal is now busy** running the Jupyter container — leave it open. Whenever you need another terminal on the instance (for example in the next guide), simply connect again: EC2 console → **Instances** → select the instance → **Connect** → **Connect**.

## Open Jupyter Lab

1. In your web browser, go to `https://your-instance-public-ip` (the public address shown in the EC2 console).
2. Your browser will show a "Your connection is not private" warning because the certificate is self-signed. Click **Advanced**, then click **Proceed to \<your-instance\> (unsafe)**.
3. When asked for a token, type: `scoped`

You are now in Jupyter Lab. The folder `/home/ec2-user` on the instance is visible inside the container, so anything you put there (like the notebook) can be opened here.

## Get the tutorial notebook

Jupyter Lab is running, but the tutorial notebook still needs to get onto the instance. Pick whichever is easier:

- **Upload from your laptop:** download `3_tutorial_noisepy_scedc_s3_explained.ipynb` from the [GitHub repository](https://github.com/cloudbank-project/cloudbank_showcase/blob/main/cloud_analysis_seismology/3_tutorial_noisepy_scedc_s3_explained.ipynb), then click the **Upload** button (the up-arrow icon at the top of Jupyter Lab's file browser) and select the file.
- **Download directly on the instance:** open a second terminal (EC2 console → select the instance → **Connect** → **Connect**) and run:
  ```bash
  curl -LO https://raw.githubusercontent.com/cloudbank-project/cloudbank_showcase/main/cloud_analysis_seismology/3_tutorial_noisepy_scedc_s3_explained.ipynb
  ```
  (`-L` follows redirects, `-O` saves the file under its own name.) The file lands in `/home/ec2-user`, which is the folder Jupyter Lab shows you.

Once the notebook appears in the file browser, double-click it to open it, then run it from top to bottom with the menu **Run → Run All Cells**. (Before the final stacking step you also need guide 2 — the notebook writes its results to an S3 bucket you own.)

## Stop the instance

When you are done, you can stop the instance to save money — you only pay for the disk, and your files are kept. If you terminate the instance instead, everything is deleted.

> Stop vs terminate: **Stop** keeps your data and costs only for the storage. **Terminate** deletes everything and stops all charges.
