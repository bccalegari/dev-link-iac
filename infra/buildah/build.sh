#!/bin/bash
set -e

# ----------------------
# Configuration
# ----------------------
NAMESPACE="devlink"
PVC_NAME="buildah-context-pvc"
POD_COPY="copy-context"
JOB_NAME="build-images"
ACTUAL_PATH=$(pwd)
ENV_FILE="$ACTUAL_PATH/../../.env"

# ----------------------
# Load environment variables from .env file
# ----------------------
if [ ! -f "$ENV_FILE" ]; then
  echo ".env file not found at $ENV_FILE"
  exit 1
fi

# Export all variables in .env to environment
set -a
source "$ENV_FILE"
set +a

# ----------------------
# Validate required registry credentials
# ----------------------
for var in REGISTRY_USER REGISTRY_PASS; do
  if [ -z "${!var}" ]; then
    echo "$var must be set in .env"
    exit 1
  fi
done

# ----------------------
# Create PersistentVolumeClaim
# ----------------------
echo "Creating PVC..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# ----------------------
# Create temporary pod to copy context files
# ----------------------
echo "Creating temporary pod..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $POD_COPY
  namespace: $NAMESPACE
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep","3600"]
    volumeMounts:
    - name: buildah-context
      mountPath: /context
  volumes:
  - name: buildah-context
    persistentVolumeClaim:
      claimName: $PVC_NAME
EOF

# ----------------------
# Wait for the pod to exist
# ----------------------
echo "Waiting for temporary pod to exist..."
for i in {1..30}; do
    kubectl get pod $POD_COPY -n $NAMESPACE >/dev/null 2>&1 && break
    sleep 2
done

# ----------------------
# Wait for container to be ready
# ----------------------
echo "Waiting for temporary pod to be ready..."
for i in {1..30}; do
    STATUS=$(kubectl get pod $POD_COPY -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')
    if [ "$STATUS" == "true" ]; then
        break
    fi
    sleep 2
done

# ----------------------
# Set paths for Terraform-K8S and Jenkins contexts
# ----------------------
TERRAFORM_K8S_PATH=$(realpath ../terraform-k8s)
JENKINS_PATH=$(realpath ../jenkins)

# ----------------------
# Copy context files into pod
# ----------------------
echo "Copying context files into PVC..."
cd "$TERRAFORM_K8S_PATH" && kubectl cp Dockerfile $POD_COPY:/context/terraform-k8s/ -c busybox -n $NAMESPACE
cd "$JENKINS_PATH" && kubectl cp . $POD_COPY:/context/jenkins/ -c busybox -n $NAMESPACE
cd "$ACTUAL_PATH"

# ----------------------
# Delete temporary pod
# ----------------------
echo "Deleting temporary pod..."
kubectl delete pod $POD_COPY -n $NAMESPACE

# ----------------------
# Delete existing Buildah Job if present
# ----------------------
kubectl delete job $JOB_NAME -n $NAMESPACE --ignore-not-found

# ----------------------
# Create Buildah Job to build and push images
# ----------------------
echo "Creating Buildah Job..."
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NAMESPACE
spec:
  backoffLimit: 3 
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: buildah
        image: quay.io/buildah/stable:v1.42.2
        securityContext:
            runAsUser: 0
            privileged: true
        command: ["/bin/sh","-c"]
        args:
          - |
            set -e
            echo "Starting Buildah Job..."
            echo "Logging into local registry..."
            stdbuf -oL -eL buildah login -u $REGISTRY_USER -p $REGISTRY_PASS --tls-verify=false registry.devlink.svc.cluster.local:5000

            echo "Building Terraform-K8s image..."
            stdbuf -oL -eL buildah bud -t registry.devlink.svc.cluster.local:5000/terraform-k8s:latest /context/terraform-k8s

            echo "Building Devlink Jenkins image..."
            stdbuf -oL -eL buildah bud -t registry.devlink.svc.cluster.local:5000/devlink-jenkins:latest /context/jenkins

            echo "Pushing Terraform-K8s image..."
            stdbuf -oL -eL buildah push --tls-verify=false registry.devlink.svc.cluster.local:5000/terraform-k8s:latest

            echo "Pushing Devlink Jenkins image..."
            stdbuf -oL -eL buildah push --tls-verify=false registry.devlink.svc.cluster.local:5000/devlink-jenkins:latest

            echo "Buildah Job completed successfully."
        volumeMounts:
        - name: buildah-context
          mountPath: /context
      volumes:
      - name: buildah-context
        persistentVolumeClaim:
          claimName: $PVC_NAME
EOF

# ----------------------
# Wait for the pod to exist
# ----------------------
for i in {1..30}; do
    JOB_POD=$(kubectl get pods -n $NAMESPACE -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    [ -n "$JOB_POD" ] && break
    sleep 2
done

# ----------------------
# Wait for the container to be running
# ----------------------
for i in {1..60}; do
    STATUS=$(kubectl get pod $JOB_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$STATUS" == "Running" ]; then
        break
    fi
    echo "Pod is $STATUS, waiting..."
    sleep 2
done

# ----------------------
# Now stream logs
# ----------------------
kubectl logs -n $NAMESPACE -f $JOB_POD -c buildah

# ----------------------
# Wait for Job to complete
# ----------------------
set +e
kubectl wait --for=condition=complete job/$JOB_NAME -n $NAMESPACE --timeout=600s
STATUS=$?
set -e

# ----------------------
# Decide whether to cleanup 
# ----------------------
if [ $STATUS -eq 0 ]; then
    echo "Job succeeded, cleaning up..."
    kubectl delete job $JOB_NAME -n $NAMESPACE
    kubectl delete pvc $PVC_NAME -n $NAMESPACE
else
    echo "Job failed or timed out, leaving Job and PVC for debugging."
    echo "Use: kubectl logs -n $NAMESPACE -l job-name=$JOB_NAME"
fi