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

Production default memakai deletion protection dan final snapshot.
