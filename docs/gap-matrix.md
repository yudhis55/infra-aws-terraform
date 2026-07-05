# Gap Matrix

Dokumen ini menjadi daftar kerja utama untuk menilai kesesuaian BAB 3, kode
Terraform, aplikasi, dan CI/CD terhadap pedoman production penuh.

| Area | Kondisi target | Kondisi yang ditemukan | Status | Tindakan |
| --- | --- | --- | --- | --- |
| BAB 3 compute | ECS EC2/ASG | Teks aktif sudah diarahkan ke ECS EC2/ASG | Partial | Ganti gambar aplikasi lama saat finalisasi naskah |
| BAB 3 app | Fullstack Next.js container | Teks aktif sudah diganti dari React-Hapi ke Next.js | Partial | Ganti gambar aplikasi lama saat finalisasi naskah |
| BAB 3 RDS | RDS PostgreSQL Multi-AZ primary/standby | Uraian sudah mengarah ke Multi-AZ, gambar masih perlu caption final | Partial | Perjelas caption final |
| Ingress | Route53 -> WAF/ALB HTTPS | ACM certificate module dan HTTPS listener disiapkan | Partial | Jalankan apply dan validasi ACM/ALB di AWS |
| Terraform state | S3 backend + DynamoDB lock + KMS | Bootstrap backend dan backend example tersedia | Partial | Jalankan bootstrap di AWS lalu migrate state |
| ECS image | Immutable image SHA | ECR immutable, workflow deploy SHA, dan variable `app_image_uri` tersedia | Partial | Verifikasi deploy ECS nyata |
| ECS capacity | ASG capacity provider | Capacity provider ditambahkan | Partial | Verifikasi service placement di AWS |
| RDS | Encrypted, Multi-AZ, deletion protection, final snapshot | Default production-safe ditambahkan | Partial | Verifikasi resource RDS nyata |
| RDS Proxy | ECS -> RDS Proxy -> RDS | Proxy ingress dibatasi ke ECS SG dan target RDS terdaftar | Partial | Verifikasi proxy target healthy di AWS |
| S3 media | S3 private + CloudFront OAC | Module CDN/OAC ditambahkan dan public bucket policy dihapus | Partial | Verifikasi CloudFront/OAC di AWS |
| S3 sensitif | Private/signed access | Route private upload access memakai relasi order/verifikasi | Partial | Uji akses buyer/seller/admin setelah deploy |
| CI/CD app | Quality, security, image, deploy, ZAP, k6, artifact | Workflow deploy immutable SHA dan evidence tersedia | Partial | Jalankan di GitHub dengan vars/secrets |
| CI/CD IaC | fmt, validate, lint, scan, plan, approval, apply, verify | TFLint, gated apply, dan post-apply evidence ditambahkan | Partial | Jalankan di GitHub dengan environment protection |
| AWS verification | State vs actual AWS resource verified | Runbook dan script tersedia | Partial | Jalankan setelah apply |
| BAB 4 | Hasil eksperimen aktual | Masih template/klaim generik | Gap | Isi setelah evidence tersedia |

## Prioritas

1. Backend state, TLS/ACM, RDS/S3 safety, dan ECS capacity provider.
2. CI/CD IaC/app dengan approval dan artifact evidence.
3. Verifikasi AWS aktual setelah apply.
4. Revisi BAB 3 berdasarkan implementasi final.
5. Eksperimen BAB 4 dan penulisan hasil dari data nyata.
