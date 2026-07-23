# Project Status

This document replaces the older "complete" summary. The infrastructure is not
considered production-complete until Terraform plan/apply and AWS verification
evidence have been captured.

Status as of 2026-07-23: the stack was applied successfully once, verified, and
then destroyed for cost control. A remediation branch now changes the app, IaC,
pipeline, storage boundary, and IAM model, so the previous runtime evidence is
historical rather than final.

## Current Status

- Terraform source is being hardened for a production-like DevSecOps thesis
  environment.
- The target architecture is ECS EC2 launch type with an Auto Scaling Group,
  ALB/WAF HTTPS ingress, RDS PostgreSQL Multi-AZ through RDS Proxy, private S3,
  CloudFront OAC for public media, and CloudWatch evidence.
- Remote state backend exists and is intentionally retained after workload
  destroy.
- CI/CD workflow files, GitHub OIDC, repository variables, and environment
  approval have been exercised for the baseline apply/destroy cycle.

## Not Yet Complete

- Final BAB 4 evidence is not yet complete.
- Raw GitHub Actions artifacts are not stored in this repository; only safe
  metadata is recorded in `docs/evidence-register.md`.
- ZAP, k6, functional smoke, and monitoring evidence still need to be captured
  for the final BAB 4 package.
- No BAB 4 experimental result should be claimed from this file.
- GuardDuty and Security Hub are not part of the Terraform baseline unless a
  later change explicitly adds and verifies them.

## Required Before Final Thesis Evidence

1. Commit only safe source files; never commit `terraform.tfvars`, state, plan
   binaries, `.terraform/`, or generated scan artifacts.
2. Keep remote Terraform state with S3 native locking and KMS unless the
   user explicitly chooses a full backend teardown.
3. Push an immutable application image to ECR and pass its commit SHA tag to
   Terraform as `app_image_uri`.
4. Review `terraform plan` before apply.
5. After apply, run the AWS verification runbook and keep artifacts from
   Terraform, AWS CLI, CloudWatch, scanner, and load test outputs.
