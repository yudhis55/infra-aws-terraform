# Scan Triage Before AWS Apply

This note records the handling decision for remaining scanner findings before
the first controlled AWS apply. It should be updated when a finding is fixed,
accepted, or replaced by real evidence from AWS.

## Fixed In This Pass

- S3 CORS wildcard: browser upload CORS is restricted to explicit HTTP(S)
  origins. The environment defaults to the application base URL.
- CloudFront default certificate for public media: the CDN supports a custom
  alias and ACM viewer certificate. The target production media URL is
  `https://media.eepistore.web.id`.
- ECS writable root filesystem: the app container now declares
  `readonlyRootFilesystem=true` with a small `/tmp` tmpfs.
- Next.js image optimizer runtime cache risk: disabled through
  `images.unoptimized=true` because public media is already served by
  CloudFront.

## Accepted Or Deferred For This Thesis Baseline

- CloudFront default root object: accepted. The distribution is a media CDN, not
  a website origin, so there is no meaningful index document.
- CloudFront geo restriction: accepted. The thesis target is single-region
  infrastructure with public e-commerce access, not geo-fenced content.
- CloudFront origin failover: deferred. S3 is the single media origin for this
  production-like thesis scope; multi-origin failover is outside the current
  single-region architecture.
- CloudFront WAF and access logging: deferred hardening. The dynamic
  application path is protected by ALB WAF and ALB logs. CDN WAF/logging must
  not be claimed in BAB 4 unless implemented and verified later.
- ECR customer-managed KMS key: accepted for the existing repository baseline.
  Switching encryption can require replacing or recreating the repository, so
  it is not changed before first apply.
- ALB HTTP listener finding: accepted as scanner context. With HTTPS enabled,
  the active HTTP listener only redirects to HTTPS; the plain HTTP forwarding
  listener is not created.

## Evidence Required Later

- Terraform plan showing no wildcard S3 CORS and CloudFront alias
  `media.eepistore.web.id`.
- ACM certificate validation for the media domain in `us-east-1`.
- AWS post-apply check proving S3 remains private and CloudFront OAC is active.
- Container smoke test or ECS evidence showing no read-only filesystem errors.

