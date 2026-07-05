# Module: cdn

Membuat CloudFront distribution untuk membaca media publik dari S3 private
melalui Origin Access Control.

## Resource Utama

- CloudFront Origin Access Control
- CloudFront distribution
- S3 bucket policy yang hanya mengizinkan CloudFront distribution membaca objek

## Catatan Operasional

Module ini bisa memakai default CloudFront domain atau custom media domain.
Untuk production project ini, caller mengirim alias `media.eepistore.web.id`
dan ACM certificate dari `us-east-1` karena CloudFront hanya menerima viewer
certificate ACM dari region tersebut.

Bucket origin tetap private. CloudFront membaca objek melalui Origin Access
Control, lalu bucket policy membatasi akses ke ARN distribution ini saja.
