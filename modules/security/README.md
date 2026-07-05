# Module: security

Mengelola WAF regional untuk ALB, WAF logs, dan VPC Flow Logs.

## Resource Utama

- AWS WAFv2 Web ACL
- AWS managed rule groups untuk common, SQLi, known bad inputs, IP reputation
- rate limiting rule
- WAF association ke ALB
- WAF log group
- VPC Flow Logs ke CloudWatch

## Catatan Operasional

WAF berada pada layer ALB sebagai Web ACL regional. Ia bukan hop jaringan di
dalam VPC, tetapi filter request yang diasosiasikan ke ALB.

