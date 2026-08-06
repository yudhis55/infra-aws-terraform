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

test("uses WAF visibility metric names for CloudWatch dimensions", () => {
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
  assert.match(workflow, /output -raw waf_metric_name/);
  assert.match(workflow, /Name=Rule,Value=ExperimentRateLimitMetric/);
  assert.match(collector, /Value:"ExperimentRateLimitMetric"/);
  assert.match(monitoring, /var\.waf_metric_name/);
});
