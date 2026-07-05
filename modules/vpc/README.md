# Module: vpc

Membuat fondasi jaringan: satu VPC, dua public subnet, dua private app subnet,
dua private data subnet, Internet Gateway, dan route table publik.

## Resource Utama

- `aws_vpc.this`
- `aws_subnet.public`
- `aws_subnet.private_app`
- `aws_subnet.private_data`
- `aws_internet_gateway.this`
- public route table ke Internet Gateway

## Catatan Operasional

Private route table tidak dibuat di module ini. Routing private app/data sengaja
dipindahkan ke module `networking` agar NAT Gateway, VPC endpoints, dan isolasi
data tier bisa dikelola sebagai boundary keamanan terpisah.

