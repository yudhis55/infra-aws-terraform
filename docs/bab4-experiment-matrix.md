# BAB 4 Experiment Matrix

Matriks ini menghubungkan skenario, artifact, metrik, dan kriteria lulus.
Angka final harus diambil dari canonical evidence, bukan disalin dari log
recovery atau dashboard secara manual.

| Experiment | Input | Execution | Required Artifact | Metrics / Checks | Pass Criteria | Final Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| App quality and security gates | App commit final | App workflow `publish-image` | Quality logs, CodeQL, npm audit, SBOM, Trivy, attestation | job conclusions, CVE/findings, digest | Semua gate wajib sukses; tidak ada high/critical tanpa triage | Run `30056560034`, passed |
| Image publish | App commit final | Publish ke ECR melalui OIDC | `published-image` | source SHA dan digest | Terraform memakai digest immutable yang sama | Run `30056560034`, digest `sha256:eb54f55d...` |
| IaC quality and security gates | Infra commit final | Terraform workflow | `terraform-security-evidence` | fmt, validate, TFLint, Trivy IaC, Checkov | Semua gate sukses dengan suppression terdokumentasi | Run `30057073750`, passed |
| Terraform rollout plan | GitHub vars/secrets final dan image digest | Plan dari run apply yang sama | `terraform-plan-review` | create/update/delete/replace, duration | Tidak ada perubahan tidak terduga; plan direview sebelum approval | Run `30057073750`, plan 34 detik |
| Terraform apply and migration | Saved plan yang direview | Environment approval, apply, one-off Prisma migration | apply timing dan `migration-evidence` | apply/migration status dan duration | Apply dan migration sukses | Run `30057073750`: apply 20 detik, migration 46 detik |
| AWS actual verification | Terraform state/output dan AWS aktual | `scripts/verify-aws-post-apply.sh` | `post-apply-verification` | VPC, ALB, WAF, ECS, RDS Proxy/RDS, S3, CloudFront, health/readiness | Semua required check PASS | Run `30057073750`, verification 156 detik |
| Functional and authorization | Fixture user/store/data terisolasi | Playwright | JSON/HTML report dan failure-only screenshot | expected, unexpected, flaky, skipped, duration | Unexpected 0; cleanup fixture lulus | Run `30057455143`: 1 expected, 0 unexpected |
| DAST | Domain HTTPS milik project | ZAP passive baseline dan bounded active allowlist | ZAP JSON/HTML dan normalized summary | alert per severity, unique rules, blocking list | Tidak ada high/blocking yang belum ditriage | Run `30057455143`: 0 high, 4 medium, 3 low, 2 informational |
| Regular load test | Endpoint publik read-only; baseline 2 VU dan peak 3 VU | Tiga trial k6 identik | Tiga summary JSON | requests, failure, checks, p50/p95, throughput | Failure `<1%`, checks `>99%`, p95 `<1000 ms`; 3/3 trial lulus | Run `30057455143`: median p95 296.113 ms, throughput 2.714 req/s, failure 0% |
| WAF rate-limit detection | Request burst terkontrol pada domain milik project | Recovery trial terpisah dari profil performa | k6 failure evidence dan WAF sampled request | 429/block count dan rule | WAF rate rule menghasilkan block; hasil tidak dicampur dengan performa reguler | Run `30055597919`, confirmed WAF 429 |
| Monitoring | Window eksperimen yang sama | CloudWatch/AWS collector | normalized series dan AWS snapshots | ALB, ECS, ASG, RDS, WAF, app errors | Core series tersedia dan provenance cocok | Run `30057455143`, collected; app error events 0 |
| Cleanup and conformance | Fixture experiment ID | Cleanup task dan schema validation | cleanup JSON dan conformance report | residual DB/S3, passed/failed checks | Semua residual 0 dan conformance failed 0 | Run `30057455143`: 42 passed, 0 failed |
| Canonical aggregation | Semua artifact dari lineage final | Aggregator, JSON Schema, manifest hash | `experiment-evidence.json` | provenance, completeness, trial aggregate, checksum | Status `final`; app/infra/image/run ID konsisten | Reprocess run `30060088000`, status final |
| Dashboard import | Canonical JSON final | `pnpm evidence:import`, typecheck, lint, build | Local generated data | schema and rendering build | Import dan seluruh validation lulus | Local validation passed |
| Controlled destroy | Evidence final sudah diamankan | Terraform `action=destroy` dengan reviewed plans | plan review dan `post-destroy-verification` | state empty dan audit resource berbiaya | State kosong; workload mahal tidak tersisa | Final run `30063265875`, passed |

## Deferred Items Not For BAB 4 Claims

- Perbandingan deployment manual berpasangan.
- DDoS atau request flooding.
- GuardDuty dan Security Hub.
- Multi-region disaster recovery.
- CloudFront WAF/access logging, origin failover, dan geo restriction.
- DNSSEC dan public hosted-zone query logging.
- Secrets Manager automatic rotation.
- Customer-managed KMS untuk setiap log group dan SNS topic.
