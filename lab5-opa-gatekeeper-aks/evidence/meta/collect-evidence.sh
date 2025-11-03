#!/bin/bash
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
EVIDENCE_DIR="./evidence"
META_DIR="$EVIDENCE_DIR/meta"
LOGS_DIR="$EVIDENCE_DIR/logs"
ATTACK_RESULTS_DIR="$EVIDENCE_DIR/attack-results"
ATTACK_ERRORS_DIR="$ATTACK_RESULTS_DIR/attack-errors"
REPORTS_DIR="$EVIDENCE_DIR/reports"
DIAGRAMS_DIR="$EVIDENCE_DIR/diagrams"
GATEKEEPER_NS="gatekeeper-system"

mkdir -p "$META_DIR" "$LOGS_DIR" "$ATTACK_RESULTS_DIR" "$ATTACK_ERRORS_DIR" "$REPORTS_DIR" "$DIAGRAMS_DIR"

echo "Recolectando evidencia..."

# Gatekeeper audit logs
# Logs del auditor y controladores de Gatekeeper
kubectl logs -n $GATEKEEPER_NS -l control-plane=audit-controller --all-containers > "$LOGS_DIR/gatekeeper-audit.log"
kubectl logs -n $GATEKEEPER_NS -l control-plane=controller-manager --all-containers > "$LOGS_DIR/gatekeeper-controllers.log"

# Save audit summary to a separate file
{
  echo "## 🧩 Gatekeeper Audit Summary"
  echo ""
  echo "| Constraint | Violations |"
  echo "|-------------|------------|"
  kubectl get constraints -o custom-columns=NAME:.metadata.name,VIOLATIONS:.status.totalViolations | tail -n +2 | awk '{print "| " $1 " | " $2 " |"}'
  echo ""
} > "$LOGS_DIR/audit-summary.txt"

# Save violations in JSON format
kubectl get constraints -o json > "$REPORTS_DIR/violations.json"

# Save audit findings in CSV format: name,violations
kubectl get constraints -o custom-columns=NAME:.metadata.name,VIOLATIONS:.status.totalViolations --no-headers | awk 'BEGIN{print "Constraint,Violations"} {print $1","$2}' > "$REPORTS_DIR/audit-findings.csv"

# kubectl apply error
kubectl apply -f attack/malicious-pod.yaml 2> "$META_DIR/kubectl-apply-error.txt" || true

# Pods
kubectl get pods -A -o wide > "$META_DIR/pods.txt"

# Helm values
helm get values gatekeeper -n $GATEKEEPER_NS > "$META_DIR/helm-values.yaml"

echo "EVIDENCE COLLECTED"

{
  echo "## 🧩 Gatekeeper Audit Summary"
  echo ""
  echo "| Constraint | Violations |"
  echo "|-------------|------------|"
  kubectl get constraints -o custom-columns=NAME:.metadata.name,VIOLATIONS:.status.totalViolations | tail -n +2 | awk '{print "| " $1 " | " $2 " |"}'
  echo ""
  echo "---"
  echo ""
  echo "## 🚫 Admission Deny Events"
  echo "> 💡 **Nota:** Los recursos rechazados en tiempo de admisión no aparecen como violaciones de auditoría, ya que nunca se crearon en el clúster."
  echo ""
  # Admission Deny Events: buscar en logs y stderr
  echo "" 
  echo "### From Gatekeeper logs (controller-manager and auditor):" 
  echo "" 
  kubectl logs -n gatekeeper-system -l control-plane=controller-manager --tail=500 | grep -iE "denied|violates|violat|validation.gatekeeper.sh" || echo "No deny-like entries found in controller-manager logs."
  echo ""
  kubectl logs -n gatekeeper-system -l control-plane=audit-controller --tail=500 | grep -iE "denied|violates|violat|validation.gatekeeper.sh" || echo "No deny-like entries found in audit-controller logs."

  echo ""
  echo "### From kubectl apply stderr (attack attempts):"
  if ls "$ATTACK_ERRORS_DIR"/*.stderr &>/dev/null; then
    for e in "$ATTACK_ERRORS_DIR"/*.stderr; do
      echo "---- $(basename "$e") ----"
      tail -n 50 "$e"
    done
  else
    echo "No attack attempt stderr files found."
  fi
  echo ""
  echo "---"
  echo ""
  echo "## ⚔️ Attack Attempts (kubectl apply stderr)"
  if ls "$ATTACK_ERRORS_DIR"/*.stderr &>/dev/null; then
    for e in "$ATTACK_ERRORS_DIR"/*.stderr; do
      echo ""
      echo "### 🧨 $(basename "$e")"
      tail -n 20 "$e"
      echo ""
    done
  else
    echo "No attack attempt logs found."
  fi
} > "$REPORTS_DIR/report.md"

# Generate a summary of attack stderr files to summary.txt
if ls "$ATTACK_ERRORS_DIR"/*.stderr &>/dev/null; then
  {
    echo "Attack Attempts Summary"
    echo "======================="
    for e in "$ATTACK_ERRORS_DIR"/*.stderr; do
      echo "File: $(basename "$e")"
      head -n 10 "$e"
      echo ""
    done
  } > "$ATTACK_RESULTS_DIR/summary.txt"
else
  echo "No attack attempt stderr files found." > "$ATTACK_RESULTS_DIR/summary.txt"
fi