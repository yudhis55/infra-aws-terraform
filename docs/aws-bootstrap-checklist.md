# AWS Bootstrap Checklist

Gunakan checklist ini setelah ACM certificate untuk `eepistore.web.id` sudah
berstatus `Issued`. Jangan jalankan `apply` production sebelum semua nilai
placeholder diganti dengan nilai asli.

Catatan status pasca-destroy: remote backend dan ECR bootstrap dipertahankan,
sedangkan ECS, RDS, ALB, S3 workload, serta CloudFront dihapus. Jika ECR belum
pernah dibootstrap, jalankan workflow khusus sebelum app `publish-image`.

## 1. Domain dan Certificate

- [ ] Route 53 public hosted zone untuk `eepistore.web.id` sudah ada.
- [ ] Nameserver domain di registrar mengarah ke empat nameserver Route 53.
- [ ] ACM certificate regional di `ap-southeast-3` sudah `Issued`.
- [ ] Certificate mencakup `eepistore.web.id` dan `www.eepistore.web.id`.
- [ ] Catat hosted zone ID dan ACM certificate ARN.

## 2. GitHub OIDC dan Environment

- [ ] OIDC provider `https://token.actions.githubusercontent.com` tersedia di IAM.
- [ ] Role infra plan dibuat untuk repo `infra-aws-terraform`.
- [ ] Role infra apply dibuat untuk environment `production`.
- [ ] Role app publish dibuat untuk repo `eepistore` environment `production`.
- [ ] GitHub environment `production` memakai required reviewer.
- [ ] Branch deployment dibatasi ke branch utama (`main` atau `master`).

## 3. GitHub Vars dan Secrets Final

Infra repository variables:

- [ ] `AWS_REGION=ap-southeast-3`
- [ ] `TF_VAR_PROJECT_NAME=eepistore`
- [ ] `TF_VAR_DOMAIN_NAME=eepistore.web.id`
- [ ] `TF_VAR_ROUTE53_ZONE_ID=<hosted-zone-id-asli>`
- [ ] `TF_VAR_ENABLE_HTTPS=true`
- [ ] `TF_VAR_ACM_CERTIFICATE_ARN=<arn-acm-ap-southeast-3>`
- [ ] `TF_VAR_APP_BASE_URL=https://eepistore.web.id`
- [ ] `TF_VAR_APP_IMAGE_URI=<ecr-url>@sha256:<digest>`

Infra repository secrets:

- [ ] `AWS_PLAN_ROLE_ARN=<arn-role-plan>`
- [ ] `AWS_APPLY_ROLE_ARN=<arn-role-apply>`

Password master RDS dan `AUTH_SECRET` dibuat oleh Terraform lalu disimpan di
Secrets Manager. Nilai tersebut tidak disimpan sebagai GitHub secret.

App repository variables:

- [ ] `AWS_REGION=ap-southeast-3`
- [ ] `ECR_REPOSITORY=eepistore-repo`
- [ ] `APP_URL=https://eepistore.web.id`

App repository secrets:

- [ ] `AWS_DEPLOY_ROLE_ARN=<arn-role-publish-image>`

## 4. Remote State Bootstrap

- [ ] Jalankan bootstrap `bootstrap/state-backend`.
- [ ] Catat output bucket S3 dan KMS key.
- [ ] Salin nilai output ke backend configuration environment utama.
- [ ] Jalankan migrasi state ke remote backend.
- [ ] Pastikan backend memakai `use_lockfile = true`.
- [ ] Pastikan Terraform state tidak tersimpan di Git.

## 5. ECR dan Image Aplikasi

- [ ] Jika ECR bootstrap belum ada, jalankan `bootstrap-ecr.yml` dengan
      `action=apply`.
- [ ] Review saved plan dan approve environment `production`; pastikan plan
      hanya berisi module ECR beserta KMS terkait.
- [ ] Simpan artifact `ecr-bootstrap-verification`.
- [ ] Build aplikasi lulus secara lokal dan/atau GitHub Actions.
- [ ] Push image dengan tag commit SHA, rekam digest, dan jangan gunakan
      `latest`.
- [ ] Isi `TF_VAR_APP_IMAGE_URI` memakai URI digest immutable dari workflow app.

## 6. Terraform Plan Review

- [ ] Jalankan workflow Terraform dengan action `plan`.
- [ ] Unduh dan review `tfplan.txt`.
- [ ] Pastikan resource publik hanya ALB/CloudFront.
- [ ] Pastikan ECS dan RDS berada di private subnet.
- [ ] Pastikan RDS Proxy punya target RDS.
- [ ] Pastikan ALB HTTPS aktif memakai ACM certificate.
- [ ] Pastikan WAF attached ke ALB.
- [ ] Pastikan S3 tidak public langsung.
- [ ] Pastikan CloudWatch alarm/dashboard memakai dimension yang benar.

## 7. Apply Terkontrol

- [ ] Jalankan workflow Terraform dengan action `apply`.
- [ ] Approve environment `production` secara manual.
- [ ] Simpan artifact Terraform plan, apply log, dan post-apply verification.
- [ ] Jika verification menemukan mismatch, jangan lanjut BAB 4 sebelum gap dicatat.

## 8. Migration, Runtime, dan Evidence

- [ ] Pastikan workflow app hanya memublikasikan image digest dan tidak mengubah ECS.
- [ ] Pastikan Terraform menjadi satu-satunya pemilik task definition dan ECS service.
- [ ] Pastikan RDS Proxy target `AVAILABLE` pada `proxy-readiness.json` sebelum migration task dimulai.
- [ ] Pastikan migration task selesai dengan exit code `0` dan log CloudWatch tersimpan dalam artifact.
- [ ] Pastikan ECS service stable.
- [ ] Jalankan workflow runtime evidence setelah stack aktif.
- [ ] Simpan artifact ZAP, k6, health, readiness, dan verifikasi AWS.
