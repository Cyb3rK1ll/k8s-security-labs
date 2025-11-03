#!/bin/bash

EVIDENCE_DIR="./evidence"
GATEKEEPER_NS="gatekeeper-system"

mkdir -p "$EVIDENCE_DIR"

echo "Recolectando evidencia..."

# Gatekeeper audit logs
kubectl logs -n $GATEKEEPER_NS -l app.kubernetes.io/name=gatekeeper > "$EVIDENCE_DIR/gatekeeper-audit.log"

# kubectl apply error
kubectl apply -f attack/malicious-pod.yaml 2> "$EVIDENCE_DIR/kubectl-apply-error.txt" || true

# Pods
kubectl get pods -A -o wide > "$EVIDENCE_DIR/pods.txt"

# Helm values
helm get values gatekeeper -n $GATEKEEPER_NS > "$EVIDENCE_DIR/helm-values.yaml"

echo "EVIDENCE COLLECTED"

echo "## Gatekeeper Audit Summary" > report.md
kubectl get constraints -o custom-columns=NAME:.metadata.name,VIOLATIONS:.status.totalViolations >> report.md