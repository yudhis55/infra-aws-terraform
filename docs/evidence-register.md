# Evidence Register

Dokumen ini mencatat metadata evidence yang aman disimpan di Git. Artifact
mentah, Terraform state, plan binary, secret, dan output yang memuat data
sensitif tetap disimpan di GitHub Actions atau media lokal yang di-ignore.

## Current Infrastructure State

- Research campaign v2 belum menjadi evidence final sampai dua clean cycle dan
  paket 18 run lulus agregasi canonical.
- Terraform state workload kosong dibuktikan ulang oleh run `31061976370`, artifact
  `post-destroy-verification`, dengan status `PASS terraform-state-empty`.
- Audit AWS setelah destroy tidak menemukan VPC, NAT Gateway, EC2/ECS/ASG,
  ALB, RDS/RDS Proxy, CloudFront, secret aktif, atau bucket workload Eepistore.
- Tepat satu ECR bootstrap sengaja dipertahankan agar image digest identik dapat
  dipakai pada Cycle R dan Cycle F.
- Remote backend S3, native lockfile, KMS backend, domain, hosted zone, dan
  sertifikat regional domain utama sengaja dipertahankan.
- Data Billing dan Cost Explorer harus diperiksa terpisah karena tidak
  real-time.

## Evidence Rules

- `Valid historical baseline`: dapat menjelaskan perkembangan dan uji awal,
  tetapi tidak menggantikan campaign v2 final.
- `Valid final`: hanya diberikan setelah campaign v2 canonical lulus.
- `Valid recovery`: menjelaskan kegagalan terkontrol dan perbaikannya, bukan
  hasil utama performa atau keamanan.
- `Stale`: sudah digantikan oleh evidence yang lebih baru.
- `Deferred`: tidak boleh diklaim sebagai fitur atau hasil implementasi.

## Historical Baseline Evidence Inventory

Paket run `300*` berikut tetap valid sebagai baseline implementasi Juli 2026,
tetapi berstatus historis setelah kontrak penelitian v2 mengunci dua clean
provisioning cycle dan paket canonical 18 run.

