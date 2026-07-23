# Gap Matrix

Dokumen ini menjadi daftar kerja utama untuk menilai kesesuaian BAB 3, kode
Terraform, aplikasi, dan CI/CD terhadap pedoman production penuh.

Status terbaru: stack pernah berhasil di-apply dan diverifikasi pada run
`28765301534`, lalu dihancurkan pada run `28767137374` untuk hemat biaya. Gap
utama sekarang bukan lagi validitas dasar Terraform, melainkan kelengkapan
paket evidence final BAB 4.

| Area | Kondisi target | Kondisi yang ditemukan | Status | Tindakan |
| --- | --- | --- | --- | --- |
| BAB 3 compute | ECS EC2/ASG | Teks aktif sudah diarahkan ke ECS EC2/ASG | Partial | Ganti gambar aplikasi lama saat finalisasi naskah |
| BAB 3 app | Fullstack Next.js container | Teks aktif sudah diganti dari React-Hapi ke Next.js | Partial | Ganti gambar aplikasi lama saat finalisasi naskah |
| BAB 3 RDS | RDS PostgreSQL Multi-AZ primary/standby | Uraian sudah mengarah ke Multi-AZ, gambar masih perlu caption final | Partial | Perjelas caption final |
| Ingress | Route53 -> WAF/ALB HTTPS | Apply baseline membuktikan ALB/listener/WAF/Route53 path berjalan | Valid baseline | Ambil evidence final saat apply ulang |
| Terraform state | S3 backend + native lockfile + KMS | Remote backend aktif dan sengaja dipertahankan setelah destroy | Valid baseline | Jangan hapus kecuali target nol biaya absolut |
| ECS image | Immutable image digest | Image baseline `18fb24f...` sudah stale karena source berubah | Gap | Publish image remediation setelah CI lulus |
| ECS capacity | ASG capacity provider | Post-apply baseline mencatat ECS container instances dan service stable | Valid baseline | Capture ulang untuk BAB 4 final |
| RDS | Encrypted, Multi-AZ, deletion protection, final snapshot | RDS tervalidasi saat apply baseline; snapshot destroy sudah dihapus | Valid baseline | Capture ulang untuk BAB 4 final |
| RDS Proxy | ECS -> RDS Proxy -> RDS | RDS Proxy dan target tervalidasi saat apply baseline | Valid baseline | Capture ulang untuk BAB 4 final |
| S3 media | Bucket media private + CloudFront OAC | Source remediation memisahkan bucket media publik dari dokumen privat | Draft | Verifikasi plan/apply dan uji upload |
| S3 sensitif | Bucket dokumen terpisah + app authorization | Key exact disimpan di database dan route memeriksa relasi order/verifikasi | Draft | Uji akses buyer/seller/admin setelah deploy |
| CI/CD app | Quality, security, SBOM, attestation, image publish | Pipeline hanya memublikasikan image yang sudah dipindai; tidak mengubah ECS | Draft | Rerun CI dan runtime evidence |
| CI/CD IaC | fmt, validate, lint, scan, plan, approval, migrate, apply, verify | Terraform menjadi pemilik tunggal deployment ECS | Draft | Rerun CI dan plan setelah image baru tersedia |
| AWS verification | State vs actual AWS resource verified | Post-apply verification PASS dan destroy state empty PASS | Valid baseline | Tambah functional/monitoring evidence |
| BAB 4 | Hasil eksperimen aktual | Masih template/klaim generik | Gap | Isi setelah evidence tersedia |

## Prioritas

1. Inventaris evidence yang valid, stale, dan missing.
2. Apply ulang hanya jika evidence BAB 4 final siap diambil.
3. Jalankan ZAP, k6, functional smoke, dan monitoring capture saat stack hidup.
4. Destroy ulang setelah evidence aman.
5. Revisi BAB 3 dan BAB 4 berdasarkan evidence final, bukan asumsi.
