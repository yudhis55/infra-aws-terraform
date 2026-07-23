# Module: storage

Membuat dua S3 bucket private dengan batas akses yang berbeda.

## Resource Utama

- S3 bucket media publik untuk `products`, `avatars`, dan `banners`
- S3 bucket dokumen privat untuk `payments` dan `verifications`
- bucket ownership controls
- versioning
- server-side encryption
- public access block
- CORS untuk presigned browser upload

## Catatan Operasional

Kedua bucket tidak memberi public read policy. Hanya bucket media publik yang
menjadi origin module `cdn` melalui CloudFront Origin Access Control. Bucket
dokumen privat tidak terhubung ke CloudFront; objek pembayaran dan verifikasi
hanya diakses melalui route aplikasi yang memeriksa relasi data pengguna.

CORS hanya dipakai untuk browser upload lewat presigned URL. Caller harus
mengirim origin eksplisit seperti `https://eepistore.web.id`; wildcard tidak
diterima untuk baseline production.
