# Operations Runbook

Runbook ini menjelaskan alur repeatable untuk plan, apply terkontrol, evidence
collection, dan destroy hemat biaya. Gunakan bersama
`docs/aws-verification-runbook.md`, `docs/evidence-register.md`, dan
`docs/bab4-experiment-matrix.md`.

## Operating Principles

- Production-like stack bersifat sementara untuk penelitian, bukan layanan yang
  harus hidup permanen.
- Remote backend Terraform dipertahankan agar apply berikutnya tetap punya state
  terenkripsi dan S3 native lockfile.
- Domain dan hosted zone dipertahankan.
- Raw artifacts tidak di-commit ke Git; simpan di GitHub Actions atau folder
  lokal yang di-ignore.
- GuardDuty dan Security Hub tidak boleh diklaim kecuali nanti benar-benar
  diaktifkan dan punya evidence.

## Plan Flow

1. Pastikan GitHub variables/secrets lengkap:
   - `AWS_REGION=ap-southeast-3`
   - `TF_VAR_PROJECT_NAME=eepistore`
   - `TF_VAR_DOMAIN_NAME=eepistore.web.id`
   - `TF_VAR_ROUTE53_ZONE_ID`
   - `TF_VAR_ENABLE_HTTPS=true`
   - `TF_VAR_ACM_CERTIFICATE_ARN`
   - `TF_VAR_APP_BASE_URL=https://eepistore.web.id`
   - `TF_VAR_APP_IMAGE_URI` berisi image URI immutable dengan digest atau commit SHA
   - password RDS dan `AUTH_SECRET` dibuat Terraform di Secrets Manager
2. Jalankan GitHub Actions Terraform CI dengan `action=plan`.
3. Review artifact `terraform-plan/tfplan.txt`.
4. Stop jika ada destroy/replacement yang tidak direncanakan, bucket public,
   CORS wildcard, image bukan SHA, ALB tanpa HTTPS, RDS public, atau RDS Proxy
   tanpa target.

## Apply Terkontrol

1. Jalankan workflow Terraform dengan `action=apply`.
2. Tunggu job validate/scan dan plan selesai.
3. Review `tfplan.txt` dari run apply yang sama, bukan plan lama.
4. Approve environment `production` hanya jika review gate lulus.
5. Setelah apply, simpan link run, run ID, artifact `terraform-plan`, dan
   artifact `post-apply-verification` di `docs/evidence-register.md`.
6. Jika apply gagal, jangan lanjut deploy app terpisah. Analisis state, events,
   dan resource aktual terlebih dahulu.

## Post-Apply Verification

1. Gunakan artifact otomatis dari `scripts/verify-aws-post-apply.sh`.
2. Review status `PASS` untuk drift, VPC, ALB/listeners, target health, ECS,
   ASG, RDS, RDS Proxy targets, S3 public access block/encryption, CloudFront,
   WAF, `/api/health`, dan `/api/readiness`.
3. Lengkapi manual evidence jika dibutuhkan BAB 4:
   - ECS deployment events.
   - CloudWatch log aplikasi tanpa error read-only filesystem.
   - CloudWatch metrics/alarm/dashboard.
   - Route53 dan ACM status.
   - Media CloudFront domain.

## Final Experiment Evidence

Jalankan hanya setelah controlled apply dan post-apply verification lulus.

1. Jalankan workflow `Final Experiment Evidence` dengan mode
   `role-preflight`. Approve environment `production`, lalu pastikan artifact
   `experiment-oidc-preflight` berstatus `passed`. Mode ini hanya menguji asumsi
   role dan pembacaan lokasi bucket backend; tidak menjalankan Terraform.
2. Pastikan image aktif menggunakan digest dari app publish run.
3. Tambahkan secret `AWS_EXPERIMENT_ROLE_ARN` sesuai policy
   `bootstrap/github-oidc/experiment-evidence-policy.json`.
