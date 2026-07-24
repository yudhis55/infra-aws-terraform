# Evidence Register

Dokumen ini mencatat metadata evidence yang aman disimpan di Git. Artifact
mentah, Terraform state, plan binary, secret, dan output yang memuat data
sensitif tetap disimpan di GitHub Actions atau media lokal yang di-ignore.

## Current Infrastructure State

- Eksperimen final telah selesai dan workload AWS sudah di-destroy.
- Terraform state kosong dibuktikan oleh run `30063265875`, artifact
  `post-destroy-verification`, dengan status `PASS terraform-state-empty`.
- Audit AWS setelah destroy tidak menemukan VPC, NAT Gateway, EC2/ECS/ASG,
  ALB, RDS/RDS Proxy, ECR, CloudFront, atau bucket workload Eepistore.
- Snapshot manual sisa `eepistore-dev-final-4de2c0ae` sudah dihapus setelah
  audit.
- Secret aplikasi berada dalam scheduled deletion. KMS workload yang telah
  dijadwalkan hapus dapat tetap berstatus `PendingDeletion` sampai masa tunggu
  AWS selesai.
- Remote backend S3, lock table, KMS backend, domain, hosted zone, dan
  sertifikat regional domain utama sengaja dipertahankan.
- Data Billing dan Cost Explorer harus diperiksa terpisah karena tidak
  real-time.

## Evidence Rules

- `Valid final`: dapat dipakai untuk hasil dan analisis BAB 4.
- `Valid recovery`: menjelaskan kegagalan terkontrol dan perbaikannya, bukan
  hasil utama performa atau keamanan.
- `Stale`: sudah digantikan oleh evidence yang lebih baru.
- `Deferred`: tidak boleh diklaim sebagai fitur atau hasil implementasi.

## Final Evidence Inventory

| Area | Evidence | Source | Status | BAB 4 Usage |
| --- | --- | --- | --- | --- |
| App image publish | App commit `6727099a4b930b6c1e0e0ca0ef9bd0cc5b565ba2`; digest `sha256:eb54f55db076b931a860e618a76753256f94426e441203a6f84173ce488bd170` | App run `30056560034`; artifact `published-image`, SBOM, scan, dan attestation | Valid final | Bukti image immutable yang dipakai Terraform |
| Final Terraform rollout | Plan 34 detik, apply 20 detik, migration 46 detik, verification 156 detik | Infra run `30057073750`; artifact `terraform-plan-review`, `migration-evidence`, dan `post-apply-verification` | Valid final | Bukti rollout image, migration, dan verifikasi dari satu run terkontrol |
| Functional and authorization | 1 expected suite, 0 unexpected, 0 flaky, 0 skipped; durasi 29.862 detik | Experiment run `30057455143`; Playwright evidence dalam artifact `final-experiment-evidence-30057455143` | Valid final | Bukti login/role, media, dan otorisasi private object |
| DAST OWASP ZAP | 9 alert: 2 informational, 3 low, 4 medium, 0 high; 7 unique rules; tidak ada blocking finding | Experiment run `30057455143`; ZAP JSON/HTML dan normalized summary | Valid final | Data hasil DAST; medium/low tetap dibahas melalui triage |
| k6 trial 1 | 1,470 request; failure rate 0%; checks 100%; p95 296.113 ms; throughput 2.717 req/s | Experiment run `30057455143`; k6 trial summary | Valid final | Trial reguler dalam budget WAF |
| k6 trial 2 | 1,458 request; failure rate 0%; checks 100%; p95 291.125 ms; throughput 2.693 req/s | Experiment run `30057455143`; k6 trial summary | Valid final | Trial reguler dalam budget WAF |
| k6 trial 3 | 1,466 request; failure rate 0%; checks 100%; p95 303.977 ms; throughput 2.714 req/s | Experiment run `30057455143`; k6 trial summary | Valid final | Trial reguler dalam budget WAF |
| k6 aggregate | 3/3 trial lulus; median p95 296.113 ms; median throughput 2.714 req/s; median failure rate 0% | Corrected canonical evidence dari reprocess run `30060088000` | Valid final | Ringkasan performa utama; bukan bukti bahwa DevSecOps meningkatkan performa |
| Monitoring | ALB, ECS CPU/memory, ASG, RDS, dan WAF series terkumpul; application error events 0 | Experiment run `30057455143`; CloudWatch evidence | Valid final | Bukti observability pada window eksperimen |
| Cleanup fixture | 4 user dan 1 store dihapus; residual user/store/order/product 0; residual object public/private 0 | Experiment run `30057455143`; conformance 42 passed, 0 failed | Valid final | Bukti isolasi serta pembersihan data eksperimen |
| Canonical package | Status `final`, experiment ID `exp-30057455143-1`, manifest SHA-256 `9c4f9cb48c7dda3845f31466b54652f0e228a5540db31efb0f454b8312d44905` | Reprocess run `30060088000`; artifact `reprocessed-final-experiment-evidence-30057455143` | Valid final | Sumber canonical untuk testing-dashboard dan angka BAB 4 |
| Final controlled destroy | Plan terakhir `0 add, 0 change, 3 destroy`; state kosong | Run `30063265875`; artifact `terraform-plan-review` dan `post-destroy-verification` | Valid final | Bukti teardown dan kontrol biaya setelah evidence diamankan |
| Post-destroy AWS audit | Workload utama tidak ditemukan; hanya backend/domain yang disengaja tetap ada | AWS CLI read-only audit `2026-07-24` | Valid final operational | Catatan operasional pendamping artifact state kosong |