| Area | Evidence | Source | Status | BAB 4 Usage |
| --- | --- | --- | --- | --- |
| App image publish | App commit `6727099a4b930b6c1e0e0ca0ef9bd0cc5b565ba2`; digest `sha256:eb54f55db076b931a860e618a76753256f94426e441203a6f84173ce488bd170` | App run `30056560034`; artifact `published-image`, SBOM, scan, dan attestation | Valid historical baseline | Bukti awal image immutable; superseded oleh campaign v2 |
| Final Terraform rollout | Plan 34 detik, apply 20 detik, migration 46 detik, verification 156 detik | Infra run `30057073750`; artifact `terraform-plan-review`, `migration-evidence`, dan `post-apply-verification` | Valid historical baseline | Bukti rollout awal; bukan Cycle R/F campaign v2 |
| Functional and authorization | 1 expected suite, 0 unexpected, 0 flaky, 0 skipped; durasi 29.862 detik | Experiment run `30057455143`; Playwright evidence dalam artifact `final-experiment-evidence-30057455143` | Valid historical baseline | Bukti uji awal; capture ulang untuk campaign v2 |
| DAST OWASP ZAP | 9 alert: 2 informational, 3 low, 4 medium, 0 high; 7 unique rules; tidak ada blocking finding | Experiment run `30057455143`; ZAP JSON/HTML dan normalized summary | Valid historical baseline | Data DAST awal; capture ulang untuk campaign v2 |
| k6 trial 1 | 1,470 request; failure rate 0%; checks 100%; p95 296.113 ms; throughput 2.717 req/s | Experiment run `30057455143`; k6 trial summary | Valid historical baseline | Trial reguler awal dalam budget WAF |
| k6 trial 2 | 1,458 request; failure rate 0%; checks 100%; p95 291.125 ms; throughput 2.693 req/s | Experiment run `30057455143`; k6 trial summary | Valid historical baseline | Trial reguler awal dalam budget WAF |
| k6 trial 3 | 1,466 request; failure rate 0%; checks 100%; p95 303.977 ms; throughput 2.714 req/s | Experiment run `30057455143`; k6 trial summary | Valid historical baseline | Trial reguler awal dalam budget WAF |
| k6 aggregate | 3/3 trial lulus; median p95 296.113 ms; median throughput 2.714 req/s; median failure rate 0% | Corrected canonical evidence dari reprocess run `30060088000` | Valid historical baseline | Ringkasan performa awal; bukan bukti bahwa DevSecOps meningkatkan performa |
| Monitoring | ALB, ECS CPU/memory, ASG, RDS, dan WAF series terkumpul; application error events 0 | Experiment run `30057455143`; CloudWatch evidence | Valid historical baseline | Bukti observability awal; capture ulang untuk campaign v2 |
| Cleanup fixture | 4 user dan 1 store dihapus; residual user/store/order/product 0; residual object public/private 0 | Experiment run `30057455143`; conformance 42 passed, 0 failed | Valid historical baseline | Bukti isolasi awal; capture ulang untuk campaign v2 |
| Canonical package | Status `final`, experiment ID `exp-30057455143-1`, manifest SHA-256 `9c4f9cb48c7dda3845f31466b54652f0e228a5540db31efb0f454b8312d44905` | Reprocess run `30060088000`; artifact `reprocessed-final-experiment-evidence-30057455143` | Valid historical baseline | Canonical schema 1 lama; bukan canonical campaign v2 |
| Final controlled destroy | Plan terakhir `0 add, 0 change, 3 destroy`; state kosong | Run `30063265875`; artifact `terraform-plan-review` dan `post-destroy-verification` | Valid historical baseline | Bukti teardown awal |
| Post-destroy AWS audit | Workload utama tidak ditemukan; hanya backend/domain yang disengaja tetap ada | AWS CLI read-only audit `2026-07-24` | Valid historical baseline | Catatan operasional baseline Juli |

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
| `30870725305` | Fresh apply selesai, tetapi migration task dimulai sebelum readiness runtime terbukti dan keluar dengan kode 1 | Log migration diarsipkan dan gate RDS Proxy `AVAILABLE` ditambahkan sebelum task | Valid recovery |
| `30872524245` | Rerun idempoten setelah target matang menyelesaikan tiga migration dan seluruh post-apply verifier PASS | Mendukung diagnosis readiness race; run tidak dipakai sebagai Cycle R | Valid recovery |
| `30872856860` | Destroy parsial menunggu ECS service `DRAINING` sampai timeout 45 menit | Pre-destroy ECS scale-to-zero, autoscaling suspension, dan target drain ditambahkan | Valid recovery |
| `30875541625` | Destroy lanjutan menghapus 67 resource tersisa | State kosong, seluruh workload count nol, ECR retained satu | Valid recovery/clean baseline |
| `30965178973` | Fresh apply gagal karena log group VPC Flow Logs muncul kembali di luar state | Izin `CreateLogGroup` dicabut dari role Flow Logs dan audit destroy kini mewajibkan `vpcFlowLogGroups=0` | Valid recovery; bukan Cycle R |
| `30967301286` | Full destroy melewati timeout ECS service 45 menit walaupun pre-drain lulus | Timeout Terraform dinaikkan menjadi 60 menit; continuation run `30970089169` menghapus 67 resource tersisa dan membuktikan state kosong, workload nol, Flow Logs group nol, serta ECR retained satu | Valid recovery/clean baseline |
| `30973278848` | Cycle R destroy mencoba final snapshot ketika RDS tidak berstatus `available` | Workflow eksperimen menetapkan `skip_final_snapshot=true` sejak apply; audit destroy menghitung snapshot final dan cleanup recovery dibatasi prefix exact | Invalid Cycle R; valid recovery finding |
| `30975324252` | Apply dan verifikasi operasional lulus, tetapi artifact drift plan memuat satu update normalisasi `iam_auth` RDS Proxy sementara verifier salah mencatat no drift | `iam_auth="DISABLED"` dibuat eksplisit dan drift gate diubah agar memeriksa setiap action non-`no-op` dari saved plan JSON | Invalid Cycle R; valid recovery finding |
| `30977187906` | Stack dari Cycle R yang dibatalkan dihancurkan dengan plan 140 destroy | State kosong, seluruh workload count nol, snapshot final nol, Flow Logs group nol, dan satu ECR prerequisite tetap ada | Valid recovery/clean baseline |
| `31017342567` | Exact-tag drift recovery ditolak karena module-level dependency memperluas perubahan menjadi replacement experiment agent dan update KMS policy | Emergency rollback run `31017571822` menghapus tag exact; dependency RDS/experiment dikembalikan ke resource-scoped input references | Invalid campaign; valid stop-condition evidence |
| `31017727741` | Stack campaign yang dibatalkan dihancurkan dengan plan 147 destroy | State dan resource workload diverifikasi kosong sebelum baseline baru | Valid recovery/clean baseline |
| `31061853071` | Positive-control `FI-IAC-02` tidak menghasilkan finding HIGH/CRITICAL karena fixture hanya membuka PostgreSQL dan tidak memenuhi severity gate Trivy yang dipin | Fixture diubah menjadi unrestricted ingress seluruh protokol; wajib lulus preflight fault sebelum clean cycle berikutnya | Invalid fault evidence; valid stop-condition evidence |
| `31061976370` | Stack campaign dibatalkan setelah fault matrix tidak lengkap dan dihancurkan dengan plan 147 destroy | State dan resource workload diverifikasi kosong sebelum fixture diperbaiki | Valid recovery/clean baseline |
| `31063347824` | Preflight `FI-IAC-02` pada fixture unrestricted ingress menghasilkan finding sesuai severity gate | Positive-control IaC dinyatakan siap sebelum resource AWS dibuat | Valid preflight; bukan bagian dari 18 run canonical |
| `31063409823` / `31065078156` | Cycle R pada commit infra `eeadcf4c` selesai dengan plan 140 create, seluruh verifier PASS, zero drift, lalu 140 destroy | Menunjukkan satu clean provisioning cycle, tetapi campaign tidak dipakai sebagai hasil final karena Cycle F berikutnya gagal | Valid recovery/repeatability observation; non-canonical |
| `31066242977` | Cycle F membuat 140 resource, tetapi one-off migration pertama gagal dengan Prisma `P1001` walaupun target RDS Proxy sudah `AVAILABLE` | Stop condition dijalankan; eksperimen tidak dimulai dan run tidak dipakai sebagai Cycle F final | Invalid campaign; valid readiness-race finding |
| `31067840407` | Retry diagnostik dengan plan `0/0/0/0` menyelesaikan migration dan post-apply verification tanpa perubahan infrastruktur | Membuktikan kegagalan sebelumnya bersifat transien pada data-plane readiness; runner migration diberi retry terbatas khusus `P1001` | Valid diagnostic; non-canonical |
| `31068112570` | Stack campaign `eeadcf4c` yang dibatalkan dihancurkan dengan plan 140 destroy | State kosong, seluruh workload count nol, snapshot final nol, dan satu ECR prerequisite tetap ada | Valid recovery/clean baseline |
| `31074746171` | WAF rate run berhenti pada precondition karena experiment agent AL2023 berstatus SSM Online tetapi `docker` belum tersedia; tidak ada request uji yang dikirim | Bootstrap agent diberi retry, marker readiness, dan cloud-init diagnostics; campaign tidak dipakai sebagai hasil final | Invalid campaign; valid stop-condition evidence |
| `31074789854` | Cleanup otomatis memulihkan sebagian state, tetapi penghapusan WAF IP set ditolak dengan `WAFAssociatedItemException` saat Web ACL masih berpropagasi | Web ACL diberi dependency eksplisit terhadap temporary IP set agar update terjadi sebelum penghapusan | Valid recovery finding; cleanup parsial |
| `31075285225` | Continuation cleanup masih merencanakan update WAF dan delete IP set dalam run yang sama tanpa dependency baru | Run dibatalkan sebelum approval/apply untuk menghindari pengulangan error asosiasi | Valid stop-condition evidence; no mutation |
| `31075924747` | Dependency eksplisit belum memaksa update-before-delete karena Web ACL hanya diperbarui, bukan dihancurkan; AWS kembali menolak delete IP set | IP set diubah menjadi baseline dormant dengan sentinel `127.0.0.1/32`; cleanup selanjutnya melakukan update alamat, bukan delete | Valid recovery finding; campaign tetap invalid |
| `31076733012` | Cleanup pertama dengan IP set dormant merencanakan dan menerapkan tepat dua update WAF in-place tanpa delete atau replacement | Output membuktikan mode `off`, agent tidak ada, permanent deny aktif, dan rule eksperimen sementara tidak ada | Valid recovery/cleanup evidence; non-canonical |
| `31077536146` | Agent AL2023 mencapai SSM, tetapi bootstrap gagal karena policy S3 gateway endpoint menolak bucket paket resmi `al2023-repos-ap-southeast-3-de612dc2` dengan HTTP 403; precondition menghentikan run sebelum request uji dikirim | Endpoint policy diberi allowlist read-only untuk bucket regional AL2023 dan regression test ditambahkan | Invalid campaign; valid stop-condition and network-policy finding |
| `31077865454` | Cleanup setelah diagnostic WAF merencanakan 7 delete agent dan 2 update WAF in-place | Cleanup selesai, agent dihapus, dan WAF kembali ke baseline dormant tanpa association race | Valid recovery/cleanup evidence; non-canonical |
| `31078592898` / `31078929903` | S3 endpoint policy AL2023 diterapkan sebagai satu update in-place; post-apply verification lulus dan agent baru berhasil bootstrap dengan Docker ready | Membuktikan allowlist bucket paket resmi memperbaiki private agent tanpa membuka seluruh S3 | Valid recovery/network remediation evidence; non-canonical |
| `31079409441` | Bounded request sequence mencapai satu HTTP 429 dan sampled request WAF sesuai endpoint, tetapi normalisasi menyimpan hasil validasi `jq` sebagai boolean serta query CloudWatch memakai end time sebelum datapoint matang | Pisahkan validasi dari penulisan object JSON dan perluas akhir jendela metric hingga waktu koleksi setelah propagation wait | Invalid campaign; valid evidence-normalization finding |
| `31079904633` | Cleanup yang sudah direview dibatalkan ketika merge PR memicu run `push` pada concurrency group yang sama | Concurrency group dipisahkan berdasarkan event agar validasi branch tidak dapat membatalkan operasi manual; cleanup dijalankan ulang sebelum eksperimen berikutnya | Valid workflow-race finding; no cleanup mutation occurred |

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
