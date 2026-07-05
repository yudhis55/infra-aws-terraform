# Module: certificate

Membuat ACM certificate dan melakukan DNS validation di Route53.

## Resource Utama

- ACM certificate
- Route53 validation records
- ACM certificate validation

## Catatan Operasional

Untuk ALB regional, panggil module dengan provider default region aplikasi.
Untuk CloudFront custom domain, panggil module dengan provider alias
`us-east-1`, karena CloudFront hanya menerima ACM viewer certificate dari region
tersebut. Gunakan `certificate_purpose` agar tag certificate mudah dibedakan di
AWS.
