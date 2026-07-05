# Architecture Decision Record

## Keputusan Final

Target implementasi skripsi DevSecOps ini memakai arsitektur production penuh
single-region di AWS dengan model berikut:

- Compute: Amazon ECS EC2 launch type dengan Auto Scaling Group dan capacity
  provider.
- Runtime aplikasi: fullstack Next.js dalam satu container.
- Ingress publik: Route53 -> AWS WAF regional -> Application Load Balancer
  HTTPS -> ECS service.
- Data path: ECS task -> RDS Proxy -> Amazon RDS PostgreSQL Multi-AZ.
- Object storage: Amazon S3 private sebagai origin object, CloudFront + Origin
  Access Control untuk media publik, dan akses signed/private untuk objek
  sensitif.
- Observability: CloudWatch Logs, metrics, alarms, dashboards, WAF logs, VPC
  Flow Logs, dan artifact CI/CD.
- Repository: aplikasi dan IaC dipisah agar pipeline, permission, dan evidence
  akademik tidak bercampur.

## Alasan

Model ECS EC2/ASG selaras dengan gambar infrastruktur BAB 3 yang menampilkan
ECS Container Instances dan ECS Tasks di private subnet. Pilihan ini juga cocok
untuk pembahasan DevSecOps karena memberi ruang evaluasi terhadap network
isolation, IAM role, image deployment, auto scaling, observability, dan
post-apply verification.

Standar production penuh dipakai agar klaim keamanan tidak sekadar demo. Karena
itu desain tidak memakai self-signed TLS, public database, public ECS task,
static AWS access key, atau bucket S3 publik langsung.

## Batasan

- Scope tetap single-region, bukan multi-region disaster recovery.
- GuardDuty atau Security Hub hanya boleh masuk naskah jika benar-benar
  diaktifkan dan punya evidence.
- BAB 4 hanya boleh berisi hasil eksperimen aktual dari pipeline, Terraform,
  AWS, scanner, dan load testing.

## Konsekuensi Implementasi

- Terraform harus memiliki remote backend S3, DynamoDB locking, dan KMS.
- ALB harus memakai ACM certificate valid melalui DNS validation.
- ECS deploy harus memakai immutable image tag berbasis commit SHA dan
  Terraform menerima image final melalui variable `app_image_uri`, bukan
  default `latest`.
- RDS harus private, encrypted, Multi-AZ, protected, dan diakses via RDS Proxy.
- S3 uploads tidak boleh mengandalkan bucket public read sebagai default.
- CI/CD aplikasi dan IaC harus menghasilkan artifact yang dapat dipakai sebagai
  bukti skripsi.
