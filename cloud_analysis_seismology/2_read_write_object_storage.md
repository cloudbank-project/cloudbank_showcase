
# Tutorial: Creating S3 Access Keys and Configuring AWS CLI

This guide will walk you through creating AWS access keys for S3 read/write and configuring your local environment using `aws configure`.

---

## 1. Create an IAM User with S3 Permissions

1. Log in to the [AWS Management Console](https://console.aws.amazon.com/).
2. Navigate to **IAM** (Identity and Access Management).
3. In the sidebar, click **Users** > **Create user**.
4. Enter a username (e.g., `s3-access-user`).
5. Click **Next**.
6. Attach permissions. Prefer a least-privilege policy scoped to the buckets you actually need. Avoid `AmazonS3FullAccess` unless you truly need administrator-level access. Create a customer-managed policy (IAM → **Policies** → **Create policy** → **JSON**) that grants **read-only** access to the public `scedc-pds` bucket and **read/write** access to your own project bucket, for example:

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
                    "arn:aws:s3:::your-project-bucket"
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
                "Resource": "arn:aws:s3:::your-project-bucket/*"
            }
        ]
    }
    ```

    Replace `your-project-bucket` with the name of the S3 bucket you created to store your stack outputs (see `1_setup_instance.md` / the notebook). Click **Next**, name the policy (e.g., `s3-seismology-tutorial-access`), and **Create policy**. Then go back to the user, **Add permissions** → **Attach policies directly**, and select it.
7. Click **Create user**.
8. Click on the user just created.
9. Under **Security credentials**, click **Create access key**.
10. Select **Command Line Interface (CLI)**, tick the confirmation checkbox, click **Next**, and then **Create access key**.
11. Save the **Access Key ID** and **Secret Access Key**. **You will not be able to see the secret again!**
	- **Important:** Store the keys in a secure secrets manager and never commit them to git. When possible, prefer using an EC2 instance profile/role so you do not need long-lived access keys at all.

---

## 2. Configure AWS CLI with Your Access Keys

> **Note:** On the Amazon Linux 2023 instances used in `1_setup_instance.md`, the AWS CLI v2 is already installed (`aws --version`). No installation step is needed. On other systems, install it from the [AWS CLI docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

Run the following command in your terminal (inside the Jupyter container's mounted home or on the EC2 instance):

```bash
aws configure
```

You will be prompted for:

1. **AWS Access Key ID**: Paste the key you copied earlier.
2. **AWS Secret Access Key**: Paste the secret you copied earlier.
3. **Default region name**: e.g., `us-west-2` (choose the region where your S3 bucket is located).
4. **Default output format**: e.g., `json` (or leave blank).

Your credentials will be saved in `~/.aws/credentials` and configuration in `~/.aws/config`.

---

## 3. Test Your Configuration

List your S3 buckets to verify access:

```bash
aws s3 ls
```

You should see a list of your S3 buckets. If you get a permissions error, check your IAM user permissions.

You can also verify read access to the public SCEDC dataset and write access to your own bucket:

```bash
aws s3 ls s3://scedc-pds/FDSNstationXML/CI/ | head
aws s3 ls s3://your-project-bucket
```

---

> **Security Note:**
>
> Never share your AWS secret access key. Rotate keys regularly and use IAM policies with the least privilege required.
