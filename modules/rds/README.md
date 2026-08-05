# Module: rds

Membuat Amazon RDS PostgreSQL Multi-AZ, RDS Proxy, Secrets Manager, encryption,
backup, enhanced monitoring, dan parameter group.

## Resource Utama

- RDS PostgreSQL instance
- DB subnet group
- DB parameter group
- KMS key untuk encryption
- Secrets Manager secret untuk kredensial
- RDS Proxy, default target group, target RDS, dan security group proxy
- IAM role enhanced monitoring

## Catatan Operasional

RDS Proxy hanya boleh menerima koneksi dari security group ECS. Aplikasi harus
menggunakan endpoint proxy, bukan endpoint RDS langsung, agar connection pooling
lebih stabil untuk fullstack Next.js.

Blok autentikasi proxy menetapkan `iam_auth = "DISABLED"` secara eksplisit karena
aplikasi memakai kredensial Secrets Manager. Nilai eksplisit ini juga mencegah
normalisasi default provider menghasilkan plan update berulang setelah apply.

Production default memakai deletion protection dan final snapshot.
