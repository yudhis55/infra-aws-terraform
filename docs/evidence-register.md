# Evidence Register

Dokumen ini mencatat metadata evidence yang aman disimpan di Git. Jangan
commit artifact mentah dari GitHub Actions, output AWS CLI penuh, plan binary,
state, secret, screenshot yang memuat data sensitif, atau file hasil scan yang
belum ditinjau.

## Current Infrastructure State

- Workload AWS utama sudah di-destroy untuk hemat biaya.
- Terraform remote backend tetap dipertahankan: S3 state bucket
  `eepistore-dev-terraform-state`, native lockfile, dan KMS key backend.
- Domain dan hosted zone Route53 tetap dipertahankan.
- Role GitHub OIDC tidak lagi memakai `AdministratorAccess`; policy source
  disimpan di `bootstrap/github-oidc`.

## Evidence Rules

- `Valid` berarti evidence boleh menjadi referensi teknis.
- `Stale` berarti evidence sudah digantikan evidence lebih baru.
- `Missing` berarti belum boleh diklaim di BAB 4.
- `Draft` berarti membantu debugging, tetapi perlu diulang untuk paket final.

## Evidence Inventory

| Area | Evidence | Source | Status | BAB 4 Usage |
| --- | --- | --- | --- | --- |
| App remediation CI | Quality, CodeQL, npm audit, Docker build, SBOM, dan Trivy container scan untuk commit `f94ad65` | GitHub Actions app run `29981599919`, PR `yudhis55/eepistore#1` | Valid CI evidence | Bukti gate source remediation; belum menjadi bukti image publish/deployment |
| IaC remediation CI | fmt, validate, TFLint, Trivy IaC, dan Checkov untuk commit `84eacb5` | GitHub Actions infra run `29981610767`, PR `yudhis55/infra-aws-terraform#1` | Valid CI evidence | Bukti source IaC lulus gate; plan/apply memang tidak dijalankan pada PR |
| App image publish | Image `557947229844.dkr.ecr.ap-southeast-3.amazonaws.com/eepistore-repo:18fb24f6d419722841f587cbf4355aa2419c2dbf` | GitHub Actions app run `28765082346`, artifact `published-image` | Stale | Hanya bukti baseline lama; source aplikasi sudah berubah pada remediation 2026-07-23 |
| App image publish lama | Image tag `1496d689d5bd7d304995fdde7ab2feacdeb15003` | GitHub Actions app run `28748288932` | Stale | Jangan dipakai sebagai image final karena sudah digantikan `18fb24f...` |
| Terraform apply | Controlled apply dengan strict readiness | GitHub Actions infra run `28765301534`, artifact `terraform-plan` dan `post-apply-verification` | Valid baseline | Boleh dipakai sebagai bukti bahwa desain pernah berhasil, tetapi eksperimen BAB 4 final sebaiknya mengambil paket evidence lengkap ulang |
| Post-apply verification | Drift, VPC, ALB, ECS, RDS, RDS Proxy, S3, CloudFront, WAF, health, readiness semuanya PASS | GitHub Actions infra run `28765301534` | Valid baseline | Boleh dikutip sebagai baseline teknis, dengan catatan stack sudah di-destroy |
| Terraform destroy | Destroy plan `0 add, 0 change, 78 destroy` lalu state kosong | GitHub Actions infra run `28767137374`, artifact `post-destroy-verification` | Valid | Boleh dipakai sebagai bukti teardown hemat biaya dan operasional IaC |
| Post-destroy AWS spot check | VPC/NAT kosong, ECS inactive, ALB/RDS/RDS Proxy/ECR not found, workload S3 hilang, secret kosong, snapshot hilang | AWS CLI read-only check pada `2026-07-06` | Valid operational note | Boleh dipakai sebagai catatan operasional, bukan pengganti artifact workflow final |
| Remediation validation | Format, lint, typecheck, 15 unit tests, Next production build, npm audit, Docker build, dan read-only container smoke | Local validation pada `2026-07-23` | Draft | Harus diulang di GitHub Actions setelah branch dipush |
| IaC remediation validation | Terraform init/validate, TFLint, Trivy `0` finding, Checkov `255 passed / 0 failed` | Local validation pada `2026-07-23` | Draft | Harus diulang di GitHub Actions sebelum plan |
| GitHub OIDC hardening | App role ECR-only, plan role read-only + backend, apply role PowerUser + project IAM | AWS IAM policy simulator pada `2026-07-23` | Valid operational note | Bukti hardening akses pipeline; workflow tetap perlu menguji permission aktual |
| Scanner triage | Fixed, accepted, dan deferred scanner findings | `docs/scan-triage.md` | Valid | Boleh dipakai untuk menjelaskan batasan klaim keamanan |
| OWASP ZAP | DAST terhadap domain HTTPS | Belum ada paket final setelah apply sukses | Missing | Jangan diklaim sebelum report JSON/HTML tersedia |
| k6 load test | Smoke/load test terhadap `/api/health` dan alur utama | Belum ada paket final setelah apply sukses | Missing | Jangan diklaim sebelum summary JSON tersedia |
| Functional smoke | Login, upload media publik via CloudFront, akses objek sensitif | Belum ada paket final | Missing | Jangan diklaim sebelum ada hasil uji eksplisit |
| Monitoring evidence | CloudWatch logs, metrics, alarms/dashboard, WAF evidence | Sebagian resource sudah diverifikasi, tetapi paket screenshot/log final belum lengkap | Missing | Jangan diklaim sebagai hasil BAB 4 final tanpa artifact/screenshot |

## Evidence To Capture On Next Apply

1. GitHub Actions app remediation run dan image digest baru.
2. Terraform plan artifact dari source remediation.
3. Post-apply verification artifact pada eksperimen final.
4. App image digest, SBOM, provenance attestation, dan container scan artifact.
5. ZAP JSON/HTML report.
6. k6 summary JSON.
7. Runtime smoke evidence for HTTPS, redirect, health, readiness, login, media
   upload, and private object authorization.
8. CloudWatch evidence for application logs, target health, ECS service events,
   RDS/RDS Proxy state, WAF association, and alarms/dashboard.
9. Final destroy verification after evidence is safely captured.
