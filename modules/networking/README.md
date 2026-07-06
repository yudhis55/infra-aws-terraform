# Module: networking

Mengelola routing private, NAT Gateway per AZ, VPC endpoints, dan security group
utama untuk ALB, ECS, RDS, serta endpoint interface.

## Resource Utama

- NAT Gateway dan Elastic IP per AZ
- route table private app menuju NAT Gateway per AZ
- route table private data tanpa internet route
- S3 Gateway Endpoint
- ECR, Secrets Manager, dan CloudWatch Logs Interface Endpoints
- security group ALB, ECS, RDS, dan VPC endpoint

## Catatan Operasional

Private data subnet tidak memiliki default route internet. Secara default,
aplikasi tidak diberi jalur langsung ke RDS; koneksi database harus melewati
RDS Proxy. Direct ECS -> RDS hanya boleh diaktifkan dengan
`allow_ecs_direct_rds_access=true` untuk kebutuhan break-glass/debugging.

S3 Gateway Endpoint dibatasi ke bucket yang diteruskan melalui
`s3_endpoint_allowed_bucket_arns`. Untuk environment utama, isi variable ini
dengan bucket upload aplikasi agar endpoint policy tidak wildcard ke seluruh S3.
Policy juga mengizinkan `s3:GetObject` ke bucket internal ECR
`prod-<region>-starport-layer-bucket/*`. Jalur ini diperlukan agar ECS EC2 di
private subnet bisa menarik image layer dari ECR melalui S3 gateway endpoint.
