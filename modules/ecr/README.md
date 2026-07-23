# Module: ecr

Membuat repository container image aplikasi.

## Resource Utama

- `aws_ecr_repository.app`
- dedicated KMS key with rotation for image encryption

## Catatan Operasional

Repository memakai immutable tag agar deployment production selalu mengacu pada
commit SHA tertentu. Pipeline aplikasi tidak boleh bergantung pada tag `latest`
untuk deployment production.

Pipeline aplikasi hanya membangun, memindai, membuat SBOM/attestation, dan
memublikasikan image. Terraform menjadi satu-satunya pemilik task definition dan
ECS service deployment.
