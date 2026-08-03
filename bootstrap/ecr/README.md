# ECR bootstrap state

This root module owns the immutable Eepistore application repository separately
from the workload stack. It is applied once before publishing the frozen image
and is intentionally retained across Cycle R and Cycle F. This keeps the exact
image digest available while each workload cycle can still end with an empty
`env/dev` state.

The repository remains Terraform-owned. Normal workload destroy must not delete
it. Removing this bootstrap is a separate, explicit operation after the academic
archive no longer needs a repeatable redeployment path.
