# k8s-multitier-kind

A multi-tier Kubernetes application running locally with KinD (Kubernetes in Docker), using ArgoCD for GitOps-based continuous deployment, KubeChecks for policy enforcement, and ngrok to expose the cluster externally.

## Architecture

```
Internet
   │
 ngrok
   │
KinD Cluster (localhost:80)
   │
Frontend (Nginx) ── NodePort :30080
   │
Backend (API/Nginx + Redis)
   │
MySQL Database
```

**Stack:**
- **KinD** — local Kubernetes cluster
- **ArgoCD** — GitOps continuous deployment (auto-sync from this repo)
- **KubeChecks** — validates manifests against OPA/Conftest policies before deploy
- **ngrok** — exposes the local cluster to the internet
- **OPA/Conftest** — policy enforcement (e.g., no `:latest` image tags)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) (optional)
- [ngrok](https://ngrok.com/download)

## Running the Project

### 1. Create the KinD cluster

```bash
kind create cluster --config kind/cluster.yaml
```

This creates a single-node cluster with port 80 on your host mapped to NodePort 30080 inside the cluster.

### 2. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for ArgoCD to be ready:

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

### 3. Apply RBAC for KubeChecks

```bash
kubectl apply -f argocd/serviceAccount.yaml
```

### 4. Deploy the ArgoCD Application

```bash
kubectl apply -f argocd/backend-app.yaml
```

ArgoCD will automatically sync the manifests from this repository and deploy the full stack (frontend, backend, MySQL) to the cluster.

### 5. Deploy KubeChecks (optional — for policy enforcement on PRs)

Set up your secrets first:

```bash
# Create the kubechecks secret with your tokens
kubectl create secret generic kubechecks-secret \
  --from-literal=ARGOCD_TOKEN=<your-argocd-token> \
  --from-literal=GITHUB_TOKEN=<your-github-token> \
  -n argocd
```

Then deploy KubeChecks:

```bash
kubectl apply -f kubechecks/kubechecks-final.yaml
```

### 6. Expose the cluster with ngrok

Once the frontend is running on `localhost:80`, expose it publicly:

```bash
ngrok http 80
```

ngrok will output a public URL (e.g., `https://abc123.ngrok.io`) that forwards traffic to your local cluster.

> **Note:** If you need a stable URL for KubeChecks webhooks (GitHub → KubeChecks), configure a static ngrok domain or use `ngrok http --domain=<your-static-domain> 80`.

### 7. Configure the GitHub Webhook (for KubeChecks)

In your GitHub repository settings, add a webhook:
- **Payload URL**: `https://<your-ngrok-url>/api/v1/event`
- **Content type**: `application/json`
- **Events**: Pull requests

## Verifying the Deployment

Check all pods are running:

```bash
kubectl get pods -A
```

Access the frontend:

```bash
# Locally
open http://localhost

# Or via the ngrok URL printed in your terminal
```

Access ArgoCD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
# Default user: admin
# Get password:
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

## Policy Enforcement

All manifests are validated by OPA/Conftest before being deployed. The active policy is:

- **No `:latest` tags** — deployments must use explicit image versions (e.g., `nginx:1.25.3`, not `nginx:latest`).

The policy file lives at `policies/no-latest-tag.rego`. Pull requests that violate policies will be flagged by KubeChecks before merging.

## Project Structure

```
.
├── argocd/                  # ArgoCD Application + RBAC
├── k8s/
│   ├── backend/             # Backend deployment & service
│   ├── frontend/            # Frontend deployment, service & configmap
│   ├── mysql/               # MySQL deployment, service, configmap & secret
│   └── policy/              # OPA policy (also used by conftest locally)
├── kind/                    # KinD cluster configuration
├── kubechecks/              # KubeChecks deployment
└── policies/                # OPA policies for KubeChecks
```

## Teardown

```bash
kind delete cluster
```
