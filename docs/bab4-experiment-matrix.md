# BAB 4 Experiment Matrix

Matriks ini menjadi daftar evidence yang harus tersedia sebelum BAB 4 ditulis.
Status `Missing` berarti klaim belum boleh dimasukkan sebagai hasil final.

| Experiment | Input | Execution | Required Artifact | Metrics / Checks | Pass Criteria | Current Status |
| --- | --- | --- | --- | --- | --- | --- |
| App quality gate | Latest app commit | App workflow `ci` or `publish-image` | Quality logs | lint, typecheck, unit tests | All pass | Remediation valid locally; GitHub run missing |
| SAST | Latest app commit | CodeQL in app workflow | CodeQL result | high/critical findings | No untriaged high/critical | Valid baseline; rerun for final package |
| SCA | `package-lock.json` | npm audit gate | `npm-audit.json` | known vulnerabilities | No unaccepted high/critical | Valid baseline; rerun for final package |
| Container scan | Docker image | Trivy image scan | `trivy-image.txt` | high/critical CVEs | No untriaged high/critical | Valid baseline; rerun if image changes |
| Image publish | Immutable app commit SHA | App workflow `publish-image` | `published-image` and attestation | image digest and source SHA | Terraform input uses digest URI | Previous image stale; remediation publish missing |
| ECR bootstrap | Terraform ECR module | Terraform target/minimal apply before image publish | ECR repository URL | repo exists and image tag can be pushed | ECR available before full ECS apply | Missing after destroy; required before next publish |
| IaC quality gate | Infra commit | Terraform workflow scan job | `terraform-security-evidence` | fmt, validate, TFLint, Trivy, Checkov | All gates pass with documented exact suppressions | Remediation valid locally; GitHub run missing |
| Terraform plan | Final GitHub vars/secrets | Terraform workflow `action=plan` or apply run plan job | `terraform-plan/tfplan.txt` | add/change/destroy summary, critical resources | No unexpected destroy/replacement | Missing final post-destroy rerun |
| Terraform apply | Reviewed plan from same run | Terraform workflow `action=apply` | apply log and `post-apply-verification` | drift, AWS resources, runtime checks | All required checks PASS | Valid baseline run `28765301534`; rerun for final package if needed |
| AWS actual verification | Terraform outputs | `scripts/verify-aws-post-apply.sh` plus manual review | verification JSON files | VPC, ALB, ECS, RDS, RDS Proxy, S3, CloudFront, WAF | State matches AWS actual resources | Valid baseline; manual evidence incomplete |
| Runtime smoke | Live app domain | curl/browser checks | smoke evidence | HTTPS, HTTP redirect, health, readiness | Expected 200/redirect and JSON `status=ok` | Health/readiness valid baseline; login/upload missing |
| Functional checks | Seeded users/data | Browser/API test | screenshots or test notes | login, upload public media, private object auth | Expected role-based access | Missing |
| DAST | Live HTTPS domain | OWASP ZAP baseline | `zap-report.json`, `zap-report.html` | alerts by risk | No untriaged high risk | Missing |
| Load test | Live `/api/health` and selected app paths | k6 | `k6-summary.json` | failure rate, p95 latency | Thresholds met and documented | Missing |
| Monitoring evidence | Live AWS stack | AWS Console/CLI | CloudWatch/log screenshots or JSON | logs, metrics, alarms/dashboard, ECS events | Evidence captured and interpretable | Missing |
| Destroy | Evidence already captured | Terraform workflow `action=destroy` | `post-destroy-verification` | state empty, costly resources gone | PASS and no costly leftovers | Valid run `28767137374` |

## Deferred Items Not For BAB 4 Claims

- CloudFront WAF/access logging, origin failover, geo restriction, and default
  root object.
- DNSSEC and public hosted zone query logging.
- Secrets Manager automatic rotation.
- Customer-managed KMS for every log group, bucket, and SNS topic.
- GuardDuty and Security Hub.
