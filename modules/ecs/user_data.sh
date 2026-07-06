#!/bin/bash
set -euo pipefail

# ECS Cluster initialization script
# This script configures EC2 instances to join the ECS cluster

# Update ECS agent configuration with ECS cluster name. Use a full write instead
# of append so replacement instances do not accumulate duplicate settings.
cat > /etc/ecs/ecs.config << EOF
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_CONTAINER_METADATA=true
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs","splunk"]
ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
ECS_ENABLE_INSTANCE_IAM_ROLE=true
EOF

# ecs.service declares After=cloud-final.service, while user data runs inside
# cloud-final. Queue the start without blocking so cloud-final can finish first.
systemctl daemon-reload
systemctl enable ecs
systemctl start --no-block ecs

# Log that initialization is complete
echo "ECS initialization complete for cluster: ${cluster_name}" >> /var/log/ecs/ecs-init.log
