# Evidence Register

Dokumen ini mencatat metadata evidence yang aman disimpan di Git. Artifact
mentah, Terraform state, plan binary, secret, dan output yang memuat data
sensitif tetap disimpan di GitHub Actions atau media lokal yang di-ignore.

## Current Infrastructure State

- Research campaign v2 berstatus `Valid final`. Dua clean provisioning cycle,
  paket 18 source run, schema canonical `2.0.0`, dan arsip offline lulus pada
  aggregation run `31578428362`.
- Terraform state workload kosong dibuktikan ulang oleh run `31570617948`,
  artifact `post-destroy-verification`, dengan status
  `PASS terraform-state-empty` dan `PASS aws-workload-resources-absent`.
- Audit AWS setelah destroy tidak menemukan VPC, NAT Gateway, EC2/ECS/ASG,
  ALB, RDS/RDS Proxy, CloudFront, secret aktif, atau bucket workload Eepistore.
- Tepat satu ECR bootstrap sengaja dipertahankan agar image digest identik dapat
  dipakai pada Cycle R dan Cycle F.
- Remote backend S3, native lockfile, KMS backend, domain, hosted zone, dan
  sertifikat regional domain utama sengaja dipertahankan.
- Data Billing dan Cost Explorer harus diperiksa terpisah karena tidak
  real-time.

## Final Research Campaign v2

Campaign `campaign-20260812-f3346ec-671db9f` adalah baseline final untuk BAB 4.
Lineage dibekukan pada app commit
`f3346ec59d52830f1dcbf592f905f7fbc4136248`, infra commit
`671db9fb6cc5c0454c9be334d67ea3b59e7e27f2`, image digest
`sha256:e08451c0dbc21a84d74c30b9953984306731cafcf2ffe6c89ee571bb83b47ab7`,
dan input digest
`sha256:a356d390461a8bc491975aaa703519ea2a9b703c2226d5d940b3190909751cc7`.

Canonical aggregation run `31578428362` menghasilkan artifact
`canonical-campaign-campaign-20260812-f3346ec-671db9f-31578428362` dengan
artifact ID `9134123578`, status `final`, dan seluruh sepuluh section `passed`.
Artifact GitHub berakhir pada `2026-11-10T08:27:47Z`; salinan offline yang
manifest-nya telah diverifikasi wajib disimpan sebelum tanggal tersebut.

| Area | Final evidence | Source run | Status |
| --- | --- | --- | --- |
| App publish | App commit dan image digest immutable sesuai frozen lineage | `31172403493` | Valid final |
| Cycle R | Plan 16 detik, apply 1.307 detik, verification 71 detik; 141 resource dibuat lalu dihancurkan | Apply `31544258763`; destroy `31548407610` | Valid final |
| Cycle F | Plan 14 detik, apply 1.195 detik, verification 75 detik; input sama dengan Cycle R | Apply `31549677809`; destroy `31570617948` | Valid final |
| Fault injection | 6/6 positive-control terdeteksi dan 6/6 delivery diblokir | App `31551535975`, `31551537764`, `31551539727`; infra `31551541553`, `31551543141`, `31551544758` | Valid final |
| Controlled drift | Satu tag drift diinjeksi, recovery plan tepat satu update, lalu no-change plan | Injection `31551868621`; recovery `31551921512` | Valid final |
| WAF rate protection | 134 request terbatas, satu HTTP 429, metric dan sampled request cocok, time-to-detect 70,65 detik | `31552432036` | Valid final |
| Functional | Playwright: 1 expected, 0 unexpected/flaky/skipped, durasi 38.379,895 ms | Runtime `31553375900` | Valid final |
| Network isolation | 11/11 outcome sesuai; 9 VPC reject berkorelasi, 1 S3 private HTTP 403, 1 positive control sukses | Runtime `31553375900` | Valid final |
| DAST | 9 alert: 2 informational, 3 low, 4 medium, 0 high; 7 unique rules; 0 confirmed high/critical | Runtime `31553375900` | Valid final; temuan medium/low perlu dibahas per konteks |
| Load/scaling | 3/3 trial lulus; median p95 82,074 ms; throughput 19,661 req/s; failure rate median 0%; ECS scale-out 3/3 | Runtime `31553375900` | Valid final untuk profil beban terbatas |
| Monitoring | 9/9 required series terisi; 13 series tersedia; 0 unexpected application error | Runtime `31553375900` | Valid final |
| Fixture cleanup | Seluruh residual database, object S3, agent, dan temporary resource bernilai nol | Runtime `31553375900`; cleanup `31570286703` | Valid final |
| Final destroy | Plan 141 destroy; state kosong dan 16 kategori workload bernilai nol; satu ECR prerequisite dipertahankan | `31570617948` | Valid final |

