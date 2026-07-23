# Evidence Register

Dokumen ini mencatat metadata evidence yang aman disimpan di Git. Jangan
commit artifact mentah dari GitHub Actions, output AWS CLI penuh, plan binary,
state, secret, screenshot yang memuat data sensitif, atau file hasil scan yang
belum ditinjau.

## Current Infrastructure State

- Workload AWS utama sudah di-destroy untuk hemat biaya.
- ECR bootstrap telah dibuat ulang untuk menerima image remediation. Full
  workload tetap belum di-apply.
- Terraform remote backend tetap dipertahankan: S3 state bucket
  `eepistore-dev-terraform-state`, native lockfile, dan KMS key backend.
- Domain dan hosted zone Route53 tetap dipertahankan.
- Role GitHub OIDC tidak lagi memakai `AdministratorAccess`; policy source
  disimpan di `bootstrap/github-oidc`.
- Role eksperimen sudah dibuat dan hanya dapat diasumsikan oleh environment
  `production` pada repository infra.

## Evidence Rules

- `Valid` berarti evidence boleh menjadi referensi teknis.
- `Stale` berarti evidence sudah digantikan evidence lebih baru.
- `Missing` berarti belum boleh diklaim di BAB 4.
- `Draft` berarti membantu debugging, tetapi perlu diulang untuk paket final.

## Evidence Inventory

