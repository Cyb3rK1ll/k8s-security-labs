# 🔐 DevSecOps Lab 7 – Automated DefectDojo on AWS (IaC + Restore Pipeline)

This lab delivers a **lab-grade DefectDojo stack** (for enablement/PoC use, not direct production) with:

- **100 % IaC** (Terraform + userdata) that provisions networking, IAM and EC2 in 12 minutes.  
- **Secure-by-default installation** with Docker Compose hardening, systemd auto-restarts, and evidence logging.  
- **Continuous backup & one-click restore** from S3, including **automatic admin password rotation** after every restore.  
- **Real-time observability**: Terraform streams `/var/log/defectdojo_install.log` and prints the final URL + credentials.

It is aimed at **DevSecOps engineers, application security teams, and consultants** showcasing enterprise readiness on LinkedIn, RFPs, or interviews.

---

## 🎯 Business & Security Outcomes

| Stakeholder | Outcome |
|-------------|---------|
| **CISO / Security Director** | Demonstrates repeatable DevSecOps capability, with auditable logs and password management. |
| **AppSec / DevSecOps Team** | Push-button lab to rehearse workflows (SAST/SCA ingestion, risk reporting, pipeline integration). |
| **Sales / Advisory** | Tangible proof for clients that security analytics can be deployed with IaC and recovered in minutes. |

---

## 🏗️ Architecture Snapshot

- **AWS EC2 (Amazon Linux 2023)** – runs the DefectDojo Docker stack.  
- **IAM Role + Instance Profile** – grants least-privilege access to the S3 backup bucket.  
- **Security Group** – exposes only SSH (22) and DefectDojo UI (8080).  
- **Terraform Provisioners** – stream install logs, copy restore scripts, and optionally trigger a full restore.  
- **Systemd Service (`defectdojo.service`)** – ensures Docker Compose auto-starts on reboot.  
- **Evidence Artifacts** – `/var/log/defectdojo_install.log`, `/home/ec2-user/defectdojo_admin_credentials.log`.

> ⚠️ **Scope**: this setup is intentionally lab-focused. For production you must harden networking (private subnets, ALB/WAF), move to managed DB/storage, add secrets management (KMS/SSM), and integrate monitoring.

> _Suggested diagram:_ `evidence/diagrams/devsecops-defectdojo-architecture.png` – high-level view of Terraform → AWS → Docker Compose → S3 backups.

---

## ⚙️ Automation Flow

1. **Terraform Apply**  
   - Creates the EC2 instance + IAM plumbing.  
   - Streams installer logs live via `null_resource.defectdojo_install_log`.
2. **`install_defectdojo.sh` (userdata)**  
   - Installs Docker/Compose, deploys DefectDojo, captures admin credentials.  
   - Registers `defectdojo.service` so containers auto-recover.  
3. **Optional Restore** (`enable_defectdojo_restore=true`)  
   - Downloads DB + media backups from S3.  
   - Drops/recreates the `defectdojo` database, restores media volume, restarts the stack.  
   - Resets the `admin` password with a fresh random secret and stores it on disk.  
4. **Summary Output**  
   - Terraform prints public IP, URL, and the current `admin` password for immediate login.

---

## ✅ Features & Controls

- **Hardened Installation**: non-root containers, PAM-style constraints from upstream DefectDojo Docker stack.  
- **Secrets Hygiene**: admin password extracted from logs on first boot, rotated during restores, stored in mode `600`.  
- **Operational Resilience**: systemd service + `docker compose` health checks keep services alive.  
- **Observability**: log streaming plus artifacts under `/home/ec2-user` for audits.  
- **Turn-Key Restore**: scripted S3 pull, DB reset, media rehydration, and password reset – ideal for DR demos.

---

## 📋 Prerequisites

1. **AWS Account** with permissions to create EC2, IAM roles, and S3 objects.  
2. **AWS CLI profile** named `k8s-labs` (adjust in `main.tf` if needed).  
3. **Terraform v1.5+** installed locally.  
4. **Existing S3 backups** (or disable the restore flag for a fresh install).

---

## 🚀 Deployment Walkthrough

```bash
# 1. Generate or reuse an EC2 key pair
aws ec2 create-key-pair \
  --key-name defectdojo-key \
  --query 'KeyMaterial' \
  --output text \
  --region eu-west-1 \
  --profile k8s-labs > defectdojo-key.pem
chmod 400 defectdojo-key.pem

# 2. Initialize and deploy
terraform init
terraform apply -auto-approve
```

During `apply`, Terraform will:

- Show the live installer log.  
- Optionally perform the S3 restore (if `enable_defectdojo_restore=true`).  
- Print a summary similar to:

```text
============================================================
 📋 DefectDojo listo
------------------------------------------------------------
IP pública: 34.242.67.67
URL: http://ec2-34-242-67-67.eu-west-1.compute.amazonaws.com:8080
Usuario: admin
Contraseña: z3yEwJ2h3pJgB4yJt6aN2Q
============================================================
```

Outputs are also available via Terraform:

```text
dojo_public_ip = "34.242.67.67"
dojo_url       = "http://ec2-34-242-67-67.eu-west-1.compute.amazonaws.com:8080"
```

---

## 🔁 Restore / DR Scenario

Variables in `main.tf` control the automated restore:

```hcl
enable_defectdojo_restore      = true
defectdojo_restore_bucket      = "defectdojo-backup-lab9-devsecops"
defectdojo_restore_db_object   = "defectdojo_db_backup_2025-11-06_2313.sql"
defectdojo_restore_media_object= "dojo_media_backup_2025-11-06_2313.tar.gz"
```

What happens:
1. Installer finishes → Terraform copies `restore_defectDojo.sh`.  
2. Script pulls the specified objects from S3.  
3. Database is recreated from scratch, media volume is rehydrated, and Docker Compose stack is restarted.  
4. Admin password rotates (stored locally + echoed in Terraform summary).

Disable the restore by setting `enable_defectdojo_restore=false` when you want a pristine environment.

---

## 🔍 Operations & Access

```bash
# SSH session
ssh -i defectdojo-key.pem ec2-user@$(terraform output -raw dojo_public_ip)

# View evidence
sudo less /var/log/defectdojo_install.log
cat ~/defectdojo_admin_credentials.log

# Docker health
cd ~/django-DefectDojo
docker compose ps
```

Systemd ensures the stack survives reboots:

```bash
sudo systemctl status defectdojo.service
```

---

## 🧭 Next Steps

- **Integrate CI/CD**: push findings via API tokens once pipelines are ready.  
- **Add guardrails**: extend IAM policy to include KMS keys or private S3 buckets.  
- **Evidence Pack**: capture screenshots (UI login, findings dashboard) for LinkedIn case studies.  
- **Cost Optimization**: convert EC2 to spot instances or an Auto Scaling Group if you need multiple sandboxes.

---

Feel free to fork, adapt, and showcase the runbooks with your clients or hiring managers. This lab is designed to prove that **DevSecOps automation, resilience, and reporting can coexist in one repeatable package**. 🚀
