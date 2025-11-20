# FL xApp Deployment Guide

This document describes two deployment methods for the FL xApp:
1. **O-RAN SC Official Onboarding** (recommended for production)
2. **Direct Kubernetes Deployment** (for development and testing)

## Table of Contents

- [Prerequisites](#prerequisites)
- [Method 1: O-RAN SC Official Onboarding](#method-1-oran-sc-official-onboarding)
- [Method 2: Direct Kubernetes Deployment](#method-2-direct-kubernetes-deployment)
- [Post-Deployment Verification](#post-deployment-verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Common Requirements

- Kubernetes 1.24+ cluster
- kubectl configured and connected
- Minimum 4 CPU cores, 8GB RAM available
- Storage class for PVC (5GB required)

### For GPU Deployment

- NVIDIA GPU (Compute Capability 7.0+)
- NVIDIA Driver 470+
- nvidia-docker2 installed
- NVIDIA Device Plugin for Kubernetes

Run GPU setup if needed:
```bash
./scripts/setup-gpu.sh
```

### For O-RAN SC Onboarding Method

- O-RAN RIC Platform deployed
- xApp Onboarder service running
- Chart Museum accessible
- App Manager (appmgr) running

## Method 1: O-RAN SC Official Onboarding

This is the **recommended** method for production deployments. It provides full lifecycle management through the RIC Platform.

### Architecture

```
Docker Image → Chart Museum → xApp Onboarder → App Manager → Deployment
```

### Step 1: Build and Push Image

```bash
# Build image
./scripts/build.sh gpu  # or 'cpu' for CPU version

# Tag for O-RAN SC registry
docker tag localhost:5000/fl-xapp:1.0.0-gpu \
    nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-fl:1.0.0

# Push to registry
docker push nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-fl:1.0.0
```

### Step 2: Onboard the xApp

```bash
# Using onboard script
./scripts/onboard.sh onboard

# Or manually with curl
curl -X POST http://appmgr-service.ricplt:8080/api/v1/onboard/download \
  -H "Content-Type: application/json" \
  -d @xapp-descriptor.json
```

Expected output:
```json
{
  "status": "success",
  "message": "xApp onboarded successfully",
  "name": "federated-learning",
  "version": "1.0.0"
}
```

### Step 3: Install the xApp

```bash
# Using onboard script
./scripts/onboard.sh install

# Or with App Manager API
curl -X POST http://appmgr-service.ricplt:8080/api/v1/xapps \
  -H "Content-Type: application/json" \
  -d '{"name":"federated-learning","version":"1.0.0"}'
```

### Step 4: Verify Installation

```bash
# Check xApp status
./scripts/onboard.sh status

# Or via App Manager
curl http://appmgr-service.ricplt:8080/api/v1/xapps/federated-learning
```

### Step 5: Check Deployment

```bash
kubectl get pods -n ricxapp -l app=federated-learning
kubectl logs -n ricxapp -l app=federated-learning -f
```

### Lifecycle Management

**Upgrade:**
```bash
# Update version in xapp-descriptor.json
# Rebuild and push image
./scripts/build.sh gpu --push

# Upgrade xApp
./scripts/onboard.sh upgrade
```

**Delete:**
```bash
./scripts/onboard.sh delete
```

## Method 2: Direct Kubernetes Deployment

This method is suitable for **development, testing, and standalone deployments**.

### Architecture

```
Docker Image → Kubernetes Manifests → Direct Deployment
```

### Quick Start

```bash
# Build image
./scripts/build.sh gpu  # or 'cpu' or 'both'

# Deploy (auto-detects GPU)
./scripts/deploy.sh auto --wait

# Or specify variant
./scripts/deploy.sh gpu --wait
```

### Detailed Steps

#### Step 1: Build Image

```bash
# CPU version
./scripts/build.sh cpu

# GPU version
./scripts/build.sh gpu

# Both versions
./scripts/build.sh both
```

#### Step 2: Verify Image

```bash
docker images | grep fl-xapp
```

Expected output:
```
localhost:5000/fl-xapp   1.0.0      abc123   5 minutes ago   3.2GB
localhost:5000/fl-xapp   1.0.0-gpu  def456   3 minutes ago   8.1GB
```

#### Step 3: Create Namespace

```bash
kubectl create namespace ricxapp
```

#### Step 4: Deploy Resources

**Option A: Using deployment script**
```bash
# Auto-detect GPU
./scripts/deploy.sh auto --wait

# Force CPU
./scripts/deploy.sh cpu --wait

# Force GPU
./scripts/deploy.sh gpu --wait
```

**Option B: Manual deployment**
```bash
# Apply manifests
kubectl apply -f deploy/kubernetes/configmap.yaml -n ricxapp
kubectl apply -f deploy/kubernetes/pvc.yaml -n ricxapp
kubectl apply -f deploy/kubernetes/serviceaccount.yaml -n ricxapp

# Choose deployment based on hardware
kubectl apply -f deploy/kubernetes/deployment-gpu.yaml -n ricxapp  # GPU
# OR
kubectl apply -f deploy/kubernetes/deployment.yaml -n ricxapp      # CPU

kubectl apply -f deploy/kubernetes/service.yaml -n ricxapp
```

#### Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -n ricxapp -l app=federated-learning

# Check logs
kubectl logs -n ricxapp -l app=federated-learning -f

# Run health checks
./scripts/test.sh health
```

### Customization

#### Modify Resources

Edit `deploy/kubernetes/deployment.yaml` or `deployment-gpu.yaml`:

```yaml
resources:
  requests:
    cpu: "2000m"           # Adjust CPU
    memory: "4Gi"          # Adjust memory
    nvidia.com/gpu: "1"    # GPU count
  limits:
    cpu: "8000m"
    memory: "12Gi"
    nvidia.com/gpu: "1"
```

#### Modify FL Configuration

Edit `config/config.json`:

```json
{
  "fl_config": {
    "min_clients": 3,
    "max_clients": 100,
    "rounds": 100,
    "aggregation_method": "fedavg"
  }
}
```

Then update ConfigMap:
```bash
kubectl create configmap federated-learning-config \
  --from-file=config/config.json \
  --dry-run=client -o yaml | kubectl apply -n ricxapp -f -
```

#### Restart Deployment

```bash
kubectl rollout restart deployment/federated-learning -n ricxapp
kubectl rollout status deployment/federated-learning -n ricxapp
```

## Post-Deployment Verification

### 1. Check Pod Status

```bash
kubectl get pods -n ricxapp -l app=federated-learning
```

Expected:
```
NAME                                   READY   STATUS    RESTARTS   AGE
federated-learning-7d9f8c6b5d-x7z2m   1/1     Running   0          2m
```

### 2. Check Logs

```bash
kubectl logs -n ricxapp -l app=federated-learning --tail=50
```

Look for:
```
[INFO] FL xApp started successfully
[INFO] RMR initialized on port 4590
[INFO] REST API listening on port 8110
[INFO] GPU detected: True  (or False for CPU)
```

### 3. Test Health Endpoints

```bash
POD_NAME=$(kubectl get pod -n ricxapp -l app=federated-learning -o jsonpath='{.items[0].metadata.name}')

# Liveness
kubectl exec -n ricxapp $POD_NAME -- curl -s http://localhost:8110/health/alive

# Readiness
kubectl exec -n ricxapp $POD_NAME -- curl -s http://localhost:8110/health/ready

# FL Status
kubectl exec -n ricxapp $POD_NAME -- curl -s http://localhost:8110/fl/status | jq
```

### 4. Check GPU (if applicable)

```bash
kubectl exec -n ricxapp $POD_NAME -- python3 -c \
  "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

### 5. Check Metrics

```bash
kubectl exec -n ricxapp $POD_NAME -- curl -s http://localhost:8110/ric/v1/metrics | grep fl_
```

### 6. Run Automated Tests

```bash
./scripts/test.sh health
```

## Comparison: Onboarding vs Direct Deployment

| Aspect | O-RAN SC Onboarding | Direct Kubernetes |
|--------|---------------------|-------------------|
| **Complexity** | Higher (requires RIC Platform) | Lower (standalone) |
| **Use Case** | Production, full RIC | Development, testing |
| **Lifecycle** | Full management (install/upgrade/delete) | Manual |
| **Integration** | Complete RIC integration | Standalone |
| **Standards** | O-RAN compliant | Kubernetes native |
| **Setup Time** | 30-60 minutes | 5-10 minutes |
| **Dependencies** | RIC Platform, Onboarder, AppMgr | Only Kubernetes |

## Troubleshooting

### Issue: Pod stuck in Pending

**Symptoms:**
```bash
NAME                                   READY   STATUS    RESTARTS   AGE
federated-learning-7d9f8c6b5d-x7z2m   0/1     Pending   0          5m
```

**Solutions:**

1. Check node resources:
```bash
kubectl describe node | grep -A 5 "Allocated resources"
```

2. Check GPU availability (if using GPU deployment):
```bash
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
```

3. Check PVC status:
```bash
kubectl get pvc -n ricxapp
```

### Issue: Pod CrashLoopBackOff

**Symptoms:**
```bash
NAME                                   READY   STATUS             RESTARTS   AGE
federated-learning-7d9f8c6b5d-x7z2m   0/1     CrashLoopBackOff   5          3m
```

**Solutions:**

1. Check logs:
```bash
kubectl logs -n ricxapp $POD_NAME --previous
```

2. Check configuration:
```bash
kubectl get configmap federated-learning-config -n ricxapp -o yaml
```

3. Verify image:
```bash
kubectl describe pod -n ricxapp $POD_NAME | grep Image
```

### Issue: GPU not detected

**Symptoms:**
```
[INFO] GPU detected: False
```

**Solutions:**

1. Check NVIDIA Device Plugin:
```bash
kubectl get daemonset -n kube-system | grep nvidia
```

2. Check RuntimeClass:
```bash
kubectl get runtimeclass nvidia
```

3. Run GPU setup:
```bash
./scripts/setup-gpu.sh
```

### Issue: xApp Onboarding fails

**Symptoms:**
```json
{
  "status": "error",
  "message": "Failed to onboard xApp"
}
```

**Solutions:**

1. Check Onboarder connectivity:
```bash
curl http://appmgr-service.ricplt:8080/health
```

2. Verify descriptor:
```bash
jq empty xapp-descriptor.json
```

3. Check image availability:
```bash
docker pull nexus3.o-ran-sc.org:10002/o-ran-sc/ric-app-fl:1.0.0
```

## Next Steps

- [Configuration Guide](CONFIGURATION.md)
- [API Documentation](API.md)
- [Monitoring Setup](MONITORING.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

## References

- [O-RAN SC xApp Onboarding Documentation](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-plt-appmgr/en/latest/user-guide.html)
- [RIC Platform Documentation](https://docs.o-ran-sc.org/projects/o-ran-sc-ric-plt-ric-dep/en/latest/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
