# Scan Triage Before AWS Apply

This note records scanner findings reviewed before the first controlled AWS
apply. Every remaining finding must be either fixed, accepted as scanner
context, or deferred as future hardening. Deferred items must not be claimed as
implemented evidence in BAB 4.

## Fixed Before Apply

- S3 CORS wildcard: browser upload CORS is restricted to explicit HTTP(S)
  origins. Production resolves to `https://eepistore.web.id`.
- CloudFront default certificate for public media: the media CDN uses custom
  alias `media.eepistore.web.id` with an ACM certificate in `us-east-1`.
- CloudFront response security headers: the media distribution attaches the AWS
  managed security headers response policy.
- ECS writable root filesystem: the app container declares
  `readonlyRootFilesystem=true` with `/tmp` tmpfs.
- Next.js image optimizer runtime cache risk: disabled through
  `images.unoptimized=true` because public media is served by CloudFront.
- CloudWatch retention shorter than one year: ECS, VPC Flow Logs, WAF, DNS
  query logs, and custom monitoring log groups now default to 365 days.
- SNS topic encryption: alarm notification topic uses AWS managed SNS KMS
  encryption.
- RDS minor version upgrades and transport hardening: auto minor upgrades,
  IAM DB authentication, `rds.force_ssl`, and Performance Insights KMS are
  enabled.
- Secrets Manager CMK for generated DB credentials: the RDS credentials secret
  uses the RDS KMS key; RDS Proxy and ECS IAM policies include KMS decrypt for
  runtime secret access.
- VPC subnet public IP defaults: public, private app, and private data subnets
  explicitly disable automatic public IPv4 assignment. Public routing remains
  limited to the ALB subnets.
- Default VPC security group: the default security group is managed with no
  ingress or egress rules.
- S3 lifecycle configuration: Terraform state, upload, and ALB log buckets have
  lifecycle rules for noncurrent versions and incomplete multipart uploads.
- KMS key policy presence: Terraform state and RDS KMS keys define explicit
  account-administration key policies.

## Accepted Scanner Context

- ALB public exposure: accepted. The application entry point is intentionally a
  public ALB. ECS tasks and RDS remain private.
- ALB HTTP listener and port 80 ingress: accepted. With HTTPS enabled, port 80
  is used only for HTTP-to-HTTPS redirect; the forwarding HTTP listener is not
  created.
- ALB WAF finding: accepted as module-context limitation. Terraform creates a
  WAFv2 Web ACL association to the ALB; post-apply verification must prove the
  association exists.
- VPC Flow Logs finding: accepted as module-context limitation. Flow logs are
  created in the security module and must be verified after apply.
- Security group attachment findings: accepted as module-context limitation
  where resources are wired across modules; post-apply verification must prove
  the effective attachments.
- CloudFront TLS finding: accepted as computed-plan context. The plan must show
  `minimum_protocol_version = "TLSv1.2_2021"` and `sni-only`.
- ALB TLS finding: accepted as conditional-resource scanner context. The
  non-HTTPS listener in `modules/ecs/asg.tf` is only created when HTTPS is
  disabled; production sets HTTPS enabled and creates the TLS listener plus
  HTTP redirect.
- ECR customer-managed KMS key: accepted for the existing repository baseline.
  Switching encryption can require replacing or recreating the repository, so
  it is not changed before first apply.
- S3 bucket event notifications: accepted. Terraform state, ALB log, and media
  buckets do not require event notifications for the thesis baseline.

## Deferred Hardening

- CloudFront default root object: deferred/accepted. The distribution is a media
  CDN, not a website origin, so there is no meaningful index document.
- CloudFront geo restriction: deferred. The thesis target is public e-commerce
  access in a single-region architecture, not geo-fenced content.
- CloudFront origin failover: deferred. S3 is the single media origin for this
  production-like thesis scope; multi-origin failover is outside the current
  baseline.
- CloudFront WAF and access logging: deferred. The dynamic application path is
  protected by ALB WAF and ALB logs. CDN WAF/logging must not be claimed in
  BAB 4 unless implemented and verified later.
- Route53 DNSSEC and query logging findings: DNS query logging is optional and
  DNSSEC is deferred because the thesis focuses on workload deployment and
  DevSecOps pipeline evidence, not DNSSEC operations.
- S3 cross-region replication: deferred. The target architecture is
  single-region production-like, not multi-region disaster recovery.
- S3 access logging and customer-managed KMS for every bucket: deferred. Buckets
  are private, encrypted, versioned where relevant, and protected by public
  access block; full logging/KMS-per-bucket hardening can be added after the
  first controlled deployment.
- CloudWatch Logs customer-managed KMS: deferred. Log groups now retain evidence
  for 365 days, but per-log-group CMK policies for CloudWatch Logs are deferred
  until after first deployment to avoid adding untested log-delivery key policy
  risk.
- SNS customer-managed KMS: deferred. Alarm notifications are encrypted with
  AWS managed SNS encryption for the baseline; a dedicated CMK can be added
  later if the thesis scope expands to stricter key ownership controls.
- Secrets Manager automatic rotation: deferred. Rotation requires a tested
  rotation Lambda/strategy and should not be enabled without validating app and
  RDS Proxy behavior.
- Broad egress findings on ALB/ECS/security endpoint groups: accepted/deferred.
  ECS requires controlled outbound paths for AWS APIs, package/runtime
  integrations, payment/email providers, and health operations through NAT/VPC
  endpoints. Least-privilege egress can be refined after runtime flows are
  verified.

## Evidence Required Later

- Terraform plan showing no wildcard S3 CORS and CloudFront alias
  `media.eepistore.web.id`.
- ACM certificate validation for the media domain in `us-east-1`.
- AWS post-apply check proving S3 remains private and CloudFront OAC is active.
- ALB listener check proving HTTP redirects to HTTPS and HTTPS uses TLS 1.2+.
- WAF association check proving the ALB is attached to the regional Web ACL.
- VPC Flow Logs and CloudWatch retention evidence.
- ECS task definition evidence showing immutable image SHA, read-only root
  filesystem, and no runtime `EROFS` errors.