## Recovery Evidence

Recovery berikut dipertahankan karena menunjukkan stop condition dan perbaikan
runbook, tetapi tidak menggantikan paket eksperimen final:

| Run | Observation | Resolution | Status |
| --- | --- | --- | --- |
| `30054376463` | ZAP report volume tidak dapat ditulis dan query S3 kosong menghasilkan `None` | Permission volume dan normalisasi hasil kosong diperbaiki | Valid recovery |
| `30055597919` | Profil 50 VU melewati WAF rate rule; 1.36% request gagal dan WAF mengembalikan 429 | Uji performa reguler diubah ke baseline 2 VU/peak 3 VU; rate-limit dicatat sebagai skenario terpisah | Valid recovery/security detection |
| `30060226908` | Destroy parsial: ECR tidak kosong dan ECS service melewati timeout delete 20 menit | ECR pre-clean dan timeout delete ECS 45 menit ditambahkan | Valid recovery |
| `30061608491` | Destroy berhenti pada deletion protection RDS dan ALB | Workflow menonaktifkan protection secara project-scoped sebelum apply destroy | Valid recovery |
| `30062209037` | Destroy berhenti pada object versions/delete markers di tiga bucket workload | Workflow mem-purge seluruh versi untuk prefix bucket workload; backend dikecualikan | Valid recovery |

## Interpretation Boundaries

- WAF block/HTTP 429 pada recovery run `30055597919` membuktikan rate rule
  mendeteksi dan membatasi request burst. Data itu tidak digunakan sebagai
  angka performa reguler.
- Pengujian k6 final memvalidasi perilaku runtime arsitektur pada profil beban
  terbatas, bukan membuktikan bahwa DevSecOps meningkatkan latency.
- Tidak ada klaim DDoS, request flooding, GuardDuty, Security Hub, multi-region,
  atau perbandingan manual berpasangan.
- Temuan ZAP medium/low bukan otomatis kerentanan yang dapat dieksploitasi;
  setiap alert harus dijelaskan berdasarkan endpoint, evidence, dan triage.
- Dashboard lokal hanya memvisualisasikan canonical JSON dan tidak boleh
  mengubah status atau nilai evidence.

## Stale Baselines

Run `28765301534`, `28767137374`, `29983090390`, `29983467498`,
`30008122012`, dan `30008739652` tetap berguna sebagai sejarah pengembangan,
tetapi sudah digantikan lineage final di atas untuk angka utama BAB 4.
