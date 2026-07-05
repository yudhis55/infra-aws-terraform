# Module: storage

Membuat S3 bucket private untuk upload aplikasi.

## Resource Utama

- S3 bucket upload
- bucket ownership controls
- versioning
- server-side encryption
- public access block
- CORS untuk presigned browser upload

## Catatan Operasional

Bucket tidak memberi public read policy. Media publik disajikan melalui module
`cdn` dengan CloudFront Origin Access Control. Objek sensitif seperti pembayaran
dan verifikasi tetap diakses melalui signed URL atau route aplikasi.