4. Jalankan workflow yang sama dari `main` dengan mode `full-experiment`.
5. Isi app commit SHA, image digest, app publish run ID, Terraform apply run ID,
   dan target HTTPS. Workflow menjalankan tiga trial k6 secara tetap.
6. Review artifact `final-experiment-evidence-<run-id>`. Canonical JSON harus
   berstatus `final`.
7. Pastikan cleanup database dan prefix S3 eksperimen lulus sebelum destroy.

Workflow ini tidak memiliki Terraform apply. ZAP dibatasi allowlist/timeout dan
k6 dibatasi maksimum 50 VU. DDoS, request flood, dan target di luar domain
project dilarang.

Setelah perubahan IAM, jalankan `node scripts/validate-experiment-iam.mjs`.
Hentikan proses jika Access Analyzer mengeluarkan warning/error, izin wajib
tidak `allowed`, atau aksi mutasi yang dilarang tidak `implicitDeny`.

### Local Backend Cache

Backend aktif memakai S3 native lockfile (`use_lockfile = true`). Working copy
lama dapat masih menyimpan konfigurasi DynamoDB lock pada
`env/dev/.terraform/terraform.tfstate` dan menampilkan checksum mismatch yang
tidak terjadi pada clean GitHub runner. Jangan mengubah Digest DynamoDB secara
langsung. Validasi source lokal dapat memakai `TF_DATA_DIR` terpisah dan
`terraform init -backend=false`; untuk operasi state, gunakan clean checkout
atau hapus cache `.terraform/` yang ignored lalu jalankan `terraform init
-reconfigure` dengan credential yang benar.

## App Image dan Evidence Flow

1. Jika kode app berubah, jalankan workflow app untuk quality gate, scanning,
   SBOM, attestation, dan publish image.
2. Jika ECR repo belum ada setelah destroy, buat ECR terlebih dahulu melalui
   workflow Terraform `action=bootstrap-ecr`. Review targeted saved plan dan
   approve environment `production` sebelum menjalankan `publish-image`.
3. Gunakan image digest URI dari output workflow untuk update
   `TF_VAR_APP_IMAGE_URI`.
4. Terraform menjadi satu-satunya pemilik task definition dan ECS service.
   Workflow aplikasi tidak boleh melakukan register task definition atau update
   service.
5. Setelah stack aktif, jalankan workflow `Final Experiment Evidence` untuk
   Playwright, bounded ZAP, tiga trial k6, CloudWatch, dan cleanup fixture.
6. Simpan metadata run dan artifact di `docs/evidence-register.md`.

## Destroy Hemat Biaya

1. Jalankan workflow Terraform dengan `action=destroy`.
2. Review plan sebelum approval:
   - mayoritas harus destroy-only,
   - tidak boleh ada create/update besar tanpa alasan,
   - deletion protection override aktif,
   - bucket dan ECR force destroy/delete aktif,
   - keputusan final snapshot jelas.
3. Approve environment `production` setelah review lulus.
4. Setelah destroy:
   - cek artifact `post-destroy-verification` berisi `PASS terraform-state-empty`,
   - hapus final RDS snapshot jika muncul dan tidak diperlukan,
   - cek secret sisa dan force-delete bila masih ada,
   - cek resource mahal: NAT, RDS, ALB, ECS/EC2, ECR, S3 workload, CloudFront.
5. Jangan hapus backend remote state kecuali target berubah menjadi nol biaya
   absolut dan siap bootstrap ulang nanti.

## Cost Audit Notes

- AWS Billing/Cost Explorer tetap perlu dicek manual karena data biaya tidak
  selalu real-time.
- Resource yang harus tidak aktif setelah destroy: NAT Gateway, RDS instance,
  ALB, ECS tasks/container instances, EC2 ECS instances, ECR repo workload, S3
  workload buckets, CloudFront media distribution, RDS snapshots yang tidak
  diperlukan.
- Resource yang sengaja boleh tersisa: domain, hosted zone, Terraform state
  bucket, lockfile object, dan KMS backend.
