# Module: certificate

Membuat ACM certificate regional untuk ALB dan melakukan DNS validation di
Route53.

## Resource Utama

- ACM certificate
- Route53 validation records
- ACM certificate validation

## Catatan Operasional

Module ini untuk ALB regional. Jika CloudFront memakai custom domain, certificate
CloudFront harus dibuat di `us-east-1` secara terpisah.

