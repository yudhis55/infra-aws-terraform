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

## Input Keamanan Jaringan

Security group ALB dan ECS dimiliki oleh module `networking`. Module ECS hanya
menerima ID security group tersebut sehingga aturan jaringan memiliki satu
sumber kebenaran dan tidak diduplikasi.

## Catatan Operasional

EC2 container instances memakai ECS-optimized Amazon Linux 2023 AMI yang dipin
melalui input `ecs_ami_id`. Nilai kandidat diperoleh dari AWS-managed SSM
parameter `/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended`, lalu
diubah hanya melalui source change yang direview. Pinning mencegah alias
`recommended` berubah di antara saved plan, apply, dan verifikasi drift.

Task definition memakai `bridge` network mode dengan dynamic host port mapping.
Karena itu ECS service yang mendaftarkan target `instance:dynamic-port` ke ALB,
bukan Auto Scaling Group.

Container aplikasi memakai read-only root filesystem. Runtime tetap mendapat
tmpfs kecil di `/tmp` untuk kebutuhan sementara Node/Prisma, sementara media
publik dilayani langsung oleh CloudFront sehingga Next image optimizer tidak
perlu menulis cache runtime.

Untuk production, `enable_https=true` wajib disertai `acm_certificate_arn` yang
sudah valid. Self-signed certificate tidak dipakai.

Kapasitas EC2 dan jumlah task ECS memakai input terpisah. `asg_*` mengatur
container instances, sedangkan `service_*` mengatur task aplikasi. Pemisahan ini
mencegah satu nilai scaling dipakai untuk dua lapisan yang berbeda.

Setelah service dibuat, Application Auto Scaling menjadi pemilik nilai runtime
`desired_count`. Terraform mengabaikan atribut tersebut, sedangkan batas minimum
dan maksimum tetap dikelola melalui scalable target. Pemisahan kepemilikan ini
mencegah scale-out yang sah dibaca sebagai drift konfigurasi.

ECS service memakai target tracking CPU, memori, dan
`ALBRequestCountPerTarget`. Target request default 300 request per target per
menit memberi sinyal scale-out yang dapat diukur melalui trafik aplikasi nyata,
tanpa endpoint pembakar CPU khusus eksperimen.
