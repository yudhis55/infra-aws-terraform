module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
}

module "networking" {
  source = "../../modules/networking"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  vpc_id                  = module.vpc.vpc_id
  internet_gateway_id     = module.vpc.internet_gateway_id
  public_subnet_ids       = module.vpc.public_subnets
  private_app_subnet_ids  = module.vpc.private_app_subnets
  private_data_subnet_ids = module.vpc.private_data_subnets
  s3_endpoint_allowed_bucket_arns = [
    module.storage.bucket_arn
  ]
}

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
}

locals {
  effective_app_base_url = var.app_base_url != "" ? var.app_base_url : (
    var.domain_name != "" ? "https://${var.domain_name}" : ""
  )
  effective_s3_cors_allowed_origins = length(var.s3_cors_allowed_origins) > 0 ? var.s3_cors_allowed_origins : compact([local.effective_app_base_url])
  media_domain_enabled              = var.enable_cdn_cname && var.domain_name != "" && var.route53_zone_id != ""
  media_domain_name                 = local.media_domain_enabled ? "${var.cdn_subdomain}.${var.domain_name}" : ""
  media_certificate_arn             = try(module.cloudfront_certificate[0].certificate_arn, "")
  cdn_dns_target                    = local.media_domain_enabled ? module.cdn.distribution_domain_name : var.cloudfront_domain_name
}

module "storage" {
  source = "../../modules/storage"

  project_name         = var.project_name
  environment          = var.environment
  cors_allowed_origins = local.effective_s3_cors_allowed_origins
}

module "cloudfront_certificate" {
  count  = local.media_domain_enabled ? 1 : 0
  source = "../../modules/certificate"

  providers = {
    aws = aws.us_east_1
  }

  project_name              = var.project_name
  environment               = var.environment
  certificate_purpose       = "media"
  domain_name               = local.media_domain_name
  hosted_zone_id            = var.route53_zone_id
  subject_alternative_names = []
}

module "cdn" {
  source = "../../modules/cdn"

  project_name                = var.project_name
  environment                 = var.environment
  bucket_id                   = module.storage.bucket_id
  bucket_arn                  = module.storage.bucket_arn
  bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  price_class                 = var.cloudfront_price_class
  aliases                     = local.media_domain_enabled ? [local.media_domain_name] : []
  viewer_certificate_acm_arn  = local.media_certificate_arn
  public_domain_name          = local.media_domain_name
}

module "certificate" {
  count  = var.enable_https && var.acm_certificate_arn == "" ? 1 : 0
  source = "../../modules/certificate"

  project_name              = var.project_name
  environment               = var.environment
  certificate_purpose       = "alb"
  domain_name               = var.domain_name
  hosted_zone_id            = var.route53_zone_id
  subject_alternative_names = var.enable_www_subdomain ? ["www.${var.domain_name}"] : []
}

locals {
  alb_certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (
    var.enable_https && length(module.certificate) > 0 ? module.certificate[0].certificate_arn : ""
  )
}

module "rds" {
  source = "../../modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
  db_engine_version          = var.db_engine_version
  db_instance_class          = var.db_instance_class
  db_allocated_storage       = var.db_allocated_storage
  db_storage_type            = var.db_storage_type
  db_iops                    = var.db_iops
  db_storage_throughput      = var.db_storage_throughput
  backup_retention_period    = var.backup_retention_period
  backup_window              = var.backup_window
  maintenance_window         = var.maintenance_window
  multi_az                   = true
  skip_final_snapshot        = var.skip_final_snapshot
  enable_encryption          = true
  enable_deletion_protection = var.enable_deletion_protection

  private_data_subnet_ids = module.vpc.private_data_subnets
  rds_security_group_id   = module.networking.rds_security_group_id
  rds_proxy_source_sg_id  = module.networking.ecs_security_group_id
  vpc_id                  = module.vpc.vpc_id

  enable_rds_proxy           = true
  proxy_max_connections      = var.proxy_max_connections
  proxy_max_idle_connections = var.proxy_max_idle_connections

  depends_on = [module.networking]
}

module "ecs" {
  source = "../../modules/ecs"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # Network configuration
  public_subnets        = module.vpc.public_subnets
  private_subnets       = module.vpc.private_app_subnets # For backward compatibility
  private_app_subnets   = module.vpc.private_app_subnets
  alb_security_group_id = module.networking.alb_security_group_id
  ecs_security_group_id = module.networking.ecs_security_group_id

