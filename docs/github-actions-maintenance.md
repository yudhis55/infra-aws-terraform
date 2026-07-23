# GitHub Actions Maintenance Baseline

Workflow app dan infra memakai commit SHA immutable. Komentar versi hanya
menjelaskan release asal SHA dan tidak dipakai untuk resolusi action.

## Runtime-Compatible Pins

| Action | Release | Tujuan |
| --- | --- | --- |
| `actions/checkout` | `v7.0.1` | Checkout tanpa persisted Git credential |
| `actions/setup-node` | `v7.0.0` | Node toolchain dan explicit npm cache |
| `actions/upload-artifact` | `v7.0.1` | Evidence upload |
| `actions/download-artifact` | `v8.0.1` | Artifact download dengan digest mismatch sebagai error |
| `github/codeql-action` | `v4.37.3` | CodeQL dan SARIF upload |
| `aws-actions/configure-aws-credentials` | `v6.2.3` | AWS OIDC credentials |
| `hashicorp/setup-terraform` | `v4.0.1` | Terraform setup tanpa Node 20 warning |
| `terraform-linters/setup-tflint` | `v6.3.0` | TFLint setup |
| `actions/attest-build-provenance` | `v4.1.1` | Image provenance |

`anchore/sbom-action`, `aws-actions/amazon-ecr-login`, dan
`bridgecrewio/checkov-action` tetap memakai SHA yang telah dipin karena tidak
menghasilkan warning runtime pada baseline dan tidak memerlukan perubahan
perilaku.

Setelah pin berubah, PR wajib menjalankan seluruh gate. Jangan mengganti SHA
dengan floating major tag. Review release note dan minimum GitHub Actions
runner sebelum maintenance berikutnya.
