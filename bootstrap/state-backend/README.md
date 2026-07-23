# Terraform State Backend Bootstrap

Jalankan bootstrap ini sekali sebelum environment utama memakai remote backend.

```powershell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Setelah bucket dan KMS key tersedia, salin nilai output ke
`env/dev/backend.tf`. Backend memakai S3 native state locking melalui
`use_lockfile = true`, lalu jalankan:

```powershell
terraform init -migrate-state
```

State backend sengaja dipisah karena Terraform tidak bisa membuat backend S3
yang sedang dipakai oleh konfigurasi yang sama.
