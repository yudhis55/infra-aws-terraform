# GitHub OIDC IAM Baseline

Direktori ini menyimpan policy IAM yang dipakai oleh GitHub Actions. Bootstrap
IAM sengaja dipisahkan dari workload state agar role apply tidak mengelola
permission miliknya sendiri.

## Role

- `eepistore-app-deploy-role`: hanya memublikasikan image ke
  `eepistore-repo`. Nama role dipertahankan untuk kompatibilitas secret GitHub,
  walaupun role tidak lagi melakukan deployment ECS.
- `eepistore-infra-plan-role`: memakai AWS managed `ReadOnlyAccess` dan inline
  policy `plan-backend-policy.json` untuk membaca state serta mengelola S3
  lockfile.
- `eepistore-infra-apply-role`: memakai AWS managed `PowerUserAccess` dan inline
  policy `apply-iam-policy.json` untuk IAM resource project yang tidak dicakup
  PowerUserAccess.
- `eepistore-infra-experiment-role`: memakai trust policy environment
  `production` dan inline `experiment-evidence-policy.json`. Role ini hanya
  menjalankan one-off fixture task, membaca telemetry runtime, serta membersihkan
  object pada kelas prefix eksperimen.

Tidak ada role GitHub yang boleh memakai `AdministratorAccess`.

## Trust Boundary

- App publish hanya dapat diasumsikan oleh environment `production` repo
  `yudhis55/eepistore`.
- Infra plan hanya dapat diasumsikan dari branch `main` repo
  `yudhis55/infra-aws-terraform`.
- Infra apply hanya dapat diasumsikan oleh environment `production` repo
  `yudhis55/infra-aws-terraform`.
- Infra experiment hanya dapat diasumsikan oleh environment `production` repo
  `yudhis55/infra-aws-terraform`.

Environment `production` dan branch `main` harus tetap dilindungi di GitHub.

## Operasional

Policy ini berisi account ID dan resource name project yang aktual. Jika project
dipindah ke account atau repository lain, review seluruh ARN dan subject OIDC
sebelum menggunakannya.

Setelah perubahan policy, gunakan IAM policy simulator dan workflow plan untuk
memastikan permission cukup. Jangan memulihkan `AdministratorAccess` hanya
karena satu action kurang; tambahkan action minimum yang dibuktikan oleh log
`AccessDenied`.

Simpan ARN role experiment sebagai secret repository
`AWS_EXPERIMENT_ROLE_ARN`. Role ini tidak memiliki izin Terraform apply.
