# Phase 6: DNS & Route53 Implementation Guide

## Overview

Phase 6 provides complete DNS management infrastructure using AWS Route53 with the following capabilities:

- **Hosted Zone Management**: Create and manage Route53 hosted zones
- **A Records**: Alias records pointing to ALB with optional health checks
- **Subdomains**: Support for www, api, admin, and custom subdomains
- **Health Checks**: Automated health monitoring of ALB endpoint
- **Query Logging**: DNS query logging to CloudWatch for audit/troubleshooting
- **Email**: MX and TXT records for mail and domain verification
- **CDN**: CNAME records for CloudFront distributions

## Module Structure

```
modules/dns/
├── route53.tf         # Route53 hosted zone, records, health checks
├── variables.tf       # Input variables
└── outputs.tf         # Output values
```

## Configuration

### Basic Setup (Development)

By default, DNS module is **disabled** (domain_name = ""). To enable:

```hcl
# env/dev/terraform.tfvars
domain_name        = "example.com"
create_hosted_zone = true
alb_zone_id        = "Z1LMS91P8CMLE5"  # Region-specific
```

### Regional Zone IDs for ALB

The `alb_zone_id` is region-specific. Common zones:

| Region                     | Zone ID        |
| -------------------------- | -------------- |
| ap-southeast-3 (Jakarta)   | Z1LMS91P8CMLE5 |
| ap-southeast-1 (Singapore) | Z1LMS91P8CMLE5 |
| us-east-1 (N. Virginia)    | Z35SXDOTRQ7X7K |
| us-west-2 (Oregon)         | Z1H1FL5HABSF5  |
| eu-west-1 (Ireland)        | Z32O12XQLNTSW2 |
| ap-northeast-1 (Tokyo)     | Z14GRHDCCCW56C |

