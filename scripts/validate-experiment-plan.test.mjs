import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

function run(mode, resourceChanges) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-plan-"));
  const file = path.join(directory, "plan.json");
  fs.writeFileSync(file, JSON.stringify({ resource_changes: resourceChanges }));
  return spawnSync(process.execPath, ["scripts/validate-experiment-plan.mjs", file, mode], {
    cwd: path.resolve("../.."),
    encoding: "utf8",
  });
}

test("accepts only experiment module changes for agent mode", () => {
  const result = run("agent", [
    { address: "module.experiment.aws_instance.agent[0]", change: { actions: ["create"] } },
  ]);
  assert.equal(result.status, 0, result.stderr);
});

test("rejects unrelated or replacement changes", () => {
  const result = run("rate-test", [
    { address: "module.rds.aws_db_instance.main", change: { actions: ["update"] } },
    { address: "module.security.aws_wafv2_web_acl.main[0]", change: { actions: ["delete", "create"] } },
  ]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /module\.rds/);
});

test("accepts only removal of the controlled drift tag", () => {
  const result = run("drift-recovery", [
    {
      address: "module.networking.aws_security_group.alb",
      change: {
        actions: ["update"],
        before: {
          description: "ALB security group",
          tags: { Environment: "dev", ExperimentDrift: "controlled" },
          tags_all: { Environment: "dev", ExperimentDrift: "controlled" },
        },
        after: {
          description: "ALB security group",
          tags: { Environment: "dev" },
          tags_all: { Environment: "dev" },
        },
      },
    },
  ]);
  assert.equal(result.status, 0, result.stderr);
});

test("rejects a drift recovery that changes a functional attribute", () => {
  const result = run("drift-recovery", [
    {
      address: "module.networking.aws_security_group.alb",
      change: {
        actions: ["update"],
        before: { description: "before", tags: { ExperimentDrift: "controlled" } },
        after: { description: "after", tags: {} },
      },
    },
  ]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unexpected attributes/);
});

test("keeps RDS and experiment dependencies resource-scoped", () => {
  const root = fs.readFileSync(path.resolve("../..", "env/dev/main.tf"), "utf8");
  for (const moduleName of ["rds", "experiment"]) {
    const block = root.match(new RegExp(`module "${moduleName}" \\{([\\s\\S]*?)\\n\\}`));
    assert.ok(block, `missing module ${moduleName}`);
    assert.doesNotMatch(
      block[1],
      /\bdepends_on\s*=/,
      `module ${moduleName} must rely on its resource input references`,
    );
  }
});

test("uses a high-severity unrestricted-ingress IaC positive control", () => {
  const fixture = fs.readFileSync(
    path.resolve("../..", "tests/fault-fixtures/iac/FI-IAC-02/main.tf"),
    "utf8",
  );
  assert.match(fixture, /protocol\s*=\s*"-1"/);
  assert.match(fixture, /cidr_blocks\s*=\s*\["0\.0\.0\.0\/0"\]/);
});

test("keeps a dormant IP set and orders the WAF lifecycle dependency", () => {
  const waf = fs.readFileSync(path.resolve("../..", "modules/security/waf.tf"), "utf8");
  const block = waf.match(/resource "aws_wafv2_web_acl" "main" \{([\s\S]*?)\n\}/);
  assert.ok(block, "missing WAF Web ACL resource");
  assert.match(block[1], /depends_on\s*=\s*\[aws_wafv2_ip_set\.experiment_source\]/);
  assert.match(waf, /count\s*=\s*var\.enable_waf\s*\?\s*1\s*:\s*0/);
  assert.match(waf, /127\.0\.0\.1\/32/);
});

test("requires a durable Docker readiness marker on the experiment agent", () => {
  const agent = fs.readFileSync(path.resolve("../..", "modules/experiment/main.tf"), "utf8");
  const readiness = fs.readFileSync(
    path.resolve("../..", "scripts/wait-for-experiment-agent.sh"),
    "utf8",
  );
  assert.match(agent, /for attempt in 1 2 3 4 5/);
  assert.match(agent, /\/var\/lib\/eepistore-experiment\/ready/);
  assert.match(readiness, /test -f \/var\/lib\/eepistore-experiment\/ready/);
  assert.match(readiness, /eepistore-experiment-bootstrap\.log/);
});

test("allows the private AL2023 agent to read the regional package repository", () => {
  const endpoints = fs.readFileSync(
    path.resolve("../..", "modules/networking/vpc-endpoints.tf"),
    "utf8",
  );
  assert.match(
    endpoints,
    /arn:aws:s3:::al2023-repos-\$\{var\.aws_region\}-de612dc2/,
  );
  assert.match(endpoints, /Sid\s*=\s*"AllowAmazonLinux2023Packages"/);
  assert.match(endpoints, /Action\s*=\s*\["s3:GetObject"\]/);
});