  create_alb_security_group = false
  create_ecs_security_group = false

  # Container image
  ecr_image = var.app_image_uri

  # EC2 Auto Scaling configuration
  ecs_instance_type    = var.ecs_instance_type
  ecs_min_size         = var.ecs_min_size
  ecs_max_size         = var.ecs_max_size
  ecs_desired_capacity = var.ecs_desired_capacity

  # ECS Task configuration
  ecs_task_cpu    = var.ecs_task_cpu
  ecs_task_memory = var.ecs_task_memory

  # RDS configuration for environment variables
  rds_endpoint    = coalesce(module.rds.rds_proxy_endpoint, module.rds.rds_instance_address)
  rds_port        = "5432"
  rds_database    = var.db_name
  rds_secrets_arn = var.secrets_manager_secret_arn != "" ? var.secrets_manager_secret_arn : module.rds.rds_secrets_manager_secret_arn

  # Application runtime configuration
  app_base_url           = var.app_base_url
  auth_secret            = var.auth_secret
  app_secrets_kms_key_id = module.rds.rds_kms_key_arn
  s3_bucket_name         = module.storage.bucket_id
  s3_bucket_arn          = module.storage.bucket_arn
  s3_region              = var.aws_region
  s3_public_base_url     = module.cdn.public_base_url
  smtp_host              = var.smtp_host
  smtp_port              = var.smtp_port
  smtp_user              = var.smtp_user
  smtp_pass              = var.smtp_pass
  smtp_from              = var.smtp_from
  health_check_path      = var.health_check_path

  # HTTPS configuration
  enable_https        = var.enable_https
  acm_certificate_arn = local.alb_certificate_arn

  depends_on = [module.networking, module.rds, module.cdn]
}

# ==================== Phase 4: Security & WAF ====================
module "security" {
  source = "../../modules/security"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  alb_arn        = module.ecs.alb_arn
  enable_waf     = var.enable_waf
  waf_rate_limit = var.waf_rate_limit

  depends_on = [module.ecs]
}

# ==================== Phase 5: Monitoring & CloudWatch ====================
module "monitoring" {
  source = "../../modules/monitoring"

  project_name               = var.project_name
  environment                = var.environment
  aws_region                 = var.aws_region
  alert_email                = var.alert_email
  ecs_min_size               = var.ecs_min_size
  ecs_cluster_name           = module.ecs.ecs_cluster_name
  ecs_service_name           = module.ecs.ecs_service_name
  asg_name                   = module.ecs.asg_name
  alb_arn_suffix             = module.ecs.alb_arn_suffix
  target_group_arn_suffix    = module.ecs.target_group_arn_suffix
  rds_instance_id            = module.rds.rds_instance_id
  ecs_log_group_name         = module.ecs.cloudwatch_log_group_name
  waf_web_acl_name           = coalesce(module.security.waf_web_acl_name, "")
  waf_log_group_name         = coalesce(module.security.waf_log_group_name, "")
  vpc_flow_log_group_name    = module.security.vpc_flow_logs_log_group
  enable_detailed_monitoring = var.enable_detailed_monitoring
  log_retention_days         = var.log_retention_days

  depends_on = [
    module.ecs,
    module.rds,
    module.security
  ]
}

# ==================== Phase 6: DNS & Route53 ====================
module "dns" {
  source = "../../modules/dns"

  project_name                   = var.project_name
  environment                    = var.environment
  domain_name                    = var.domain_name
  create_hosted_zone             = var.create_hosted_zone
  hosted_zone_id                 = var.route53_zone_id
  alb_dns_name                   = module.ecs.alb_dns_name
  alb_zone_id                    = module.ecs.alb_zone_id
  enable_health_checks           = var.enable_health_checks
  enable_www_subdomain           = var.enable_www_subdomain
  create_api_subdomain           = var.create_api_subdomain
  create_admin_subdomain         = var.create_admin_subdomain
  enable_mx_record               = var.enable_mx_record
  mx_records                     = var.mx_records
  enable_txt_verification_record = var.enable_txt_verification_record
  txt_verification_records       = var.txt_verification_records
  enable_cdn_cname               = local.media_domain_enabled
  cdn_subdomain                  = var.cdn_subdomain
  cloudfront_domain_name         = local.cdn_dns_target
  enable_query_logging           = var.enable_query_logging
  log_retention_days             = var.log_retention_days
  sns_topic_arn                  = module.monitoring.sns_topic_arn

  depends_on = [module.ecs, module.monitoring, module.cdn]
}