| Area | Evidence | Source | Status | BAB 4 Usage |
| --- | --- | --- | --- | --- |
| App final experiment image publish | Image digest `sha256:67d7b6ba0df5059d13276b41b2b9a83a66d24ef283ec553eefb67ab58f8d7df6` untuk app commit `50b26b1488c738f4d332d4cfa6d7d027479ce97d` | GitHub Actions app run `30008122012`, artifact `published-image`, SBOM, container scan, dan provenance attestation | Valid final pre-apply baseline | Sumber image immutable untuk controlled apply berikutnya |
| Terraform final pre-apply plan | Plan `139 add, 0 change, 0 destroy, 0 replace` selama 16 detik untuk infra commit `c8da6893084be4506617fbcb775acc49dde84463` | GitHub Actions infra run `30008739652`, artifact `terraform-plan-review` | Valid final pre-apply baseline | Bukti review arsitektur dan biaya perubahan sebelum controlled apply; belum membuktikan resource sudah aktif |
| Experiment OIDC role preflight | Asumsi role `eepistore-infra-experiment-role`, akun `557947229844`, region `ap-southeast-3`, dan pembacaan lokasi backend berhasil | GitHub Actions infra run `30008016042`, artifact `experiment-oidc-preflight` | Valid operational evidence | Bukti role eksperimen dapat digunakan dari environment `production` tanpa izin Terraform apply |
| App experiment automation publish | Image digest `sha256:bea6ad33e97f4e6c9f35193f404b26d50358d42f14b309101eefaea7e6d80f52` untuk app commit `487883ff478b83d6f52cde2ae9aa840a277bf0e8` | GitHub Actions app run `30004152382`, artifact `published-image`, SBOM, scan, dan provenance attestation | Stale | Digantikan app run `30008122012` setelah maintenance action |
| Terraform plan experiment automation | Plan `139 add, 0 change, 0 destroy, 0 replace` untuk infra commit `3e645008e23c491f7799afc4275f484b3b21047b` | GitHub Actions infra run `30004670727`, artifact `terraform-plan-review` | Stale | Digantikan infra run `30008739652` setelah maintenance action dan hardening IAM |
| Experiment role policy validation | Access Analyzer tanpa finding; tujuh kelompok izin wajib `allowed`; sembilan aksi mutasi infrastruktur `implicitDeny`; policy baru tidak menambah akses | AWS IAM Access Analyzer, IAM policy simulator, dan `scripts/validate-experiment-iam.mjs` pada `2026-07-23` | Valid operational evidence | Bukti least privilege sebelum OIDC preflight; tidak menggantikan pengujian asumsi role dari GitHub |
| App image publish pre-automation | Image digest `sha256:46834d635ef90087683aa1fb1d29899fd68c1f0a77270fd88c05f8724bb9c2db` untuk app commit `9aed6d5cbbe94177908f1c032e79a7b412b12808` | GitHub Actions app run `29983090390`, artifact `published-image` dan provenance attestation | Stale for final experiment | Bukti baseline immutable; utility eksperimen mengubah source app sehingga publish ulang wajib |
| Terraform plan pre-automation | Plan `139 add, 0 change, 0 destroy` untuk infra commit `cbd1a51a0adeefa86d48715937d67218658b83d0` | GitHub Actions infra run `29983467498`, artifact `terraform-plan-review` | Stale for final experiment | Bukti baseline plan; workflow, output, policy, dan collector berubah sehingga plan ulang wajib |
| Experiment automation local validation | Playwright role test, bounded ZAP plan, tiga trial k6, CloudWatch collector, schema validator, cleanup gate, dan dashboard parser | Local validation pada branch `experiment/evidence-automation-20260723` | Draft | Menjadi evidence final hanya setelah CI, image publish, plan, controlled apply, dan live experiment selesai |
| App remediation CI | Quality, CodeQL, npm audit, Docker build, SBOM, dan Trivy container scan untuk commit `f94ad65` | GitHub Actions app run `29981599919`, PR `yudhis55/eepistore#1` | Valid CI evidence | Bukti gate source remediation; belum menjadi bukti image publish/deployment |
| IaC remediation CI | fmt, validate, TFLint, Trivy IaC, dan Checkov untuk commit `84eacb5` | GitHub Actions infra run `29981610767`, PR `yudhis55/infra-aws-terraform#1` | Valid CI evidence | Bukti source IaC lulus gate; plan/apply memang tidak dijalankan pada PR |
| App image publish | Image `557947229844.dkr.ecr.ap-southeast-3.amazonaws.com/eepistore-repo:18fb24f6d419722841f587cbf4355aa2419c2dbf` | GitHub Actions app run `28765082346`, artifact `published-image` | Stale | Hanya bukti baseline lama; telah digantikan candidate digest `sha256:46834d...` |
| App image publish lama | Image tag `1496d689d5bd7d304995fdde7ab2feacdeb15003` | GitHub Actions app run `28748288932` | Stale | Jangan dipakai sebagai image final karena sudah digantikan `18fb24f...` |
| Terraform apply | Controlled apply dengan strict readiness | GitHub Actions infra run `28765301534`, artifact `terraform-plan` dan `post-apply-verification` | Valid baseline | Boleh dipakai sebagai bukti bahwa desain pernah berhasil, tetapi eksperimen BAB 4 final sebaiknya mengambil paket evidence lengkap ulang |
| Post-apply verification | Drift, VPC, ALB, ECS, RDS, RDS Proxy, S3, CloudFront, WAF, health, readiness semuanya PASS | GitHub Actions infra run `28765301534` | Valid baseline | Boleh dikutip sebagai baseline teknis, dengan catatan stack sudah di-destroy |
| Terraform destroy | Destroy plan `0 add, 0 change, 78 destroy` lalu state kosong | GitHub Actions infra run `28767137374`, artifact `post-destroy-verification` | Valid | Boleh dipakai sebagai bukti teardown hemat biaya dan operasional IaC |
| Post-destroy AWS spot check | VPC/NAT kosong, ECS inactive, ALB/RDS/RDS Proxy/ECR not found, workload S3 hilang, secret kosong, snapshot hilang | AWS CLI read-only check pada `2026-07-06` | Valid operational note | Boleh dipakai sebagai catatan operasional, bukan pengganti artifact workflow final |
| Remediation validation | Format, lint, typecheck, 15 unit tests, Next production build, Docker build, dan fixture validation pada read-only container | Local validation pada `2026-07-23` | Draft | Harus diulang di GitHub Actions setelah branch dipush |
| IaC remediation validation | Terraform init/validate, TFLint, Trivy `0` finding, Checkov `255 passed / 0 failed` | Local validation pada `2026-07-23` | Draft | Harus diulang di GitHub Actions sebelum plan |
| GitHub OIDC hardening | App role ECR-only, plan role read-only + backend, apply role PowerUser + project IAM | AWS IAM policy simulator pada `2026-07-23` | Valid operational note | Bukti hardening akses pipeline; workflow tetap perlu menguji permission aktual |
| Scanner triage | Fixed, accepted, dan deferred scanner findings | `docs/scan-triage.md` | Valid | Boleh dipakai untuk menjelaskan batasan klaim keamanan |
| OWASP ZAP | DAST terhadap domain HTTPS | Belum ada paket final setelah apply sukses | Missing | Jangan diklaim sebelum report JSON/HTML tersedia |
| k6 load test | Smoke/load test terhadap `/api/health` dan alur utama | Belum ada paket final setelah apply sukses | Missing | Jangan diklaim sebelum summary JSON tersedia |
| Functional smoke | Login, upload media publik via CloudFront, akses objek sensitif | Belum ada paket final | Missing | Jangan diklaim sebelum ada hasil uji eksplisit |
| Monitoring evidence | CloudWatch logs, metrics, alarms/dashboard, WAF evidence | Sebagian resource sudah diverifikasi, tetapi paket screenshot/log final belum lengkap | Missing | Jangan diklaim sebagai hasil BAB 4 final tanpa artifact/screenshot |

## Evidence To Capture On Next Apply

Prasyarat image, OIDC preflight, dan plan final sudah tersedia. Controlled apply
belum dijalankan. Evidence berikut masih harus diambil:

1. Post-apply verification artifact pada eksperimen final.
2. ZAP JSON/HTML report.
3. k6 summary JSON.
4. Runtime smoke evidence for HTTPS, redirect, health, readiness, login, media
   upload, and private object authorization.
5. CloudWatch evidence for application logs, target health, ECS service events,
   RDS/RDS Proxy state, WAF association, and alarms/dashboard.
6. Final destroy verification after evidence is safely captured.

## Canonical Experiment Package

Workflow `Final Experiment Evidence` menghasilkan satu
`experiment-evidence.json` dengan schema `1.0.0`. Paket berstatus `final` hanya
apabila provenance app/infra/image sama, post-apply verification tersedia,
functional/ZAP/k6/CloudWatch lengkap, dan cleanup fixture berhasil. Dashboard
lokal tidak boleh mengganti status atau nilai paket tersebut.

Input operator untuk paket final dicatat memakai
`docs/final-experiment-manifest.template.json`. Template tidak boleh diisi
dengan secret dan bukan pengganti artifact GitHub Actions.
