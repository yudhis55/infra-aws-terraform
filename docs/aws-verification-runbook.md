# AWS Post-Apply Verification Runbook

Runbook ini dijalankan setelah `terraform apply` untuk memastikan kondisi AWS
aktual sesuai Terraform state dan pedoman BAB 3.

Untuk alur plan, approval apply, dan destroy hemat biaya, gunakan
`docs/operations-runbook.md`. Dokumen ini fokus pada verifikasi setelah stack
berhasil dibuat.

## Prasyarat

- AWS credentials tersedia melalui GitHub OIDC atau profile lokal yang sah.
- Terraform sudah memakai remote backend.
- Domain dan ACM DNS validation sudah selesai.
- Container image sudah dipush ke ECR, digest immutable telah diverifikasi, dan
  URI berbasis digest diberikan ke Terraform sebagai `app_image_uri`.

## Langkah Verifikasi

1. Catat output Terraform.
   - `terraform output`
   - Simpan output sebagai artifact `terraform-output.txt`.

2. Cek state dan drift.
   - `terraform plan -detailed-exitcode`
   - Exit code `0` berarti tidak ada drift.
   - Exit code `2` berarti ada perubahan/drift yang harus dianalisis.

3. Cek network boundary.
   - VPC memiliki public, private app, dan private data subnet di dua AZ.
   - Public route hanya menuju Internet Gateway.
   - Private app route menuju NAT Gateway per AZ.
   - Private data subnet tidak punya route internet.

4. Cek ingress dan TLS.
   - Route53 alias mengarah ke ALB.
   - ACM certificate status `ISSUED`.
   - ALB listener 443 aktif.
   - Listener 80 redirect ke 443.
   - WAF Web ACL terasosiasi ke ALB.

5. Cek ECS.
   - Cluster aktif.
   - Capacity provider terpasang.
   - ECS service stabil.
   - Task berjalan di private app subnet atau ECS instances lintas AZ.
   - Target group healthy.
   - Image task definition memakai exact ECR digest yang dibekukan untuk
     campaign, bukan `latest` atau tag mutable.

6. Cek database.
   - RDS tidak public.
   - Multi-AZ aktif.
   - Storage encrypted.
   - Backup retention aktif.
   - Deletion protection aktif untuk production.
   - RDS Proxy available, memiliki target RDS terdaftar, dan security group
     hanya menerima dari ECS.

7. Cek storage.
   - S3 bucket private dan public access block aktif.
   - CloudFront distribution enabled.
   - Origin Access Control terpasang.
   - Objek sensitif tidak dapat diakses publik.

8. Cek observability.
   - ECS logs masuk CloudWatch.
   - WAF logs masuk log destination.
   - VPC Flow Logs aktif.
   - Alarm CloudWatch dibuat dan memiliki dimension yang benar.
   - Dashboard memuat ALB, ECS, RDS, WAF, dan ASG metrics.

9. Cek runtime aplikasi.
   - `https://<domain>/api/health` mengembalikan 200.
   - HTTP redirect ke HTTPS.
   - Login/basic flow berhasil.
   - Upload media publik tampil melalui CloudFront.
   - Upload/verifikasi sensitif tidak public.

10. Simpan evidence.
    - Terraform output dan plan drift.
    - ALB target health.
    - ECS deployment event.
    - RDS/RDS Proxy status.
    - Screenshot atau CLI output CloudWatch metrics/logs.
    - ZAP report.
    - k6/JMeter summary.

## Kriteria Lulus

Verifikasi dinyatakan lulus jika semua komponen sesuai pedoman, tidak ada drift,
semua target healthy, HTTPS aktif, dan evidence tersimpan sebagai artifact.

## Status Evidence Saat Ini

- Final rollout dan post-apply verification run `30057073750` lulus.
- Final experiment run `30057455143` melengkapi functional/authorization,
  bounded ZAP, tiga trial k6, CloudWatch, serta cleanup fixture.
- Canonical evidence diperbaiki dan divalidasi ulang secara immutable oleh run
  `30060088000`.
- Final controlled destroy run `30063265875` menghasilkan
  `PASS terraform-state-empty`; audit AWS sesudahnya tidak menemukan workload
  berbiaya utama.
