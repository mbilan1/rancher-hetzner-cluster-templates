# Usage Guide — Hetzner RKE2 Cluster Template

## Prerequisites

Before using this template, ensure:

1. **Rancher management cluster** is running (`terraform-hcloud-rancher` applied)
2. **Hetzner Node Driver** is installed (done automatically by `terraform-hcloud-rancher`)
3. **Cloud Credential** created in Rancher for the downstream Hetzner Project

## Step 1: Register the Chart Repository

In Rancher UI:

1. Navigate to **Cluster Management → Advanced → Repositories**
2. Click **Create**
3. Fill in:
   - **Name**: `hetzner-templates`
   - **Target**: Git Repository
   - **Git Repo URL**: `https://github.com/mbilan1/rancher-hetzner-cluster-templates.git`
   - **Branch**: `main`
4. Click **Create**

Or via CLI:

```bash
helm repo add hetzner-templates \
  https://raw.githubusercontent.com/mbilan1/rancher-hetzner-cluster-templates/main
helm repo update
```

## Step 2: Register the Hetzner Helm Repository (for CCM/CSI)

The ManagedCharts for CCM and CSI reference a `ClusterRepo` named `hcloud`.

In Rancher UI:

1. Navigate to **Cluster Management → Advanced → Repositories**
2. Click **Create**
3. Fill in:
   - **Name**: `hcloud`
   - **Target**: HTTP(S)
   - **Index URL**: `https://charts.hetzner.cloud`
4. Click **Create**

## Step 3: Create a Cloud Credential

1. Navigate to **Cluster Management → Cloud Credentials**
2. Click **Create**
3. Select **Hetzner**
4. Enter the `HCLOUD_TOKEN` for the downstream project's Hetzner Cloud Project
5. Name it descriptively (e.g., `downstream-project-a`)

> **IMPORTANT**: Each downstream cluster should use a token scoped to its own
> Hetzner Cloud Project for isolation. See ADR in `rke2-hetzner-architecture`.

## Step 3b: Build a CIS-Hardened Node Image (Optional)

If you want CIS Level 1 hardened nodes, build a node image with Packer **before** creating the cluster.

> **Why Packer?** CIS host prerequisites (etcd user, sysctl, kernel modules) must exist
> before RKE2 starts. Rancher's machine driver intercepts the userData field, so cloud-init
> cannot deliver these settings. A pre-baked Hetzner snapshot is the only reliable method.

### Build the image

```bash
cd packer-hcloud-rke2/

# Use the SAME Hetzner token as the Cloud Credential (same project)
export HCLOUD_TOKEN="<downstream-project-token>"

packer build -var "hcloud_token=$HCLOUD_TOKEN" -var enable_cis_hardening=true .
# Output: A snapshot was created: 'ubuntu2404-rke2-v1324-cis-l1-...' (ID: 555666)
```

Note the **snapshot ID** (e.g. `555666`) from the output. You will enter this in the Rancher UI form.

> **Snapshots are project-scoped.** A snapshot built with Project A's token is only visible
> to servers created with Project A's token. If you have multiple downstream Hetzner projects,
> run `packer build` once per project with each project's token.

### Without CIS hardening

Skip this step entirely. The cluster template defaults to `ubuntu-24.04` (Hetzner stock image).

## Step 4: Create a Downstream Cluster

1. Navigate to **Cluster Management → Clusters**
2. Click **Create**
3. Under **RKE2/K3s**, select **hetzner-rke2-cluster-template**
4. Fill in the form:
   - **Cluster Name**: e.g., `production-a`
   - **Cloud Credential**: select the credential from Step 3
   - **Kubernetes Version**: default is fine
   - **Network**: enter the management network name/ID (from `tofu output network_id`)
   - **Machine Image**: enter the Packer snapshot ID from Step 3b (e.g. `555666`), or leave as `ubuntu-24.04` for stock image
   - **Node Pool**: configure server type, location, count
5. Click **Create**

Rancher will provision the servers via the Hetzner API and install RKE2.

## Step 5: Post-Provisioning — Create HCLOUD_TOKEN Secret

After the downstream cluster is provisioned and shows "Active" in Rancher:

```bash
# Switch kubectl context to the downstream cluster (via Rancher UI → Download KubeConfig)

# Create the HCLOUD_TOKEN secret for CCM and CSI
kubectl -n kube-system create secret generic hcloud \
  --from-literal=token=<DOWNSTREAM_PROJECT_HCLOUD_TOKEN> \
  --from-literal=network=<NETWORK_NAME_OR_ID>
```

> **Why manual?** Rancher Cloud Credentials are stored encrypted in the management
> cluster's etcd. They are NOT automatically synced as Kubernetes Secrets to
> downstream clusters. The CCM and CSI Helm charts expect a `hcloud` secret in
> `kube-system` namespace. This is documented as an open item in DES-001.

## Step 6: Verify

After a few minutes, check that CCM is running:

```bash
kubectl -n kube-system get pods | grep hcloud
# Expected: hcloud-cloud-controller-manager-xxxxx Running
```

> **Note**: CSI is NOT managed by this chart. Operators deploy Hetzner CSI, Longhorn,
> or Rook-Ceph separately. See the chart's `values.yaml` for details.

Verify LB integration:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: test-lb
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: test
EOF

kubectl get svc test-lb
# EXTERNAL-IP should be assigned by Hetzner LB
kubectl delete svc test-lb
```

## CLI Installation (Alternative)

```bash
helm install my-cluster ./charts \
  --namespace fleet-default \
  --set cluster.name=my-cluster \
  --set cloudCredentialSecretName=cattle-global-data:cc-xxxxx \
  --set hetzner.network=my-network \
  --set nodepools[0].serverType=cx33 \
  --set nodepools[0].serverLocation=nbg1 \
  --set nodepools[0].quantity=3
```

## Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Hetzner Private Network (10.0.0.0/16)                  │
│                                                         │
│  ┌───────────────┐    ┌───────────────┐                │
│  │ Management    │    │ Downstream A  │                │
│  │ Cluster       │    │ (Rancher-     │                │
│  │ (Rancher)     │    │  provisioned) │                │
│  │ 10.0.1.x      │    │ 10.0.x.x      │                │
│  └───────────────┘    └───────────────┘                │
│                                                         │
│  Token: MGMT_TOKEN     Token: PROJECT_A_TOKEN          │
│  (Terraform)           (Rancher Cloud Credential)      │
└─────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Cluster stuck in "Provisioning"

- Check Cloud Credential is valid (`hcloud server list` with the token)
- Check server type is available in the selected location
- Check Hetzner API rate limits (visible in Hetzner Cloud Console)

### CCM/CSI pods not starting

- Verify `hcloud` ClusterRepo is registered (Step 2)
- Verify `hcloud` secret exists in `kube-system` (Step 5)
- Check ManagedChart status: `kubectl -n fleet-default get managedchart`

### Nodes not joining the private network

- Verify `hetzner.network` value matches the management cluster's network
- Verify `usePrivateNetwork: true` in values
- Check Hetzner Cloud Console → Networks → Servers tab
