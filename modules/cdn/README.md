# Module: cdn

Membuat CloudFront distribution untuk membaca media publik dari S3 private
melalui Origin Access Control.

## Resource Utama

- CloudFront Origin Access Control
- CloudFront distribution
- S3 bucket policy yang hanya mengizinkan CloudFront distribution membaca objek

## Catatan Operasional

Module ini memakai default CloudFront certificate. Jika ingin custom media
domain, tambahkan certificate ACM di `us-east-1` dan alias CloudFront secara
terpisah.

