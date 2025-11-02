#!/bin/bash

EVIDENCE_DIR="./evidence"
FALCO_NS="falco"
NAMESPACE="default"
FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

mkdir -p "$EVIDENCE_DIR"

echo "Gathering evidence..."

kubectl logs "$FALCO_POD" -n falco > "$EVIDENCE_DIR/falco.log"
kubectl get networkpolicy -n default -o yaml > "$EVIDENCE_DIR/networkpolicy.yaml"
kubectl get pods -A -o wide > "$EVIDENCE_DIR/pods.txt"
kubectl get cm falco-custom-rules -n falco -o yaml > "$EVIDENCE_DIR/falco-custom-rules.yaml"
helm get values falco -n falco > "$EVIDENCE_DIR/helm-values.yaml"
cp attack/lateral-move.log "$EVIDENCE_DIR/lateral-move.log"