[Full list](https://docs.aws.amazon.com/general/latest/gr/elb.html)

## Features

### 1. Primary Domain Record

```hcl
# Automatically created if create_hosted_zone = true
example.com  A  <ALB-DNS-NAME>  (with health check)
```

**Use Case**: Main application endpoint
**Health Check**: Monitors ALB on port 80, HTTP GET to "/"

### 2. WWW Subdomain

```hcl
# Controlled by: enable_www_subdomain = true (default)
www.example.com  A  <ALB-DNS-NAME>
```

**Use Case**: Standard web address
**Enable**: Set `enable_www_subdomain = true`

### 3. API Subdomain

```hcl
# Controlled by: create_api_subdomain = true (default: false)
api.example.com  A  <ALB-DNS-NAME>
```

**Use Case**: Separate endpoint for API clients
**Enable**: Set `create_api_subdomain = true`

### 4. Admin Subdomain

```hcl
# Controlled by: create_admin_subdomain = true (default: false)
admin.example.com  A  <ALB-DNS-NAME>
```

**Use Case**: Admin panel at separate URL
**Enable**: Set `create_admin_subdomain = true`

### 5. Email (MX Records)

```hcl
# Controlled by: enable_mx_record = true (default: false)
example.com  MX  10 mail.example.com
```

**Use Case**: Route email to mail server
**Configure**:

```hcl
enable_mx_record = true
mx_records = [
  "10 mail.example.com",    # Primary
  "20 mail2.example.com"    # Secondary
]
```

### 6. Domain Verification (TXT Records)

```hcl
# Controlled by: enable_txt_verification_record = true (default: false)
example.com  TXT  "v=spf1 include:amazon.com ~all"
```

**Use Case**: SPF, DKIM, DMARC for email authentication
**Configure**:

```hcl
enable_txt_verification_record = true
txt_verification_records = [
  "v=spf1 include:amazon.com ~all",
  "v=DMARC1; p=reject;"
]
```

### 7. CDN (CloudFront CNAME)

```hcl
# Controlled by: enable_cdn_cname = true
media.example.com  CNAME  abc123.cloudfront.net
```

**Use Case**: Serve public media from CloudFront
**Configure**:

```hcl
enable_cdn_cname = true
cdn_subdomain = "media"
cloudfront_domain_name = "abc123.cloudfront.net"
```

## Health Checks

### Automatic Health Check

When `enable_health_checks = true` (default):

- **Protocol**: HTTP
- **Port**: 80
- **Path**: /
- **Interval**: 30 seconds
- **Failure Threshold**: 3 consecutive failures
- **Evaluation**: ~90 seconds to mark unhealthy

### CloudWatch Alarm

Automatically creates alarm `{project_name}-route53-health-check-status`:

- **Metric**: HealthCheckStatus (1=healthy, 0=unhealthy)
- **Threshold**: < 1 (unhealthy)
- **Evaluation**: 1 period (60 seconds)
- **Action**: SNS notification if configured

### When Health Check Fails

1. Route53 stops returning the DNS record
2. Clients receive NXDOMAIN or try next available server
3. CloudWatch alarm triggers
4. SNS notification sent to ops team (if alert_email configured)

## Query Logging

When `enable_query_logging = true` (default):

- **Destination**: CloudWatch Log Group `/aws/route53/{domain_name}`
- **Retention**: 7 days (configurable)
- **Contents**: All DNS queries to the zone
- **Metrics**: Query count, query types, source IPs

### Use Cases

1. **Troubleshooting DNS**: Check what queries are being made
2. **Security**: Identify suspicious DNS patterns
3. **Monitoring**: Track DNS query volume trends
4. **Compliance**: Audit DNS activity

### Example Query

```
| filter queryTimestamp >= "2026-04-24T00:00:00Z"
| stats count() by queryName, queryType
| sort count() desc
```

## Deployment Steps

### Step 1: Plan DNS Configuration

Decide which records you need:

```
Domain Type         | Example           | Enable
--------------------|-------------------|----------
Primary             | example.com       | Always (create_hosted_zone=true)
WWW                 | www.example.com   | enable_www_subdomain=true
API                 | api.example.com   | create_api_subdomain=true
Admin               | admin.example.com | create_admin_subdomain=true
Email (MX)          | mail.example.com  | enable_mx_record=true
Verification (TXT)  | SPF/DKIM/DMARC    | enable_txt_verification_record=true
CDN (CNAME)         | cdn.example.com   | enable_cdn_cname=true
```

### Step 2: Update Configuration

```hcl
# env/dev/terraform.tfvars

domain_name        = "example.com"
create_hosted_zone = true
alb_zone_id        = "Z1LMS91P8CMLE5"  # Check table above for your region

# Enable records you need
enable_www_subdomain         = true
create_api_subdomain         = false
create_admin_subdomain       = false
enable_mx_record             = false
enable_txt_verification_record = false
enable_cdn_cname             = false

# Email records (if enabled)
# mx_records = ["10 mail.example.com"]

# Verification records (if enabled)
# txt_verification_records = ["v=spf1 include:amazon.com ~all"]

# CDN (if enabled)
# cloudfront_domain_name = "abc123.cloudfront.net"
```

### Step 3: Deploy Infrastructure

```bash
cd env/dev
terraform plan
terraform apply
```

### Step 4: Update Domain Registrar

After creation, update your domain registrar with Route53 nameservers:

```
Output: hosted_zone_name_servers
Example:
  ns-123.awsdns-45.com
  ns-678.awsdns-90.org
  ns-901.awsdns-23.net
  ns-234.awsdns-56.co.uk
```

**Steps**:

1. Go to domain registrar (GoDaddy, Namecheap, etc.)
2. Update nameservers to Route53 values
3. Wait for DNS propagation (typically 15-30 minutes)
4. Verify with `nslookup example.com` or `dig example.com`

## Outputs

After `terraform apply`, you can retrieve:

```bash
# Get hosted zone ID
terraform output dns_hosted_zone_id

# Get nameservers to set in registrar
terraform output dns_hosted_zone_name_servers

# Get health check ID
terraform output dns_health_check_id

# Get all created records
terraform output dns_records_summary

# Example:
# primary_domain = "example.com -> alb-1234567890.ap-southeast-3.elb.amazonaws.com"
# www_subdomain = "www.example.com -> alb-1234567890.ap-southeast-3.elb.amazonaws.com"
```

## Monitoring

### CloudWatch Metrics

**Route53 Health Check Metrics** (if enabled):

- `HealthCheckStatus`: 1 (healthy) or 0 (unhealthy)
- `ConnectionTime`: Latency to health check endpoint
- `SSLHandshakeTime`: TLS negotiation time
- `TimeToFirstByte`: Response time

### CloudWatch Logs

**Route53 Query Logs**:

```
Path: /aws/route53/example.com
Retention: 7 days (configurable)

Sample log entry:
{
  "queryTimestamp": "2026-04-24T12:34:56Z",
  "queryName": "example.com",
  "queryType": "A",
  "responseCode": "NOERROR",
  "sourceIP": "203.0.113.45"
}
```

### CloudWatch Alarms

**Health Check Alarm**: `{project_name}-route53-health-check-status`

- **Threshold**: Health check fails for 60 seconds
- **Action**: SNS notification to alert_email

## Common Scenarios

### Scenario 1: Single Domain with All Subdomains

```hcl
domain_name                    = "example.com"
create_hosted_zone             = true
enable_www_subdomain           = true
create_api_subdomain           = true
create_admin_subdomain         = true
enable_health_checks           = true
enable_query_logging           = true
```

**Result**:

- example.com → ALB
- www.example.com → ALB
- api.example.com → ALB
- admin.example.com → ALB
- Health checks monitoring
- Query logs in CloudWatch

### Scenario 2: Domain with CloudFront CDN

```hcl
domain_name                    = "example.com"
create_hosted_zone             = true
enable_www_subdomain           = true
enable_cdn_cname               = true
cloudfront_domain_name         = "d123456.cloudfront.net"
cdn_subdomain                  = "cdn"
```

**Result**:

- example.com → ALB (origin)
- www.example.com → ALB
- cdn.example.com → CloudFront distribution

### Scenario 3: Development (No DNS)

```hcl
domain_name        = ""
create_hosted_zone = false
```

**Result**: No Route53 resources created
**Access via**: ALB DNS name directly (alb-xxxxx.ap-southeast-3.elb.amazonaws.com)

### Scenario 4: Existing Hosted Zone

If you already have a Route53 hosted zone:

```hcl
domain_name        = "example.com"
create_hosted_zone = false  # Set to false!
alb_zone_id        = "Z1LMS91P8CMLE5"
```

**Manual Step**: Manually create A records in existing zone pointing to ALB

## Troubleshooting

### DNS Not Resolving

1. **Check nameservers updated**: `nslookup example.com`
   - Should show 4 AWS nameservers
   - Propagation takes 15-30 minutes

2. **Check Route53 records**:

   ```bash
   terraform output dns_records_summary
   aws route53 list-resource-record-sets --hosted-zone-id Z123...
   ```

3. **Check health check status**:
   ```bash
   aws route53 get-health-check-status --health-check-id <id>
   ```

### Health Check Failing

1. **Check ALB is healthy**:
   - Navigate to ALB in AWS console
   - Verify target group has healthy targets
   - Check security groups allow port 80

2. **Check logs**:
   - ALB access logs in S3
   - ECS task logs in CloudWatch

3. **Common causes**:
   - Firewall blocking port 80
   - Application not responding on /"
   - Security group denying health check traffic

## Cost Considerations

**Route53 Pricing** (April 2026):

- **Hosted Zone**: $0.50/month per zone
- **Standard Query**: $0.40 per million queries
- **Health Check**: $0.50/month per health check
- **Query Logging**: $0.50 per million logged queries

**Example**: Single zone + health check + logging

- 1 million queries/month: ~$1.40 (zone + health + queries + logging)
- 10 million queries/month: ~$4.90
- 100 million queries/month: ~$40.50

**Savings Tips**:

- Disable query logging if not needed
- Use simple health checks (reduce interval if possible)
- Consolidate zones if managing multiple domains

## Security Best Practices

1. **DNSSEC**: Consider enabling DNSSEC for domain validation
2. **Access Control**: Use IAM policies to restrict Route53 changes
3. **Query Logging**: Monitor for DNS exfiltration attempts
4. **Health Checks**: Monitor for ALB failures
5. **DDoS Protection**: Consider Route53 Resolver DDoS protection

## Next Steps

After Phase 6:

1. **Configure Domain Registrar**: Point nameservers to Route53
2. **Verify DNS Propagation**: Check with `nslookup` or `dig`
3. **Test Endpoints**: Verify all subdomains resolve and reach ALB
4. **Monitor Health**: Check Route53 health check metrics
5. **Enable HTTPS**: Update ALB listener with real ACM certificate once domain verified

## Phase 6 Resource Count

**New Resources**: 11+

- 1 Route53 Hosted Zone (conditional)
- 4-7 A Records (primary + subdomains)
- 1 Health Check
- 1 CloudWatch Alarm
- 1 CloudWatch Log Group
- 1 Log Metric Filter
- 1 IAM Role + 1 IAM Policy

**Total Infrastructure Resources (Phase 1-6)**: 105+

---

**Phase 6 Status**: ✅ COMPLETE
**Files Created**: 3 (route53.tf, variables.tf, outputs.tf)
**Files Updated**: 3 (env/dev/main.tf, env/dev/variables.tf, env/dev/terraform.tfvars)
