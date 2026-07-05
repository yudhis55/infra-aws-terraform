# Project Status

This document replaces the older "complete" summary. The infrastructure is not
considered production-complete until Terraform plan/apply and AWS verification
evidence have been captured.

## Current Status

- Terraform source is being hardened for a production-like DevSecOps thesis
  environment.
- The target architecture is ECS EC2 launch type with an Auto Scaling Group,
  ALB/WAF HTTPS ingress, RDS PostgreSQL Multi-AZ through RDS Proxy, private S3,
  CloudFront OAC for public media, and CloudWatch evidence.
- Remote state bootstrap exists under `bootstrap/state-backend`, but the main
  environment must still be migrated to the S3 backend before serious apply.
- CI/CD workflow files exist, but GitHub OIDC roles, repository variables, and
  environment approval must be configured before execution.

## Not Yet Complete

- No final AWS apply evidence is stored in this repository.
- No post-apply verification evidence is stored in this repository.
- No BAB 4 experimental result should be claimed from this file.
- GuardDuty and Security Hub are not part of the Terraform baseline unless a
  later change explicitly adds and verifies them.

## Required Before Final Thesis Evidence

1. Commit only safe source files; never commit `terraform.tfvars`, state, plan
   binaries, `.terraform/`, or generated scan artifacts.
2. Bootstrap remote Terraform state with S3, DynamoDB locking, and KMS.
3. Push an immutable application image to ECR and pass its commit SHA tag to
   Terraform as `app_image_uri`.
4. Review `terraform plan` before apply.
5. After apply, run the AWS verification runbook and keep artifacts from
   Terraform, AWS CLI, CloudWatch, scanner, and load test outputs.
