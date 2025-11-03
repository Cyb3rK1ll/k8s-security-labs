## 🧩 Gatekeeper Audit Summary

| Constraint | Violations |
|-------------|------------|
| pss-baseline | 0 |
| pss-baseline-dryrun | 6 |
| pss-restricted | 0 |
| pss-restricted-dryrun | 12 |

---

## 🚫 Admission Deny Events
> 💡 **Nota:** Los recursos rechazados en tiempo de admisión no aparecen como violaciones de auditoría, ya que nunca se crearon en el clúster.


### From Gatekeeper logs (controller-manager and auditor):

No deny-like entries found in controller-manager logs.

No deny-like entries found in audit-controller logs.

### From kubectl apply stderr (attack attempts):
---- cap.stderr ----
Error from server (Forbidden): error when creating "./attack/capabilities-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-restricted] Pod malicious-cap violates PSS level restricted
---- hostnetwork.stderr ----
Error from server (Forbidden): error when creating "./attack/hostnetwork-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-baseline] Pod malicious-hostnetwork violates PSS level baseline
[pss-restricted] Pod malicious-hostnetwork violates PSS level restricted
---- privileged.stderr ----
Error from server (Forbidden): error when creating "./attack/privileged-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-baseline] Pod malicious-privileged violates PSS level baseline
[pss-restricted] Pod malicious-privileged violates PSS level restricted
---- runasnonroot.stderr ----
Error from server (Forbidden): error when creating "./attack/runasnonroot-false.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-restricted] Pod malicious-runasnonroot violates PSS level restricted

---

## ⚔️ Attack Attempts (kubectl apply stderr)

### 🧨 cap.stderr
Error from server (Forbidden): error when creating "./attack/capabilities-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-restricted] Pod malicious-cap violates PSS level restricted


### 🧨 hostnetwork.stderr
Error from server (Forbidden): error when creating "./attack/hostnetwork-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-baseline] Pod malicious-hostnetwork violates PSS level baseline
[pss-restricted] Pod malicious-hostnetwork violates PSS level restricted


### 🧨 privileged.stderr
Error from server (Forbidden): error when creating "./attack/privileged-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-baseline] Pod malicious-privileged violates PSS level baseline
[pss-restricted] Pod malicious-privileged violates PSS level restricted


### 🧨 runasnonroot.stderr
Error from server (Forbidden): error when creating "./attack/runasnonroot-false.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [pss-restricted] Pod malicious-runasnonroot violates PSS level restricted

