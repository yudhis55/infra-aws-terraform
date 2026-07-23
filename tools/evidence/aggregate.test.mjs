import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { aggregate } from "./aggregate.mjs";

const environment = {
  EXPERIMENT_ID: "experiment-test-1",
  AWS_REGION: "ap-southeast-3",
  APP_URL: "https://eepistore.web.id",
  EXPERIMENT_STARTED_AT: "2026-07-23T00:00:00Z",
  EXPERIMENT_ENDED_AT: "2026-07-23T01:00:00Z",
  APP_COMMIT_SHA: "a".repeat(40),
  INFRA_COMMIT_SHA: "b".repeat(40),
  APP_IMAGE_DIGEST: `sha256:${"c".repeat(64)}`,
  EVIDENCE_STATUS: "sample",
};

test("marks absent raw evidence as sample with missing sections", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-evidence-"));
  const result = aggregate(directory, environment);
  assert.equal(result.status, "sample");
  assert.equal(result.functional.status, "missing");
  assert.equal(result.baseline, null);
});

test("normalizes k6 trial metrics and computes medians", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-evidence-"));
  fs.mkdirSync(path.join(directory, "k6"));
  for (const [trial, p95] of [[1, 300], [2, 200], [3, 250]]) {
    fs.writeFileSync(
      path.join(directory, "k6", `trial-${trial}.json`),
      JSON.stringify({
        metrics: {
          http_reqs: { values: { count: 100, rate: trial * 10 } },
          http_req_failed: { values: { rate: 0 }, thresholds: { "rate<0.01": { ok: true } } },
          checks: { values: { rate: 1 }, thresholds: { "rate>0.99": { ok: true } } },
          http_req_duration: {
            values: { "p(50)": 100, "p(95)": p95, "p(99)": p95 + 50 },
            thresholds: { "p(95)<1000": { ok: true } },
          },
        },
      }),
    );
  }
  const result = aggregate(directory, environment);
  assert.equal(result.runtime.status, "passed");
  assert.equal(result.runtime.metrics.aggregate.medianP95Ms, 250);
  assert.equal(result.runtime.metrics.aggregate.trialCount, 3);
});

test("does not mark a single successful k6 trial as final runtime evidence", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-evidence-"));
  fs.mkdirSync(path.join(directory, "k6"));
  fs.writeFileSync(
    path.join(directory, "k6", "trial-1.json"),
    JSON.stringify({
      metrics: {
        http_req_failed: { values: { rate: 0 }, thresholds: { gate: { ok: true } } },
        checks: { values: { rate: 1 }, thresholds: { gate: { ok: true } } },
        http_req_duration: {
          values: { "p(95)": 100 },
          thresholds: { gate: { ok: true } },
        },
      },
    }),
  );
  assert.equal(aggregate(directory, environment).runtime.status, "partial");
});

test("requires matching setup and cleanup evidence for final conformance", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-evidence-"));
  fs.mkdirSync(path.join(directory, "fixture"), { recursive: true });
  fs.mkdirSync(path.join(directory, "cleanup"), { recursive: true });
  fs.writeFileSync(path.join(directory, "verification-status.txt"), "PASS state\n");
  fs.writeFileSync(
    path.join(directory, "fixture", "fixture.json"),
    JSON.stringify({ experimentId: environment.EXPERIMENT_ID }),
  );
  fs.writeFileSync(
    path.join(directory, "cleanup", "cleanup.json"),
    JSON.stringify({
      experimentId: environment.EXPERIMENT_ID,
      removedUsers: 4,
      removedStores: 1,
    }),
  );
  fs.writeFileSync(
    path.join(directory, "cleanup", "s3-cleanup.json"),
    JSON.stringify({ experimentId: environment.EXPERIMENT_ID, status: "passed" }),
  );

  const result = aggregate(directory, { ...environment, EVIDENCE_STATUS: "" });
  assert.equal(result.conformance.status, "passed");
  assert.equal(result.conformance.metrics.fixtureCleanup.removedUsers, 4);

  fs.rmSync(path.join(directory, "cleanup", "cleanup.json"));
  assert.equal(
    aggregate(directory, { ...environment, EVIDENCE_STATUS: "" }).conformance.status,
    "missing",
  );
});

test("marks a complete, schema-valid package as final", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-evidence-"));
  for (const child of ["aws", "cleanup", "fixture", "k6", "timing"]) {
    fs.mkdirSync(path.join(directory, child), { recursive: true });
  }
  fs.writeFileSync(path.join(directory, "verification-status.txt"), "PASS state\n");
  fs.writeFileSync(
    path.join(directory, "playwright-results.json"),
    JSON.stringify({ stats: { expected: 2, unexpected: 0, flaky: 0, skipped: 0, duration: 1000 } }),
  );
  fs.writeFileSync(
    path.join(directory, "zap-summary.json"),
    JSON.stringify({ status: "passed", total: 0, bySeverity: {}, uniqueRules: 0 }),
  );
  fs.writeFileSync(
    path.join(directory, "scanner-summary.json"),
    JSON.stringify({ status: "passed" }),
  );
  fs.writeFileSync(
    path.join(directory, "fixture", "fixture.json"),
    JSON.stringify({ experimentId: environment.EXPERIMENT_ID }),
  );
  fs.writeFileSync(
    path.join(directory, "cleanup", "cleanup.json"),
    JSON.stringify({ experimentId: environment.EXPERIMENT_ID, removedUsers: 4, removedStores: 1 }),
  );
  fs.writeFileSync(
    path.join(directory, "cleanup", "s3-cleanup.json"),
    JSON.stringify({ experimentId: environment.EXPERIMENT_ID, status: "passed" }),
  );
  for (const stage of ["plan", "apply", "migration", "verification"]) {
    fs.writeFileSync(
      path.join(directory, "timing", `${stage}-timing.json`),
      JSON.stringify({ status: "passed", durationSeconds: 1 }),
    );
  }
  for (const trial of [1, 2, 3]) {
    fs.writeFileSync(
      path.join(directory, "k6", `trial-${trial}.json`),
      JSON.stringify({
        metrics: {
          http_reqs: { values: { count: 100, rate: 10 } },
          http_req_failed: { values: { rate: 0 }, thresholds: { gate: { ok: true } } },
          checks: { values: { rate: 1 }, thresholds: { gate: { ok: true } } },
          http_req_duration: {
            values: { "p(95)": 100 },
            thresholds: { gate: { ok: true } },
          },
        },
      }),
    );
  }
  const requiredMetricIds = [
    "albrequests",
    "albp95",
    "ecscpu",
    "ecsmemory",
    "asginservice",
    "rdscpu",
    "rdsconnections",
  ];
  fs.writeFileSync(
    path.join(directory, "aws", "cloudwatch-metrics.json"),
    JSON.stringify({
      MetricDataResults: requiredMetricIds.map((Id) => ({
        Id,
        StatusCode: "Complete",
        Timestamps: [environment.EXPERIMENT_ENDED_AT],
        Values: [1],
      })),
    }),
  );
  fs.writeFileSync(
    path.join(directory, "aws", "collection-window.json"),
    JSON.stringify({ status: "collected" }),
  );
  fs.writeFileSync(
    path.join(directory, "aws", "application-errors.json"),
    JSON.stringify({ events: [] }),
  );

  const result = aggregate(directory, { ...environment, EVIDENCE_STATUS: "" });
  assert.equal(result.status, "final");
  assert.equal(result.security.status, "passed");
  assert.equal(result.monitoring.status, "passed");
  assert.match(result.manifestSha256, /^[0-9a-f]{64}$/);
});
