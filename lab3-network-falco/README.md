# Kubernetes Security Labs – Claudio Magagnotti

> **Cybersecurity Architect | 12+ Years in Cloud Security & DevSecOps**  
> **Azure AKS | AWS EKS | Zero Trust | CISSP (2025) | CKA | AZ-500**  
> **Spain | [clau.magagnotti@hotmail.com](mailto:clau.magagnotti@hotmail.com)**  

# LAB 3: Kubernetes Network Policies + Falco (EKS + Slack Alerts)
## WHY FALCO?

Falco is the de facto solution for runtime security in Kubernetes, regardless of the cloud provider.
Azure and AWS offer native tools (Defender for Containers, GuardDuty), but:

- They lack the granularity of Falco (syscall-level detection)
- They are not open-source or multi-cloud
- They don’t support such flexible custom rules

> Falco detects in real-time: shell spawn, unauthorized binaries, privilege escalation.
We use it because it is the CNCF standard, and works the same in EKS, AKS, GKE.
In production, it integrates with Slack, SIEM, SOAR. It’s more powerful than native tools for regulated environments.


## **Lab Objective**
Demostrar **Zero Trust** en Kubernetes:
- **NetworkPolicy deny-all** → Bloquea todo tráfico
- **Falco** → Detecta shells y binarios no autorizados
- **Slack** → Alertas en tiempo real
- **Terraform + Helm + EKS** → 100% automatizado

Demonstrate Zero Trust in Kubernetes:
- **NetworkPolicy deny-all** → Blocks all traffic
- **Falco → Detects shells** and unauthorized binaries
- **Slack** → Real-time alerts
- **Terraform + Helm + EKS** → 100% automated

---
## **📊 Metrics Hardening**
|Feature|Status|Prueba|
|-|-|-|
|NetworkPolicy deny-all|✅| Activo|curl victim:80 → BLOCKED|
|Falco runtime detection|✅| Activo|shell in container → Slack alert|
|Slack integration|✅| Activo|Real-time alerts|
|Custom rules|✅| Loaded|rules_files: /etc/falco/custom_rules/falco.yaml|

---
## **Deployed Architecture**

```text
EKS Cluster (t3.medium)
├── VPC (2 AZs + NAT)
├── NetworkPolicy deny-all (default namespace)
├── Falco (DaemonSet) → Detecta:
│   • Drop and execute new binary (curl)
│   • Terminal shell in container (sh -c)
├── Falcosidekick → Envía alertas a Slack
└── Attack: lateral-move.sh → curl + shell spawn
```
---


## **📸 Slack screenshots**
|Alert | Descr|
|-|-|
|![Notificacion1](evidence/Slack_Notification01.png)|Drop and execute new binary in container|
|![Notificacion1](evidence/Slack_Notification02.png)|Terminal shell in container|


## **Deploy in 5 Minutes**

```
# 1. Clone the repo
git clone https://github.com/Cyb3rK1ll/k8s-security-labs.git
cd k8s-security-labs/lab3-network-falco

# 2. Deploy
terraform init
terraform apply -auto-approve

# 3. Execute attack
./attack/lateral-move.sh
```

---

## **Custom Rules (falco_rules/falco.yaml)**
```
- rule: Test - Any shell via sh or bash with -c
  desc: Triggers when any shell with '-c' is launched inside a container (for testing)
  condition: >
    container
    and evt.type = execve
    and (proc.name = sh or proc.name = bash)
    and proc.cmdline contains "-c"
  output: >
    🔥 [Falco Test] Shell via sh/bash with -c (user=%user.name container=%container.id image=%container.image.repository command=%proc.cmdline)
  priority: NOTICE
  tags: [test, shell, container]
```
---
## **Evidence (included in /evidence)**
|File|Description|
|-|-|
|falco.log|Logs de Falco con detección de curl y sh -c|
|lateral-move|log,Log del ataque (bloqueo + shell spawn)|
|networkpolicy|yaml,NetworkPolicy deny-all|
|slack-alert-curl|png,Alerta de curl en Slack|
|slack-alert-shell|png,Alerta de sh -c en Slack|
---

## **🔧 Troubleshooting**
|Problem|Solution|
|-|-|
|Chart|yaml file is missing,helm pull falcosecurity/falco --version 7.0.0 --untar|
|context deadline exceeded|timeout = 900 + wait = true|
|CrashLoopBackOff|driver.kind: module + privileged: true|
|Driver API version mismatch|"driver.loader.version: ""3.0.0"""|
|No custom rule loaded|rules_files: /etc/falco/custom_rules/falco.yaml|