test("preserves the bounded WAF generator summary as a JSON object", () => {
  const generator = fs.readFileSync(
    path.resolve("../..", "scripts/run-waf-rate-test.sh"),
    "utf8",
  );
  const workflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/research-campaign.yml"),
    "utf8",
  );
  assert.match(generator, /<<< "\$summary" > \/dev\/null/);
  assert.match(generator, /jq '\.' <<< "\$summary" > "\$out_dir\/generator-summary\.json"/);
  assert.match(workflow, /metric_window_end="\$\(date -u \+%Y-%m-%dT%H:%M:%SZ\)"/);
  assert.match(workflow, /--end-time "\$metric_window_end"/);
});

test("isolates manual Terraform operations from branch CI concurrency", () => {
  const workflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/terraform-ci.yml"),
    "utf8",
  );
  assert.match(workflow, /group: terraform-\$\{\{ github\.event_name \}\}-\$\{\{ github\.ref \}\}/);
  assert.match(workflow, /cancel-in-progress: \$\{\{ github\.event_name != 'workflow_dispatch' \}\}/);
});

test("uses a long apply session and tightly gates stale-lock recovery", () => {
  const terraformWorkflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/terraform-ci.yml"),
    "utf8",
  );
  const recoveryWorkflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/recover-stale-backend-lock.yml"),
    "utf8",
  );
  const bootstrapPolicy = JSON.parse(
    fs.readFileSync(
      path.resolve("../..", "bootstrap/github-oidc/apply-session-bootstrap-policy.json"),
      "utf8",
    ),
  );
  assert.match(
    terraformWorkflow,
    /role-to-assume: \$\{\{ secrets\.AWS_APPLY_ROLE_ARN \}\}[\s\S]*role-duration-seconds: 21600/,
  );
  assert.match(recoveryWorkflow, /inputs\.confirmation == 'RECOVER-STALE-LOCK'/);
  assert.match(recoveryWorkflow, /select\(\.status != "completed"\).*length == 0/);
  assert.match(recoveryWorkflow, /test "\$\(\(now_epoch - lock_epoch\)\)" -ge 300/);
  assert.match(recoveryWorkflow, /NoSuchKey\|Not Found\|404/);
  assert.match(recoveryWorkflow, /if: steps\.stale\.outputs\.lock_present == 'true'/);
  assert.match(recoveryWorkflow, /delete-object --bucket "\$BACKEND_BUCKET" --key "\$LOCK_KEY"/);
  assert.match(
    recoveryWorkflow,
    /name: Remove temporary apply-session bootstrap\r?\n\s*if: always\(\)/,
  );
  assert.equal(bootstrapPolicy.Statement.length, 1);
  assert.equal(bootstrapPolicy.Statement[0].Action, "iam:UpdateRole");
  assert.equal(
    bootstrapPolicy.Statement[0].Resource,
    "arn:aws:iam::557947229844:role/eepistore-infra-apply-role",
  );
});

test("assigns autoscaling ownership and credentials for the full runtime suite", () => {
  const ecs = fs.readFileSync(path.resolve("../..", "modules/ecs/main.tf"), "utf8");
  const runtimeWorkflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/research-campaign.yml"),
    "utf8",
  );
  const syncWorkflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/sync-experiment-oidc-policy.yml"),
    "utf8",
  );
  assert.match(ecs, /ignore_changes\s*=\s*\[desired_count\]/);
  assert.match(runtimeWorkflow, /role-duration-seconds:\s*21600/);
  assert.match(syncWorkflow, /MAX_SESSION_DURATION:\s*"21600"/);
  assert.match(syncWorkflow, /--max-session-duration\s+"\$MAX_SESSION_DURATION"/);

  const sessionBootstrapPolicy = JSON.parse(
    fs.readFileSync(
      path.resolve("../..", "bootstrap/github-oidc/experiment-session-bootstrap-policy.json"),
      "utf8",
    ),
  );
  const [durationStatement] = sessionBootstrapPolicy.Statement;
  assert.equal(durationStatement.Action, "iam:UpdateRole");
  assert.equal(
    durationStatement.Resource,
    "arn:aws:iam::557947229844:role/eepistore-infra-experiment-role",
  );
  assert.match(syncWorkflow, /name: Install temporary session bootstrap/);
  assert.match(syncWorkflow, /name: Refresh credentials with session bootstrap/);
  assert.match(syncWorkflow, /unset-current-credentials:\s*true/);
  assert.match(syncWorkflow, /name: Restore temporary session bootstrap\r?\n\s*if: always\(\)/);
  assert.match(syncWorkflow, /sessionBootstrapRetained:false/);
});

