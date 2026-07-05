# Module: monitoring

Membuat CloudWatch alarms, dashboards, SNS alerting, dan metric filter aplikasi.

## Resource Utama

- SNS topic dan optional email subscription
- ALB, ECS, RDS, WAF, ASG, dan application error alarms
- CloudWatch dashboards
- log metric filter dari ECS log group

## Catatan Operasional

Dimension alarm dan dashboard harus memakai resource aktual: ALB ARN suffix,
target group ARN suffix, ECS cluster/service name, RDS instance identifier, ASG
name, WAF Web ACL name, dan log group yang dibuat Terraform. Output module lain
harus diteruskan ke module ini agar alarm tidak menjadi metrik kosong.
