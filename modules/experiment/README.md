# Experiment agent module

This opt-in module creates one temporary Amazon Linux 2023 EC2 instance in a
private application subnet. It has no public IP, no inbound security-group
rules, IMDSv2 enforcement, an encrypted root disk, and the AWS-managed minimum
SSM core policy. It exists only to generate bounded, source-stable thesis test
traffic and exact allowlisted connection attempts.

The `ExperimentId`, `ExpiresAt`, and `Temporary` tags are mandatory when the
module is enabled. Normal infrastructure plans keep the module disabled. The
agent and its IAM/profile/security-group resources are removed through a saved
Terraform cleanup plan; they must never be left running after the campaign.

Egress is intentionally limited to HTTPS, VPC DNS, PostgreSQL, and the ECS
dynamic port range. The latter two permit explicit denial tests against known
targets; destination security groups remain the enforcement boundary. No CIDR
or port-range scanning is permitted by the experiment runbook.