test("collects scaling evidence for the full load and scale-in threshold window", () => {
  const runtimeWorkflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/research-campaign.yml"),
    "utf8",
  );
  const collector = fs.readFileSync(
    path.resolve("../..", "scripts/collect-scaling-timeline.sh"),
    "utf8",
  );
  assert.match(runtimeWorkflow, /load_duration_seconds=.*stages\[\]\.durationSeconds/);
  assert.match(runtimeWorkflow, /scale_in_window_seconds=.*scaleInSecondsMax/);
  assert.match(
    runtimeWorkflow,
    /collection_duration_seconds="\$\(\(load_duration_seconds \+ scale_in_window_seconds \+ 120\)\)"/,
  );
  assert.match(
    runtimeWorkflow,
    /collect-scaling-timeline\.sh "\$TF_WORKING_DIR" "\$collection_duration_seconds"/,
  );
  assert.match(runtimeWorkflow, /wait-for-scaling-baseline\.sh/);
  assert.match(runtimeWorkflow, /campaign-evidence\/runtime\/baseline-\$trial\.json/);
  assert.doesNotMatch(runtimeWorkflow, /jq -e '\.runStatus == "passed"'/);
  assert.doesNotMatch(runtimeWorkflow, /test "\$run_code" -eq 0/);
  assert.match(runtimeWorkflow, /trial-outcomes\.json/);
  assert.match(collector, /duration_seconds="\$\{2:-2880\}"/);
  assert.match(collector, /-gt 3600/);
});

test("archives complete campaign evidence even when a research threshold is missed", () => {
  const workflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/aggregate-campaign.yml"),
    "utf8",
  );
  assert.match(workflow, /ALLOW_INCOMPLETE_EVIDENCE: "true"/);
  assert.match(workflow, /\.status == "final" or \.status == "failed"/);
  assert.match(workflow, /\[\$required\[\] as \$key \| \.\[\$key\]/);
  assert.doesNotMatch(workflow, /all\(\$required\[\] as \$key;/);
  assert.match(workflow, /test -d "\$plan_dir\/env\/dev"/);
  assert.match(workflow, /cp "\$plan_dir"\/env\/dev\/\* "\$plan_dir\/"/);
  assert.match(workflow, /source\/waf\/security\/waf-rate-protection\.json/);
  assert.doesNotMatch(workflow, /source\/waf\/campaign-evidence\/security/);
});

test("pins the ECS-optimized AL2023 AMI for repeatable campaign inputs", () => {
  const asg = fs.readFileSync(path.resolve("../..", "modules/ecs/asg.tf"), "utf8");
  const variables = fs.readFileSync(path.resolve("../..", "env/dev/variables.tf"), "utf8");
  const root = fs.readFileSync(path.resolve("../..", "env/dev/main.tf"), "utf8");
  assert.doesNotMatch(asg, /aws_ssm_parameter/);
  assert.match(asg, /image_id\s*=\s*var\.ecs_ami_id/);
  assert.match(variables, /variable "ecs_ami_id"[\s\S]*default\s*=\s*"ami-[0-9a-f]{17}"/);
  assert.match(root, /ecs_ami_id\s*=\s*var\.ecs_ami_id/);
});

test("uses the WAF resource name for WebACL and visibility names for Rule dimensions", () => {
  const workflow = fs.readFileSync(
    path.resolve("../..", ".github/workflows/research-campaign.yml"),
    "utf8",
  );
  const collector = fs.readFileSync(
    path.resolve("../..", "scripts/collect-experiment-aws.sh"),
    "utf8",
  );
  const monitoring = fs.readFileSync(
    path.resolve("../..", "modules/monitoring/dashboards.tf"),
    "utf8",
  );
  assert.match(workflow, /output -raw waf_web_acl_name/);
  assert.match(workflow, /Name=Rule,Value=ExperimentRateLimitMetric/);
  assert.match(workflow, /for metric_attempt in \$\(seq 1 10\)/);
  assert.match(workflow, /metric-propagation\.json/);
  assert.match(collector, /output -raw waf_web_acl_name/);
  assert.match(collector, /Value:"ExperimentRateLimitMetric"/);
  assert.match(monitoring, /var\.waf_web_acl_name/);
});

test("all ECS target-tracking policies share an explicit scale-in cooldown", () => {
  const ecsModule = fs.readFileSync(path.resolve("../..", "modules/ecs/main.tf"), "utf8");
  const matches =
    ecsModule.match(/scale_in_cooldown\s+=\s+var\.service_scale_in_cooldown_seconds/g) ?? [];

  assert.equal(matches.length, 3);
  assert.match(ecsModule, /resource "aws_appautoscaling_policy" "cpu_scaling"/);
  assert.match(ecsModule, /resource "aws_appautoscaling_policy" "memory_scaling"/);
  assert.match(ecsModule, /resource "aws_appautoscaling_policy" "request_scaling"/);
});
