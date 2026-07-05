#!/bin/bash
set -e

# ECS Cluster initialization script
# This script configures EC2 instances to join the ECS cluster

# Update CloudWatch agent configuration with ECS cluster name
cat >> /etc/ecs/ecs.config << EOF
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_CONTAINER_METADATA=true
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs","splunk"]
ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
ECS_ENABLE_INSTANCE_IAM_ROLE=true
EOF

# Restart ECS agent to pick up new configuration
systemctl restart ecs

# Log that initialization is complete
echo "ECS initialization complete for cluster: ${cluster_name}" >> /var/log/ecs/ecs-init.log
