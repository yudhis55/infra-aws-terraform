# Module: ecs

Menjalankan aplikasi fullstack Next.js pada Amazon ECS EC2 launch type dengan
Auto Scaling Group, capacity provider, ALB, HTTPS listener, CloudWatch Logs, dan
ALB access logs.

## Resource Utama

- ECS cluster, task definition, service
- EC2 launch template dan Auto Scaling Group
- ECS capacity provider
- Application Load Balancer dan target group
- HTTP listener atau HTTPS listener dengan ACM certificate
- ECS task execution role, task role, dan instance role
- CloudWatch log group
- S3 bucket untuk ALB access logs

## Catatan Operasional

Task definition memakai `bridge` network mode dengan dynamic host port mapping.
Karena itu ECS service yang mendaftarkan target `instance:dynamic-port` ke ALB,
bukan Auto Scaling Group.

Untuk production, `enable_https=true` wajib disertai `acm_certificate_arn` yang
sudah valid. Self-signed certificate tidak dipakai.