Tiga trial load menghasilkan p95 `82,074`, `80,471`, dan `87,649` ms;
throughput `19,661`, `19,697`, dan `19,595` request/detik; serta scale-in
`1.095,340`, `1.043,214`, dan `1.108,781` detik. ASG capacity scaling
teramati dan berstatus `observed-passed`. Angka tersebut hanya berlaku untuk
profil, region, commit, image digest, dan periode campaign ini.

CloudWatch mencatat satu pesan error dari negative security probe dengan server
reference ID malformed `x`. Event mentah tetap ada dalam canonical archive,
tetapi diklasifikasikan terpisah dari unexpected application error karena
merupakan input invalid yang sengaja dikirim oleh pengujian. Repeatability
Cycle R/F membandingkan identitas pemeriksaan, bukan jumlah container instance
dinamis (4 pada Cycle R dan 6 pada Cycle F).

Audit tambahan menggunakan profil lokal IAM Identity Center tidak selesai pada
`2026-08-12` karena sesi SSO kedaluwarsa. Hal ini tidak membatalkan evidence
primer: auditor OIDC dalam destroy run `31570617948` membuktikan state kosong,
seluruh resource workload berbiaya nol, snapshot final nol, dan hanya satu ECR
bootstrap yang sengaja dipertahankan. Billing/Cost Explorer tetap perlu dicek
manual karena data biaya tidak real-time.

## Superseded Diagnostic Campaign Baseline

Baseline berikut digunakan oleh campaign diagnostik
`campaign-20260807-405139f-c803f2a`. Campaign dihentikan dan tidak berstatus
`Valid final` setelah gate metric WAF menemukan kesalahan semantik dimensi
CloudWatch. Commit infra baru, campaign ID baru, dan input digest baru wajib
dibekukan setelah perbaikan digabungkan.

| Input | Frozen value | Verification |
| --- | --- | --- |
| App commit | `405139fbad17dd45ddc2d3e7ed5416fbac3af3ec` | App `main`; quality, SAST, SCA, build, SBOM, dan container scan lulus |
| App publish | Run `30860780456` | Artifact `published-image`; publish ECR dan attestation sukses |
| Image digest | `sha256:bbdab02f18702a384dbcf4519be73d522febc32eaaa4936f92c53ca6c089a560` | GitHub variable memakai immutable digest URI |
| Infra commit | `c803f2ae8c72221183fd93202b26dd25ecc76fe4` | PR `#51` merged; main CI run `31145560821` lulus |
| Default Terraform plan | Run `31145648300` | `141 create, 0 update, 0 delete, 0 replace`; tidak dijalankan apply |
| Clean starting state | Run `31136824762` | State kosong dan seluruh kategori workload nol; satu ECR bootstrap dipertahankan |

Cycle R apply `31146233163` dan destroy `31147951717` lulus. Cycle F apply
`31149111839`, agent `31150898679`, drift injection `31151173812`, drift
recovery `31151227111`, dan rate-mode transition `31151486664` juga lulus.
Bounded WAF run `31151708568` menghasilkan 134 request, tepat satu HTTP 429,
dan satu sampled request yang cocok, tetapi gate metric gagal karena query
memakai visibility metric ACL sebagai nilai dimensi `WebACL`. Cleanup
`31152100706` dan destroy `31152404189` kemudian lulus; state serta seluruh
kategori workload kembali nol.

