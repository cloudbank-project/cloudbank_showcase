# 1 - Access CloudBank and Google Cloud Console

Goal: log in to the CloudBank portal with your ACCESS CI identity, use CloudBank's federated login to land in the Google Cloud Console for your CloudBank-assigned project, and create a GKE Autopilot cluster that will automatically scale nodes based on workload needs.

## Prerequisites
- An ACCESS CI account with Duo two-factor authentication. This is the identity provider (IdP) you use to log in to CloudBank. You do **not** sign in to Google at any point: CloudBank bridges your ACCESS CI identity to a CloudBank-managed Google account server-side.
- A desktop browser in a normal window (not Incognito). CloudBank's federated login needs a persistent browsing session across several redirects. If you happen to be signed in to a personal Google account, it does not interfere: CloudBank's SAML proxy always uses your ACCESS CI identity, so no Google account is selected or needed.

## Login to CloudBank and the Google Cloud Console
1) Open the CloudBank portal login page: https://www.cloudbank.org/user/login
2) Click **Log in with CILogon**.
3) On the CILogon identity provider selection page, choose **ACCESS CI (XSEDE)** and continue. You land on the ACCESS CI login page (`idp.access-ci.org`); log in with your ACCESS CI username and approve the Duo push on your phone.
4) Open https://www.cloudbank.org/billing-account-access. You now see a table with an **Amazon Web Services** row and a **Google Cloud Platform** row, listing your assigned billing account and cloud user. If instead you get a Drupal "Access Denied" page, you are not logged in: return to step 1 and complete the CILogon sign-in first.
5) Click the **Login** link in the **Google Cloud Platform** row. It goes to the CloudBank SAML proxy, e.g. `https://federation-proxy.cloudbank.org/gcp?project=<your-project-id>`.
6) On the CILogon page **CloudBank SAML Proxy Production ... Consent to Attribute Release**, choose **ACCESS CI (XSEDE)** again and click **Log On**.
7) You land in the Google Cloud Console with your assigned project active, with no Google account prompt. In the top bar, note the active project ID; we will need it for GKE.
8) Confirm console access by opening `Navigation menu ▸ Kubernetes Engine ▸ Clusters`. You do not need to create anything yet—just verify the page loads without permission errors.

## Create the small GKE cluster
1) On the `Kubernetes Engine ▸ Clusters` page, if an **ENABLE** button is shown, click it to turn on the Kubernetes Engine API, and wait until the page refreshes. If the API is already enabled (no ENABLE button, or the clusters page loads directly), skip this step and continue.
2) Click **CREATE** and stay with **Autopilot** (recommended for simplicity and guardrails). If you prefer full control over node sizes and costs, click **Switch to Standard cluster** instead.
3) **Cluster basics (Autopilot)**:
   - Name: `toy-hydro-cluster` (or another short name).
   - Region: Pick a region close to you from the dropdown menu (e.g., `us-west1`).
4) Leave everything else at defaults and click **Create**.
5) Wait for the cluster status to become **Running** (this can take about 5 minutes). Autopilot handles control plane and worker sizing automatically (roughly one control plane and minimal worker capacity).

## Connect with Cloud Shell
After the cluster is Running, open Cloud Shell by clicking the terminal icon at the very top of the screen labeled **Activate Cloud Shell** (do not use the “Connect” button inside the cluster dashboard). Then run:
```bash
gcloud container clusters get-credentials toy-hydro-cluster --region us-west1
```
Replace the cluster name/region if you used different values. Autopilot launches nodes only when needed, so `kubectl get nodes` here may show none until a workload schedules. Once a workload runs, you will see a node in `Ready` state.

Tip: Cloud Shell includes the Gemini assistant; you can ask it to run `gcloud` and `kubectl` commands on your behalf and parse their output to diagnose problems.

## Verify the cluster with a sample workload
Run these in Cloud Shell to force a node to spin up and confirm scheduling:
```bash
kubectl create deployment hello-autopilot --image=gcr.io/google-samples/hello-app:1.0 --replicas=1
kubectl get pods -w
```
Wait until the pod is `Running` (Autopilot may take a couple of minutes to bring up a node). Then in the same shell:
```bash
kubectl get nodes
```
You should now see node(s) in `Ready` state (Autopilot typically brings up 3 of them):
```
NAME                                         STATUS   ROLES    AGE   VERSION
gk3-toy-hydro-cluster-pool-1-da2ea5bf-kcd6   Ready    <none>   5s    v1.36.4-gke.1495002
```
The node name and GKE patch version above are only an example: on a fresh cluster they will differ (GKE picks its current stable version automatically; a live walkthrough of this tutorial in Oct 2026 observed `v1.36.4-gke.1495002`). What matters is that the nodes are `Ready` (Autopilot hides node roles, so `ROLES` stays `<none>`). Only worker nodes appear here; the control plane in GKE Autopilot is managed by Google and is not exposed as a node.
