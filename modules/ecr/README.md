# Module: ecr

Membuat repository container image aplikasi.

## Resource Utama

- `aws_ecr_repository.app`

## Catatan Operasional

Repository memakai immutable tag agar deployment production selalu mengacu pada
commit SHA tertentu. Pipeline aplikasi tidak boleh bergantung pada tag `latest`
untuk deployment production.

