# S3 Access Keys and the AWS CLI

This guide shows how to let your analysis read the public seismic data and write results to an S3 bucket you own. We will:

1. Create a user (access key) with exactly the needed permissions
2. Tell the AWS CLI to use that user
3. Test that it works

## Create the user and access key

1. Log in to the [AWS Management Console](https://console.aws.amazon.com/).
2. Go to **IAM** (you can search for it).
3. In the sidebar, click **Users** > **Create user**.
4. Name it `s3-access-user` and click **Next**.
5. Choose the simple option: **Attach policies directly**, then search for and select `AmazonS3FullAccess`. (This is fine for a tutorial; for a real project use the least-privilege policy at the bottom of this page instead.)
6. Click **Next**, then **Create user**.
7. Click on the new user, then on **Security credentials**.
8. Click **Create access key**, choose **Command Line Interface (CLI)**, tick the confirmation box, click **Next**, then **Create access key**.
9. **Copy both values now — you will not see the secret again:**
   - Access Key ID
   - Secret Access Key

> **Keep them safe:** never commit access keys to git or paste them in chat. To use them on the EC2 instance, see the next section.

## Configure the AWS CLI on your instance

The Amazon Linux 2023 instance already has the AWS CLI installed, so we just need to give it your credentials. The terminal from guide 1 is busy running the Jupyter container, so open a fresh one: in the EC2 console, select your instance and click **Connect** → **Connect** again. Then run:

```bash
aws configure
```

Enter the values when prompted:

1. **AWS Access Key ID**: paste the key you copied.
2. **AWS Secret Access Key**: paste the secret you copied.
3. **Default region name**: `us-west-2`
4. **Default output format**: `json`

## Test access

Before testing, make sure the bucket you want to write results to exists: in the S3 console, click **Create bucket**, name it `cloudbank-showcase-seismology`, and keep the default settings. (The form first asks for a **Bucket namespace** — keep **Global namespace** selected even if the console marks *Account Regional* as (recommended); Global is fine for this tutorial and keeps the `s3://bucket-name` addresses the notebook expects. Leave every other setting at its default.) S3 bucket names are shared across *all* AWS accounts worldwide, so if this one is already taken, add a suffix (for example `cloudbank-showcase-seismology-2`) and use that same name everywhere: in the commands below, in the notebook's `STACK_STORE_PATH` (see the next section), and in the policy JSON at the bottom of this page. Then, in your terminal:

```bash
aws s3 ls
```

You should see the S3 buckets in your account. If you get a permissions error, double-check the user permissions in IAM.

You can also check that you can read the public SCEDC data and write to your own bucket:

```bash
aws s3 ls s3://scedc-pds/FDSNstationXML/CI/ | head
aws s3 ls s3://your-bucket-name
```

> With AWS CLI v2, piping into `head` may print a harmless `aws: [ERROR]: [Errno 32] Broken pipe` message at the end — you can ignore it (or append `2>/dev/null` to the command).

## Point the notebook at your bucket

The notebook's stacking step writes its final results to S3. Set the path when you start the Jupyter container from guide 1 by adding this line to the `docker run` command:

```bash
-e STACK_STORE_PATH=s3://cloudbank-showcase-seismology/noisepy-stacks
```

If the container is already running without it, go to the terminal where Jupyter is running and press **Ctrl+C** to stop it (the container removes itself thanks to `--rm`), then start it again with the extra line. Your files are safe during the restart: they live in `/home/ec2-user` on the instance, not inside the container.

Alternatively, edit the `STACK_STORE_PATH` fallback value inside the notebook itself. Without it, the notebook raises a clear error in the stacking cell telling you to set it.

---

## Least-privilege policy (recommended for real projects)

Instead of `AmazonS3FullAccess`, create a policy with IAM → **Policies** → **Create policy** → **JSON** that allows only what is needed: read the public `scedc-pds` bucket, and read/write your own project bucket (`cloudbank-showcase-seismology` in this tutorial):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListBuckets",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": [
                "arn:aws:s3:::scedc-pds",
                "arn:aws:s3:::cloudbank-showcase-seismology"
            ]
        },
        {
            "Sid": "ReadSCEDCObjects",
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::scedc-pds/*"
        },
        {
            "Sid": "ReadWriteProjectObjects",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::cloudbank-showcase-seismology/*"
        }
    ]
}
```

Name it `s3-seismology-tutorial-access` and attach it to the user (Add permissions → Attach policies directly).

> **Note:** with this policy, plain `aws s3 ls` (which lists *all* buckets in the account) returns an error, because it requires the separate `s3:ListAllMyBuckets` permission, which we intentionally did not grant. To test your access, use the bucket-specific commands from the "Test access" section instead:
>
> ```bash
> aws s3 ls s3://cloudbank-showcase-seismology
> aws s3 ls s3://scedc-pds/FDSNstationXML/CI/ | head
> ```
