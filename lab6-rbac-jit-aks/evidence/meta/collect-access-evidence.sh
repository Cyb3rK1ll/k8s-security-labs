#!/bin/bash
set -e

EVIDENCE_DIR="./evidence/lab6-access-tests"
mkdir -p "$EVIDENCE_DIR"

echo "Collecting access evidence for AKS RBAC + PIM..."

PHASE=${1:-"phase1-userrole"}
OUTFILE="$EVIDENCE_DIR/${PHASE}.txt"

echo "## Current User" > "$OUTFILE"
az account show --query "{user:user.name, subscription:id}" -o yaml >> "$OUTFILE" || echo "az account show failed" >> "$OUTFILE"

echo -e "\n## Who am I (Kubernetes)" >> "$OUTFILE"
kubectl auth whoami >> "$OUTFILE" 2>&1

echo -e "\n## Can I do basic actions?" >> "$OUTFILE"
for ACTION in "get pods" "create pods" "delete pods" "create ns" "get ns"; do
  echo "\n$ kubectl auth can-i $ACTION" >> "$OUTFILE"
  kubectl auth can-i $ACTION >> "$OUTFILE" 2>&1
done

echo -e "\n## Try creating a pod (attack test)" >> "$OUTFILE"
cat <<EOF | kubectl apply -f - >> "$OUTFILE" 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: test-access
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "echo Hello from AKS RBAC && sleep 3600"]
EOF

echo -e "\n## Pods list (default namespace)" >> "$OUTFILE"
kubectl get pods -n default >> "$OUTFILE" 2>&1 || true

echo -e "\n## Done. Evidence stored in $OUTFILE"