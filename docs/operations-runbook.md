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
- ECR dikelola melalui state `bootstrap/ecr` dan dipertahankan melintasi Cycle R
  serta Cycle F agar image digest campaign tidak berubah.
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
3. Review artifact `terraform-plan-review/tfplan.txt`.
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

### Recovery Log Group di Luar State

Jika apply berhenti dengan `ResourceAlreadyExistsException` untuk
`/aws/vpc/flowlogs/eepistore`, jangan hapus log group karena dapat berisi log
eksperimen sebelumnya. Jalankan workflow `Recover Existing Flow Log Group
State` dengan konfirmasi `IMPORT-FLOW-LOG-GROUP`. Workflow hanya melanjutkan
jika alamat Terraform belum dikelola dan AWS mengembalikan tepat satu log group
dengan nama exact. Import dibatalkan dari state bila post-check gagal. Setelah
import berhasil, jalankan plan baru; jangan menggunakan saved plan yang gagal.

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

## Research Campaign Evidence

Jalankan hanya setelah baseline source, schema, IAM, dan plan lulus.

1. Jalankan `sync-experiment-oidc-policy.yml`, review Access Analyzer, policy
   diff, serta simulation result. Workflow melakukan rollback otomatis bila
   validasi gagal.
2. Jalankan `Research Campaign` mode `role-preflight`; artifact harus berstatus
   `passed` sebelum mutasi workload.
3. Freeze app commit, infra commit, image digest, campaign ID, input digest,
   profile, dan batas waktu aktif stack.
4. Cycle R: jalankan Terraform `apply` dengan `cycle-r`, verifikasi no-change,
   lalu `destroy`. Artifact pascadestroy harus membuktikan workload state kosong
   dan ECR bootstrap tetap tersedia.
5. Cycle F: gunakan input ilmiah yang sama, jalankan apply serta verification,
   controlled drift/recovery, enam workflow fault ephemeral, bounded WAF rate
   test, dan runtime suite.
6. Runtime suite menjalankan fixture, Playwright, bounded ZAP, network isolation,
   calibration, tiga final k6 trials, CloudWatch collection, dan cleanup data.
7. Terapkan `experiment-cleanup` melalui saved plan, lalu destroy Cycle F hanya
   setelah semua artifact wajib lengkap.
8. Jalankan `Aggregate Research Campaign Evidence` dengan tepat 18 run ID,
   termasuk tiga saved-plan transition untuk agent, rate-test, dan performance.
   Canonical evidence harus berstatus `final`, schema `2.0.0`, dan arsip offline
   harus lolos verifikasi checksum.

ZAP hanya mencakup origin milik project dan allowlist route read-only. Skenario
WAF dibatasi 150 request, 2 request/detik, concurrency satu, source `/32`, dan
berhenti pada blok pertama. DDoS, request flooding, port/CIDR scanning, dan
target di luar project dilarang.

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
2. Jika ECR bootstrap belum ada, jalankan `bootstrap-ecr.yml` dengan
   `action=apply`. Review saved plan dan approve environment `production`
   sebelum menjalankan `publish-image`.
3. Gunakan image digest URI dari output workflow untuk update
   `TF_VAR_APP_IMAGE_URI`.
4. Terraform menjadi satu-satunya pemilik task definition dan ECS service.
   Workflow aplikasi tidak boleh melakukan register task definition atau update
   service.
5. Setelah stack aktif, jalankan mode campaign yang diregistrasi untuk
   Playwright, bounded ZAP, tiga trial k6, CloudWatch, dan cleanup fixture.
6. Simpan metadata run dan artifact di `docs/evidence-register.md`.

## Destroy Hemat Biaya

1. Jalankan workflow Terraform dengan `action=destroy`.
2. Review plan sebelum approval:
   - harus destroy-only,
   - tidak boleh ada create/update besar tanpa alasan,
   - pre-step project-scoped untuk deletion protection RDS/ALB aktif,
   - purge current objects, versions, dan delete markers hanya menargetkan
     bucket public media, private documents, dan ALB logs,
   - bucket remote state tidak masuk target purge maupun destroy,
   - keputusan final snapshot jelas.
3. Approve environment `production` setelah review lulus.
4. Setelah destroy:
   - cek artifact `post-destroy-verification` berisi `PASS terraform-state-empty`,
   - hapus final RDS snapshot jika muncul dan tidak diperlukan,
   - cek secret sisa; scheduled deletion adalah kondisi yang diharapkan,
   - cek resource mahal: NAT, RDS, ALB, ECS/EC2, S3 workload, dan CloudFront;
     tepat satu ECR bootstrap boleh tetap ada selama campaign.
5. Jangan hapus backend remote state kecuali target berubah menjadi nol biaya
   absolut dan siap bootstrap ulang nanti.

Jika destroy berhenti setelah sebagian resource terhapus, jangan mengulang
saved plan lama. Jalankan workflow `action=destroy` lagi agar refresh state dan
plan baru mencerminkan resource tersisa. Approve hanya jika plan recovery tetap
`0 create`, `0 update`, dan seluruh aksi adalah destroy yang diharapkan.

Catatan implementasi: variable `force_destroy` atau deletion-protection
override tidak dapat diandalkan untuk mengubah atribut
resource yang langsung dihapus oleh destroy plan. Karena itu workflow memakai
pre-step eksplisit, terbatas pada nama/prefix workload Eepistore, sebelum
menjalankan saved plan yang telah direview.

## Cost Audit Notes

- AWS Billing/Cost Explorer tetap perlu dicek manual karena data biaya tidak
  selalu real-time.
- Resource yang harus tidak aktif setelah destroy: NAT Gateway, RDS instance,
  ALB, ECS tasks/container instances, EC2 ECS instances, S3 workload buckets,
  CloudFront media distribution, dan RDS snapshots yang tidak diperlukan.
- Resource yang sengaja boleh tersisa: domain, hosted zone, Terraform state
  bucket, lockfile object, KMS backend, serta ECR bootstrap selama campaign.

## Final Experiment Lineage

- App publish: run `30056560034`.
- Terraform rollout dan post-apply verification: run `30057073750`.
- Functional, ZAP, tiga trial k6, CloudWatch, dan cleanup: run `30057455143`.
- Canonical evidence reprocess: run `30060088000`.
- Final state-empty destroy: run `30063265875`.
