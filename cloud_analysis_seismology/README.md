# Cloud Seismology Analysis Tutorials

These guides show how to run a real research workflow — **ambient noise cross-correlation with [NoisePy](https://github.com/noisepy/NoisePy)** — entirely in the AWS cloud, using the public [Southern California Earthquake Data Center (SCEDC)](https://scedc.caltech.edu/data/getstarted-pds.html) dataset hosted on S3. You never download seismic data to your laptop: the analysis runs on a cloud instance right next to the data, and only the (small) results are written back to cloud storage.

## What you will build

By the end of the three tutorials you will have this setup, built from scratch in about an hour:

```
 your laptop                     AWS (us-west-2)
 ────────────                    ─────────────────────────────────────────────
 browser ──────────────────────► EC2 instance
 (CloudBank login)               ┌──────────────────────────────────────────┐
                                 │ Docker container with Jupyter Lab +      │
                                 │ NoisePy (pre-built image)                │
                                 └───────────────┬──────────────────────────┘
                                                 │ reads (streaming)
                                                 ▼
                                 S3 bucket `scedc-pds` (public, SCEDC data)
                                                 │
                                                 │ writes results
                                                 ▼
                                 your own S3 bucket (stacked correlations)
```

In concrete steps:

1. Log in to AWS through your CloudBank account (no separate AWS account needed).
2. Start a virtual machine (an *EC2 instance*) in the same AWS region where the SCEDC data lives, and run Jupyter Lab on it inside a Docker container that already has all the scientific software installed.
3. Create credentials for S3 (AWS's object storage) so your code can read the public seismic data and write results to a bucket of your own.
4. Run the tutorial notebook: it streams one day of continuous waveform data for three seismic stations directly from S3, computes cross-correlations between station pairs, stacks them, saves the stacks back to your bucket, and plots a "moveout" section you can use to inspect the Earth's subsurface response.

## Why run this in the cloud?

Seismic noise analysis is data-heavy: the SCEDC archive holds decades of continuous recordings (terabytes). Doing this on a laptop means slow downloads and a full disk. Hosting the data on S3 and running the analysis on an EC2 instance *in the same region* means the data never leaves the cloud — access is fast, you only pay for the compute while it runs, and you keep only the results. This "process the data where it lives" pattern is the core idea the tutorials teach; it transfers directly to other data-intensive domains.

## Repository Contents

1. **`1_setup_instance.md` – EC2 + Docker + Jupyter + S3**  
	Walks through logging in via CloudBank, choosing an AWS region, creating the security group that opens ports 22/80/443, launching an Amazon Linux EC2 instance, and configuring Docker + the `ghcr.io/seisscoped/noisepy:centos7_jupyterlab` image so you can reach Jupyter Lab securely over HTTPS.

2. **`2_read_write_object_storage.md` – Creating S3 access keys and configuring the AWS CLI**  
	Covers creating an IAM user with `AmazonS3FullAccess`, generating CLI credentials, running `aws configure`, and testing access with `aws s3 ls` so you can read and write seismic data on S3 from your notebook session.

3. **`3_tutorial_noisepy_scedc_s3_explained.ipynb` – NoisePy SCEDC workflow notebook**  
	A Jupyter tutorial that installs `noisepy-seis`, explains why cloud-native processing helps, and processes the SCEDC public dataset directly from AWS S3, demonstrating end-to-end ambient noise cross-correlation without local data transfers.

## How to Use This Repo

1. **Provision the compute environment** by following `1_setup_instance.md`. When the container is running, connect to `https://<your-public-ip>` and supply the `scoped` token set in the Docker command. At the end of the guide, put the notebook onto the instance (upload it in Jupyter Lab, or `wget` it on the instance).
2. **Enable object storage access** with `2_read_write_object_storage.md` so the notebook can stream data to/from S3 using your IAM credentials, and create the bucket that receives the stacked results.
3. **Run the notebook** `3_tutorial_noisepy_scedc_s3_explained.ipynb` inside the Jupyter Lab session (**Run → Run All Cells**), making sure `STACK_STORE_PATH` points at your bucket (create a bucket you own and either set the environment variable when starting the container — e.g. `STACK_STORE_PATH=s3://my-bucket/noisepy-stacks` — or edit the fallback path inside the notebook).

The guides are written for beginners: every step is spelled out, and advanced options (SSH from your laptop, least-privilege IAM policies) are in clearly marked notes and appendices.

## Future Work (planned)

Additional workflows—such as AWS Batch orchestration, Coiled-managed Dask clusters, and earthquake catalog analysis with Fargate + MongoDB Atlas—will be added in separate tutorials.

## References

* [NoisePy SCEC Tutorial](https://seisscoped.org/HPS-book/chapters/noise/noisepy_scedc_tutorial.html)
* [SCEDC Public Data Set on AWS](https://scedc.caltech.edu/data/getstarted-pds.html)

---
Each document is self-contained and can be followed independently, but working through them sequentially provides a complete pathway from bare-metal cloud setup to running NoisePy against AWS-hosted seismic data.
