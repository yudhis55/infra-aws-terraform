# IaC Audit Checklist

Checklist ini dipakai saat review Terraform agar kode rapi, aman, dan mudah
dipelajari.

## Struktur dan Kerapian

- Module memiliki tujuan tunggal dan nama yang konsisten.
- Variable memiliki description, type, default yang aman, dan validation jika
  perlu.
- Output hanya mengekspos nilai yang memang dibutuhkan module lain atau CI/CD.
- `locals` dipakai untuk menghindari ekspresi berulang dan menjelaskan intent.
- `depends_on` hanya dipakai jika dependency tidak bisa diturunkan otomatis.
- Komentar inline menjelaskan keputusan desain, bukan mengulang nama resource.
- README module menjelaskan tujuan, resource utama, input/output penting, dan
  catatan operasional.

## Security Baseline

- Tidak ada secret, state, plan, atau credential di Git.
- Remote state memakai S3 encrypted, native lockfile, dan KMS.
- Public ingress hanya ALB pada 80/443; HTTP redirect ke HTTPS.
- ECS dan RDS berada di private subnet.
- Security group mengikuti least privilege antar ALB, ECS, RDS Proxy, dan RDS.
- RDS encrypted, Multi-AZ, backup aktif, deletion protection aktif, dan final
  snapshot tidak dilewati untuk production.
- Secrets Manager dipakai untuk database dan app secret.
- IAM policy task role dibatasi pada bucket, secret, dan resource yang perlu.
- S3 bucket private, encrypted, versioned, dan tidak public by default.
- CloudFront OAC dipakai untuk media publik.

## Observability dan Evidence

- ECS, WAF, ALB, VPC Flow Logs, dan RDS logs punya retention yang jelas.
- CloudWatch alarms memiliki dimension yang mengarah ke resource aktual.
- Dashboard dan alarm mendukung metrik BAB 4.
- Pipeline mengunggah artifact plan, scan, deploy, DAST, load test, dan
  post-apply verification.

## Review Sign-Off

Gunakan status berikut untuk tiap module:

- `PASS`: sesuai pedoman dan sudah tervalidasi.
- `PARTIAL`: bekerja, tetapi masih ada hardening atau dokumentasi.
- `FAIL`: bertentangan dengan pedoman atau belum aman dijalankan.
- `BLOCKED`: butuh informasi eksternal, misalnya domain atau AWS credential.
