# BAB 4 Experiment Matrix

Matriks ini menjadi daftar evidence yang harus tersedia sebelum BAB 4 ditulis.
Status `Missing` berarti klaim belum boleh dimasukkan sebagai hasil final.

| Experiment | Input | Execution | Required Artifact | Metrics / Checks | Pass Criteria | Current Status |
| --- | --- | --- | --- | --- | --- | --- |
| App quality gate | Latest app commit | App workflow `ci` or `publish-image` | Quality logs | lint, typecheck, unit tests | All pass | Valid candidate run `29983090390`; rerun after experiment utility changes |
| SAST | Latest app commit | CodeQL in app workflow | CodeQL result | high/critical findings | No untriaged high/critical | Valid baseline; rerun for final package |
| SCA | `package-lock.json` | npm audit gate | `npm-audit.json` | known vulnerabilities | No unaccepted high/critical | Valid baseline; rerun for final package |
| Container scan | Docker image | Trivy image scan | `trivy-image.txt` | high/critical CVEs | No untriaged high/critical | Valid baseline; rerun if image changes |
| Image publish | Immutable app commit SHA | App workflow `publish-image` | `published-image` and attestation | image digest and source SHA | Terraform input uses digest URI | Valid candidate run `29983090390`; republish after automation changes |
| ECR bootstrap | Terraform ECR module | Terraform target/minimal apply before image publish | ECR repository URL | repo exists and image tag can be pushed | ECR available before full ECS apply | Valid bootstrap; ECR retained |
| IaC quality gate | Infra commit | Terraform workflow scan job | `terraform-security-evidence` | fmt, validate, TFLint, Trivy, Checkov | All gates pass with documented exact suppressions | Valid candidate run `29983467498`; rerun after automation changes |
| Terraform plan | Final GitHub vars/secrets | Terraform workflow `action=plan` or apply run plan job | `terraform-plan-review/tfplan.txt` | add/change/destroy summary, critical resources | No unexpected destroy/replacement | Valid candidate run `29983467498`: `139/0/0`; rerun required |
| Terraform apply | Reviewed plan from same run | Terraform workflow `action=apply` | apply log and `post-apply-verification` | drift, AWS resources, runtime checks | All required checks PASS | Valid baseline run `28765301534`; rerun for final package if needed |
| AWS actual verification | Terraform outputs | `scripts/verify-aws-post-apply.sh` plus manual review | verification JSON files | VPC, ALB, ECS, RDS, RDS Proxy, S3, CloudFront, WAF | State matches AWS actual resources | Valid baseline; manual evidence incomplete |
| Runtime smoke | Live app domain | curl checks | `smoke-status.txt`, health/readiness JSON | HTTPS, HTTP redirect, health, readiness | Expected 200/redirect and JSON `status=ok` | Automation prepared; live evidence missing |
| Functional checks | Isolated temporary users and ECS fixture task | Playwright | Playwright JSON/HTML, failure-only screenshots | login roles, public upload, private object authorization | All assertions pass and fixture cleanup passes | Automation prepared; live evidence missing |
| DAST | Live HTTPS domain | Bounded ZAP Automation Framework | ZAP JSON/HTML and normalized summary | alerts by risk and unique rule | No untriaged high risk; medium reviewed | Automation prepared; live evidence missing |
| Load test | Public read-only endpoints | k6 smoke plus staged 10/25/50 VU, three trials | trial summary JSON | errors, checks, p50/p95/p99, throughput | Error `<1%`, checks `>99%`, p95 `<1000ms` | Automation prepared; live evidence missing |
| Monitoring evidence | Bounded runtime test window | AWS CLI/CloudWatch collector | normalized metric series and AWS snapshots | ALB, ECS, ASG, RDS, WAF, logs | Window and resource provenance match experiment | Automation prepared; live evidence missing |
| Canonical aggregation | All artifacts with one experiment ID | Evidence aggregator and JSON Schema validator | `experiment-evidence.json`, manifest | workflow provenance, completeness, zero-residual database/S3 cleanup, three trials, CloudWatch core series, checksum | Status `final`; no stale, failed, partial, missing, or residual experiment data | Local schema/unit validation passed; live evidence missing |
| Destroy | Evidence already captured | Terraform workflow `action=destroy` | `post-destroy-verification` | state empty, costly resources gone | PASS and no costly leftovers | Valid run `28767137374` |

## Deferred Items Not For BAB 4 Claims

- CloudFront WAF/access logging, origin failover, geo restriction, and default
  root object.
- DNSSEC and public hosted zone query logging.
- Secrets Manager automatic rotation.
- Customer-managed KMS for every log group, bucket, and SNS topic.
- GuardDuty and Security Hub.
