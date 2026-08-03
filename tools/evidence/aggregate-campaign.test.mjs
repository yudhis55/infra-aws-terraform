import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { aggregateCampaign } from "./aggregate-campaign.mjs";

const inputDigest = `sha256:${"d".repeat(64)}`;

function write(root, relativePath, value) {
  const file = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value));
}

function completeFixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-campaign-"));
  write(root, "metadata/campaign.json", {
    campaignId: "campaign-test",
    region: "ap-southeast-3",
    targetUrl: "https://eepistore.web.id",
    startedAt: "2026-08-04T00:00:00Z",
    endedAt: "2026-08-04T04:00:00Z",
  });
  write(root, "metadata/lineage.json", {
    appCommit: "a".repeat(40),
    infraCommit: "b".repeat(40),
    imageDigest: `sha256:${"c".repeat(64)}`,
    inputDigest,
  });
  write(root, "metadata/child-fault-lineages.json", []);
  for (const [name, cycleId] of [["cycle-r", "cycle-r"], ["cycle-f", "cycle-f"]]) {
    write(root, `delivery/${name}.json`, {
      cycleId,
      runStatus: "passed",
      inputDigest,
      githubRunIds: { apply: name },
      timings: { applySeconds: 100 },
    });
  }
  write(root, "security/fault-injection-matrix.json", {
    cases: [
      "FI-IAC-01",
      "FI-IAC-02",
      "FI-IAC-03",
      "FI-SCA-01",
      "FI-IMG-01",
      "FI-AUTH-01",
    ].map((faultId) => ({
      faultId,
      severity: faultId.startsWith("FI-IAC-") ? "critical" : "high",
      runStatus: "passed",
      detected: true,
      deliveryBlocked: true,
    })),
  });
  write(root, "security/zap-summary.json", { findings: [] });
  write(root, "security/waf-rate-protection.json", {
    totalRequests: 110,
    blockedRequests: 1,
    metricCorrelated: true,
    sampleCorrelated: true,
    cleanupStatus: "passed",
    scopeViolation: false,
  });
  write(root, "security/network-isolation.json", {
    attempts: [
      { control: "vpc-network", expected: "denied", actual: "denied", flowLogAction: "REJECT" },
      { control: "storage-policy", expected: "http-403", actual: "http-403" },
    ],
  });
  write(root, "functional/playwright-results.json", {
    stats: { expected: 12, unexpected: 0, flaky: 0, skipped: 0, duration: 1000 },
  });
  for (const trial of [1, 2, 3]) {
    write(root, `runtime/scale-trial-${trial}.json`, {
      runType: "final-trial",
      runStatus: "passed",
      ecsServiceScaleOut: "passed",
      p95Ms: 200 + trial,
      throughputRps: 10 + trial,
      failureRate: 0,
      ecsScaleOutLatencySeconds: 60,
      taskReadyLatencySeconds: 90,
      scaleInLatencySeconds: 600,
    });
  }
  write(root, "runtime/scaling-events.json", { asgStatus: "not-exercised", asgActivities: [] });
  write(root, "monitoring/cloudwatch-metrics.json", {
    requiredSeries: ["alb", "ecs", "rds"],
    populatedSeries: ["alb", "ecs", "rds"],
  });
  write(root, "monitoring/application-errors.json", { events: [] });
  write(root, "cleanup/database-cleanup.json", {
    remainingUsers: 0,
    remainingStores: 0,
    remainingOrders: 0,
    remainingProducts: 0,
    remainingPayments: 0,
    remainingRateLimitBuckets: 0,
  });
  write(root, "cleanup/s3-cleanup.json", { remainingPublicObjects: 0, remainingPrivateObjects: 0 });
  write(root, "cleanup/agent-cleanup.json", { remainingAgents: 0 });
  write(root, "cleanup/terraform-experiment-cleanup.json", { remainingTemporaryResources: 0 });
  write(root, "conformance/report.json", {
    status: "passed",
    semanticDifferences: [],
    controlledDrift: {
      status: "passed",
      recoveryPlanUpdates: 1,
      remainingControlledDriftTags: 0,
      noChangeAfterRecovery: true,
    },
  });
  return root;
}

test("aggregates a complete campaign with the exact six-case fault matrix", () => {
  const result = aggregateCampaign(completeFixture());
  assert.equal(result.status, "final");
  assert.equal(result.faultInjection.metrics.summary.validCases, 6);
  assert.equal(result.faultInjection.metrics.summary.completeMatrix, true);
  assert.equal(result.faultInjection.metrics.summary.detectionCoverage, 1);
  assert.equal(result.faultInjection.metrics.summary.gateBlockRate, 1);
  assert.equal(result.scalability.metrics.aggregate.p95Ms.median, 202);
  assert.equal(result.scalability.metrics.asg.status, "not-exercised");
});

test("does not finalize a campaign containing an invalid fault fixture", () => {
  const root = completeFixture();
  const file = path.join(root, "security/fault-injection-matrix.json");
  const matrix = JSON.parse(fs.readFileSync(file, "utf8"));
  matrix.cases[0].runStatus = "invalid-fixture";
  write(root, "security/fault-injection-matrix.json", matrix);

  const result = aggregateCampaign(root);
  assert.equal(result.status, "incomplete");
  assert.equal(result.faultInjection.status, "partial");
  assert.equal(result.faultInjection.metrics.summary.invalidFixtures, 1);
});

test("fails conformance when cycle inputs diverge", () => {
  const root = completeFixture();
  const cycle = JSON.parse(fs.readFileSync(path.join(root, "delivery/cycle-f.json"), "utf8"));
  cycle.inputDigest = `sha256:${"e".repeat(64)}`;
  write(root, "delivery/cycle-f.json", cycle);
  const result = aggregateCampaign(root);
  assert.equal(result.status, "failed");
  assert.equal(result.delivery.metrics.matchingInputs, false);
  assert.equal(result.conformance.status, "failed");
});

test("does not accept fewer than three observed ECS scale-out trials", () => {
  const root = completeFixture();
  fs.rmSync(path.join(root, "runtime/scale-trial-3.json"));
  const result = aggregateCampaign(root);
  assert.equal(result.scalability.status, "failed");
  assert.equal(result.scalability.metrics.ecsService.observedTrials, 2);
});
