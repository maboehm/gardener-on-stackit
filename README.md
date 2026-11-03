# Gardener on STACKIT

This repository sets up [Gardener](https://gardener.cloud) on STACKIT: a managed Kubernetes cluster (SKE) acts as the runtime for a Gardener "garden", which can then host a seed and create shoot clusters on STACKIT.

1. Create a SKE Cluster
2. Install gardener-operator via helm
3. Create a `garden`
4. Setup gardenctl
5. Turn this cluster into a seed
6. Run your first shoot

## Setup

The steps below build the stack in layers: infrastructure with Terraform, the Gardener operator, the garden and its providers, then the seed and the first shoot. Each step's manifests are in a numbered directory under [`manifests/`](manifests/), applied in order.

### 0. Configure Terraform

Terraform in [`terraform/`](terraform/) creates the SKE cluster and kubeconfig, DNS zone, backup bucket and S3 credentials, and the Gardener service account and project role assignment. It writes the values needed by the remaining steps to `.env`, and writes the credentials to the files consumed by the manifests.

Create a service account to use for terraform:

```bash
stackit config set --project-id "<STACKIT project ID>"
email=$(stackit service-account create --name terraform -oyaml -y | yq .email)
stackit project member add "$email" --role owner -y
sleep 5
stackit service-account key create --email "$email" --expires-in-days 7 -ojson -y > serviceaccount.json
export STACKIT_SERVICE_ACCOUNT_KEY_PATH="$(pwd)/serviceaccount.json"
```

Set the required project and ACME email variables, and authenticate the STACKIT Terraform provider using your STACKIT credentials:

```bash
export TF_VAR_project_id="<STACKIT project ID>"
export TF_VAR_acme_email="some.user@example.com"
```

Terraform reads the project's `cloud.stackit.iaas` service configuration using a STACKIT access token and exports its OpenStack project ID as `OPENSTACK_PROJECT_ID` in `.env` (also available as the `openstack_project_id` Terraform output).

### 1. Create infrastructure

```bash
terraform init
terraform apply
```

Cluster creation can take around 10 minutes.

Terraform writes `.env`, `kubeconfig`, `manifests/00-providers/backup-s3-credentials.env`, and `manifests/00-providers/serviceaccount.json`. These files and the Terraform state contain credentials; keep them private and do not commit them. The state should be stored securely.

Before running the following commands, load the generated constants into your shell:

```bash
source .env
```

### 2. Install gardener-operator via helm

This installs the Gardener operator into the `garden` namespace of the SKE cluster. The operator watches `Garden` resources and reconciles the virtual garden control plane (API server, etcd, controller manager) that they describe.

```bash
helm upgrade --install \
    gardener-operator oci://europe-docker.pkg.dev/gardener-project/releases/charts/gardener/operator:"${GARDENER_VERSION}" \
    --namespace garden --create-namespace \
    --wait
```

### 3. Setup Garden

The first command applies `manifests/00-providers`, which registers the Gardener extensions for STACKIT: the provider extension (infrastructure, control plane, workers, DNS, bastion), the S3 backup extension for etcd and shoot backups, and the cert service that issues TLS certificates via Let's Encrypt. The second command applies `manifests/10-garden`, which creates the `Garden` resource itself: a virtual garden with etcd backed up to S3, the Gardener dashboard configuration, and an ingress on `gardener.${DOMAIN}` and `virtual-garden.${DOMAIN}`.

```bash
kubectl kustomize manifests/00-providers | flux envsubst | kubectl apply --server-side -f -
kubectl kustomize manifests/10-garden | flux envsubst | kubectl apply --server-side -f -
```

### 4. Setup gardenctl & access dashboard

This step extracts the garden's kubeconfig and registers the garden with `gardenctl`, the CLI for working with gardens, projects, and shoots. It also creates a `dashboard-user` service account with cluster-admin rights and prints a 24-hour token for logging in to the Gardener dashboard.

```bash
kubectl get secret -n garden gardener -o jsonpath='{.data.kubeconfig}' | base64 --decode > garden-kubeconfig
export KUBECONFIG="$(pwd)/garden-kubeconfig"
CLUSTER_IDENTITY=$(kubectl -n kube-system get configmap cluster-identity -ojsonpath={.data.cluster-identity})
gardenctl config set-garden $CLUSTER_IDENTITY --kubeconfig $KUBECONFIG
```

In a "real" environment, you would probably connect to the dashboard using a proper identity provider and have RBAC configured for different users and groups.

```bash
export KUBECONFIG="$(pwd)/garden-kubeconfig" 
kubectl -n garden create serviceaccount dashboard-user --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding dashboard-user-cluster-admin --clusterrole=cluster-admin --serviceaccount=garden:dashboard-user --dry-run=client -o yaml | kubectl apply -f -
kubectl -n garden create token dashboard-user --duration 24h | pbcopy
open "https://dashboard.gardener.${DOMAIN}"
```

### 5. Turn this cluster into a seed

This applies a `Gardenlet` resource from `manifests/20-seed`, which deploys a gardenlet into the SKE cluster and registers it as a seed. The seed is where shoot control planes run, and it is configured with the STACKIT DNS provider, the S3 backup bucket, the `internal.${DOMAIN}` ingress domain, and the zones of the `${REGION}` region.

```bash
export KUBECONFIG="$(pwd)/garden-kubeconfig" 
kubectl kustomize manifests/20-seed --load-restrictor LoadRestrictionsNone | flux envsubst | kubectl apply --server-side -f -
```

### 6. Getting ready to accept the first shoot

The `31-cloudprofile` manifest defines a `CloudProfile` named `stackit` that lists the Kubernetes versions, machine images (Flatcar and Ubuntu), machine types, regions, zones, and volume types that shoots may use. The `32-extensions` manifests install the Calico networking extension and the Flatcar OS configuration extension that shoot nodes need.

```bash
export KUBECONFIG="$(pwd)/garden-kubeconfig"
kubectl kustomize manifests/31-cloudprofile --load-restrictor LoadRestrictionsNone | flux envsubst | kubectl apply --server-side -f -

export KUBECONFIG="$(pwd)/kubeconfig"
kubectl kustomize manifests/32-extensions | flux envsubst | kubectl apply --server-side -f -
```

Create the project manually, use these values:

```bash
echo $PROJECT_ID | pbcopy
cat manifests/00-providers/serviceaccount.json | pbcopy
```

## Useful commands

### Get observability secret

This copies the password for the observability ingress, which protects the Plutono (Grafana-based) dashboards for the garden, to the clipboard. It then opens the dashboards in your browser using the hostname from the `virtual-garden-plutono-garden` virtual service.

```bash
kubectl get secret -n garden -l name=observability-ingress -o jsonpath='{.items[].data.password}' | base64 -d | pbcopy
open "https://$(kubectl get virtualservice -n garden virtual-garden-plutono-garden -o jsonpath='{.spec.hosts[0]}')"

```

### Get the admin kubeconfig of a shoot

Request an admin kubeconfig for the shoot from the garden cluster and store it in `shoot-kubeconfig`. The credential is valid for 24 hours.

```bash
export KUBECONFIG="$(pwd)/garden-kubeconfig"
SHOOT_NAMESPACE=garden-demo
SHOOT_NAME=worky
kubectl create --raw "/apis/core.gardener.cloud/v1beta1/namespaces/${SHOOT_NAMESPACE}/shoots/${SHOOT_NAME}/adminkubeconfig" -f - <<EOF | yq -r .status.kubeconfig | base64 --decode > shoot-kubeconfig
{"apiVersion":"authentication.gardener.cloud/v1alpha1","kind":"AdminKubeconfigRequest","spec":{"expirationSeconds":86400}}
EOF
chmod 600 shoot-kubeconfig

kubectl --kubeconfig shoot-kubeconfig get nodes
```