AWS `list-metrics` membuktikan bahwa dimensi seri aktual adalah
`WebACL=eepistore-waf-acl` dan `Rule=ExperimentRateLimitMetric`. Query read-only
dengan pasangan dimensi tersebut mengembalikan `BlockedRequests Sum=1` untuk
jendela pengujian. Bukti manual ini hanya mendukung diagnosis; evidence final
tetap harus dihasilkan ulang oleh workflow yang telah diperbaiki.

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
| `31081037634` | Generator menghasilkan 131 request dan berhenti pada satu HTTP 429; sampled request WAF cocok, tetapi seri CloudWatch kosong | Perbaikan awal menyamakan dimensi `WebACL` dengan visibility metric ACL; campaign berikutnya membuktikan asumsi ini masih salah | Invalid campaign; valid observability-dimension finding yang superseded |
| `31125920820` | Cleanup yang sebelumnya gagal mendapat runner selama outage GitHub Actions dijalankan ulang dengan saved plan `0 create, 2 update, 7 destroy, 0 replace` | Agent eksperimen dihapus, source IP set kembali ke sentinel, mode WAF kembali `off`, dan verifier eksperimen lulus | Valid recovery/cleanup evidence; non-canonical |
| `31136824762` | Controlled destroy memakai plan `0 create, 0 update, 141 destroy, 0 replace`; ECS drain selesai sebelum apply | State kosong, seluruh kategori workload dan snapshot final nol, satu ECR prerequisite tetap ada | Valid recovery/clean baseline; kandidat titik awal campaign berikutnya |
| `31151708568` | Bounded run menghasilkan 134 request, satu HTTP 429, dan satu sampled request cocok; metric kosong karena dimensi `WebACL` memakai `eepistore-waf-metrics` | AWS `list-metrics` membuktikan nilai yang benar adalah resource name `eepistore-waf-acl`; workflow, collector, alarm, dashboard, dan test regresi dikoreksi, lalu stack dihancurkan oleh run `31152404189` | Invalid campaign; valid stop-condition and observability finding |
| `31166827234` / `31168340801` | Bounded WAF trial pertama mencapai batas 150 request sebelum rate rule yang bersifat approximate mulai memblokir; trial kedua dijalankan setelah propagation hold dengan parameter tetap dan berhenti pada request ke-140 dengan satu HTTP 429 | Trial gagal dan cleanup `31167014001` tetap dicatat; trial kedua menghasilkan CloudWatch `BlockedRequests=1`, satu sampled BLOCK, dan tanpa scope violation | Trial pertama invalid; trial kedua valid bounded-control evidence |
| `31169565199` | Runtime suite berhenti pada precondition karena role eksperimen belum memiliki `ecr:DescribeRepositories`; tidak ada fixture, ZAP, network probe, atau k6 yang dijalankan | Tambahkan hanya `ecr:DescribeRepositories` pada repository `eepistore-repo`, perluas validator IAM, sinkronkan policy, lalu ulangi suite setelah cleanup `31169671738` | Invalid runtime evidence; valid least-privilege stop-condition finding |
| `31486942488` | Kalibrasi dan trial pertama mengamati scale-out ECS/ASG serta request sehat, tetapi trial berhenti karena scale-in pertama melewati batas 1.200 detik | Cooldown ketiga target-tracking policy diseragamkan menjadi 60 detik; campaign dibatalkan, cleanup `31497690870` dan destroy `31501978573` mengembalikan state kosong | Invalid runtime evidence; valid scalability stop-condition finding |
| `31522532194` | Setelah cooldown policy diseragamkan, kalibrasi lulus dengan scale-in 1.074,662 detik, sedangkan trial pertama mencatat scale-in 1.264,454 detik; threshold tetap 1.200 detik dan data tidak diubah | Workflow diperbaiki agar threshold miss dipertahankan sebagai hasil, tiga trial tetap dikumpulkan, dan tiap trial menunggu baseline ECS/ASG yang sama; cleanup `31533795300` sukses dengan `0 create, 2 update, 7 destroy, 0 replace`; recovery destroy `31542449772` menghapus 141 resource dan membuktikan state kosong | Invalid canonical campaign; valid pilot/stop-condition and clean-baseline evidence |

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
