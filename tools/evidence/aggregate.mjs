import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { validateEvidence } from "./validate.mjs";

export function aggregate(rawDir, environment = process.env) {
  const startedAt = required(environment, "EXPERIMENT_STARTED_AT");
  const endedAt = required(environment, "EXPERIMENT_ENDED_AT");
  const playwright = readJson(rawDir, "playwright-results.json");
  const zap = readJson(rawDir, "zap-summary.json");
  const cloudwatch = readJson(rawDir, "aws/cloudwatch-metrics.json");
  const cloudwatchWindow = readJson(rawDir, "aws/collection-window.json");
  const applicationErrors = readJson(rawDir, "aws/application-errors.json");
  const scanners = readJson(rawDir, "scanner-summary.json");
  const verification = readText(rawDir, "verification-status.txt");
  const fixtureSetup = readJson(rawDir, "fixture/fixture.json");
  const fixtureCleanup = readJson(rawDir, "cleanup/cleanup.json");
  const s3Cleanup = readJson(rawDir, "cleanup/s3-cleanup.json");
  const k6Trials = readK6Trials(path.join(rawDir, "k6"));
  const deliveryTimings = {
    plan: readJson(rawDir, "timing/plan-timing.json"),
    apply: readJson(rawDir, "timing/apply-timing.json"),
    migration: readJson(rawDir, "timing/migration-timing.json"),
    verification: readJson(rawDir, "timing/verification-timing.json"),
  };

  const sections = {
    delivery: {
      status: deliveryStatus(verification, deliveryTimings),
      metrics: deliveryTimings,
      notes: [],
    },
    security: {
      status: combinedStatus(zap?.status, scanners?.status),
      metrics: {
        zap: zap ?? null,
        scanners: scanners ?? null,
      },
      notes: [
        "ZAP is bounded to the owned public domain; role authorization is evaluated by Playwright.",
      ],
    },
    functional: {
      status: playwrightStatus(playwright),
      metrics: playwright
        ? {
            expected: playwright.stats?.expected ?? null,
            unexpected: playwright.stats?.unexpected ?? null,
            flaky: playwright.stats?.flaky ?? null,
            skipped: playwright.stats?.skipped ?? null,
            durationMs: playwright.stats?.duration ?? null,
          }
        : {},
      notes: [],
    },
    runtime: {
      status: runtimeStatus(k6Trials),
      metrics: {
        trials: k6Trials,
        aggregate: summarizeTrials(k6Trials),
      },
      notes: ["Runtime performance validates the AWS architecture, not DevSecOps itself."],
    },
    monitoring: {
      status: monitoringStatus(cloudwatch, cloudwatchWindow, applicationErrors),
      metrics: {
        window: cloudwatchWindow ?? null,
        series: normalizeCloudWatch(cloudwatch),
        applicationErrorEvents: applicationErrors?.events?.length ?? null,
      },
      notes: [],
    },
    conformance: {
      status: conformanceStatus(verification, fixtureSetup, fixtureCleanup, s3Cleanup),
      metrics: {
        passed: verification
          ? verification.split(/\r?\n/).filter((line) => line.startsWith("PASS")).length
          : null,
        failed: verification
          ? verification.split(/\r?\n/).filter((line) => line.startsWith("FAIL")).length
          : null,
        fixtureSetup: fixtureSetup
          ? { experimentId: fixtureSetup.experimentId, status: "passed" }
          : null,
        fixtureCleanup: fixtureCleanup
          ? {
              experimentId: fixtureCleanup.experimentId,
              removedUsers: fixtureCleanup.removedUsers ?? null,
              removedStores: fixtureCleanup.removedStores ?? null,
              remainingUsers: fixtureCleanup.remainingUsers ?? null,
              remainingStores: fixtureCleanup.remainingStores ?? null,
              remainingOrders: fixtureCleanup.remainingOrders ?? null,
              remainingProducts: fixtureCleanup.remainingProducts ?? null,
              status: "passed",
            }
          : null,
        s3Cleanup: s3Cleanup
          ? {
              experimentId: s3Cleanup.experimentId,
              status: s3Cleanup.status,
              remainingPublicObjects: s3Cleanup.remainingPublicObjects ?? null,
              remainingPrivateObjects: s3Cleanup.remainingPrivateObjects ?? null,
            }
          : null,
      },
      notes: [],
    },
  };

  const incomplete = Object.values(sections).some((section) =>
    ["missing", "failed", "partial"].includes(section.status),
  );
  const output = {
    schemaVersion: "1.0.0",
    status: environment.EVIDENCE_STATUS === "sample" ? "sample" : incomplete ? "incomplete" : "final",
    metadata: {
      experimentId: required(environment, "EXPERIMENT_ID"),
      region: required(environment, "AWS_REGION"),
      targetUrl: required(environment, "APP_URL"),
      startedAt,
      endedAt,
    },
    provenance: {
      appCommit: required(environment, "APP_COMMIT_SHA"),
      infraCommit: required(environment, "INFRA_COMMIT_SHA"),
      imageDigest: required(environment, "APP_IMAGE_DIGEST"),
      githubRunIds: {
        appPublish: environment.APP_PUBLISH_RUN_ID ?? null,
        terraformApply: environment.TERRAFORM_APPLY_RUN_ID ?? null,
        experiment: environment.GITHUB_RUN_ID ?? null,
      },
    },
    ...sections,
    baseline: null,
    limitations: [
      "Single-region production-like experiment in ap-southeast-3.",
      "No DDoS, request flooding, GuardDuty, or Security Hub claim.",
      "Manual comparison remains unavailable until a paired baseline is executed.",
    ],
  };

  output.manifestSha256 = crypto
    .createHash("sha256")
    .update(JSON.stringify(output))
    .digest("hex");
  validateEvidence(output);
  return output;
}

function required(environment, name) {
  const value = environment[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function readJson(root, relativePath) {
  const file = path.join(root, relativePath);
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
}

function readText(root, relativePath) {
  const file = path.join(root, relativePath);
  return fs.existsSync(file) ? fs.readFileSync(file, "utf8") : null;
}

function readK6Trials(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs
    .readdirSync(directory)
    .filter((name) => /^trial-\d+\.json$/.test(name))
    .sort()
    .map((name) => {
      const report = JSON.parse(fs.readFileSync(path.join(directory, name), "utf8"));
      const metrics = report.metrics ?? {};
      const thresholds = Object.values(metrics).flatMap((metric) =>
        Object.values(metric.thresholds ?? {}),
      );
      return {
        trial: Number(name.match(/\d+/)?.[0]),
        status: thresholds.every((threshold) => threshold.ok !== false) ? "passed" : "failed",
        requests: metrics.http_reqs?.values?.count ?? null,
        failureRate: metrics.http_req_failed?.values?.rate ?? null,
        checksRate: metrics.checks?.values?.rate ?? null,
        p50Ms: metrics.http_req_duration?.values?.["p(50)"] ?? null,
        p95Ms: metrics.http_req_duration?.values?.["p(95)"] ?? null,
        p99Ms: metrics.http_req_duration?.values?.["p(99)"] ?? null,
        throughputRps: metrics.http_reqs?.values?.rate ?? null,
      };
    });
}

function summarizeTrials(trials) {
  if (trials.length === 0) return null;
  return {
    trialCount: trials.length,
    passedTrials: trials.filter((trial) => trial.status === "passed").length,
    medianP95Ms: median(trials.map((trial) => trial.p95Ms).filter(Number.isFinite)),
    medianThroughputRps: median(
      trials.map((trial) => trial.throughputRps).filter(Number.isFinite),
    ),
    medianFailureRate: median(trials.map((trial) => trial.failureRate).filter(Number.isFinite)),
  };
}

function median(values) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function normalizeCloudWatch(report) {
  if (!report?.MetricDataResults) return [];
  return report.MetricDataResults.map((metric) => ({
    id: metric.Id,
    label: metric.Label ?? metric.Id,
    statusCode: metric.StatusCode,
    timestamps: metric.Timestamps ?? [],
    values: metric.Values ?? [],
  }));
}

function statusFromText(text) {
  return text.split(/\r?\n/).some((line) => line.startsWith("FAIL")) ? "failed" : "passed";
}

function conformanceStatus(verification, fixtureSetup, fixtureCleanup, s3Cleanup) {
  if (!verification || !fixtureSetup || !fixtureCleanup || !s3Cleanup) return "missing";
  if (statusFromText(verification) === "failed") return "failed";
  if (fixtureSetup.experimentId !== fixtureCleanup.experimentId) return "failed";
  if (
    fixtureSetup.experimentId !== s3Cleanup.experimentId ||
    s3Cleanup.status !== "passed" ||
    fixtureCleanup.removedUsers !== 4 ||
    fixtureCleanup.remainingUsers !== 0 ||
    fixtureCleanup.remainingStores !== 0 ||
    fixtureCleanup.remainingOrders !== 0 ||
    fixtureCleanup.remainingProducts !== 0 ||
    s3Cleanup.remainingPublicObjects !== 0 ||
    s3Cleanup.remainingPrivateObjects !== 0
  ) {
    return "failed";
  }
  return "passed";
}

function combinedStatus(...statuses) {
  if (statuses.some((status) => !status || status === "missing")) return "missing";
  return statuses.every((status) => status === "passed") ? "passed" : "failed";
}

function deliveryStatus(verification, timings) {
  if (!verification || Object.values(timings).some((timing) => !timing)) return "missing";
  if (statusFromText(verification) === "failed") return "failed";
  return Object.values(timings).every((timing) => timing.status === "passed")
    ? "passed"
    : "failed";
}

function playwrightStatus(report) {
  if (!report?.stats) return "missing";
  const { expected, unexpected, flaky, skipped } = report.stats;
  return expected > 0 && unexpected === 0 && flaky === 0 && skipped === 0 ? "passed" : "failed";
}

function runtimeStatus(trials) {
  if (trials.length === 0) return "missing";
  if (trials.some((trial) => trial.status !== "passed")) return "failed";
  return trials.length === 3 ? "passed" : "partial";
}

function monitoringStatus(cloudwatch, window, applicationErrors) {
  if (!cloudwatch?.MetricDataResults || !window || !applicationErrors) return "missing";
  if ((applicationErrors.events?.length ?? 0) > 0) return "failed";
  const requiredIds = [
    "albrequests",
    "albp95",
    "ecscpu",
    "ecsmemory",
    "asginservice",
    "rdscpu",
    "rdsconnections",
  ];
  const populated = new Set(
    cloudwatch.MetricDataResults
      .filter((result) => result.StatusCode === "Complete" && result.Values?.length > 0)
      .map((result) => result.Id),
  );
  return requiredIds.every((id) => populated.has(id)) ? "passed" : "partial";
}

function main() {
  const rawDir = process.argv[2] ?? "experiment-evidence";
  const outputFile = process.argv[3] ?? path.join(rawDir, "experiment-evidence.json");
  const evidence = aggregate(rawDir);
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, `${JSON.stringify(evidence, null, 2)}\n`);
  fs.writeFileSync(
    path.join(path.dirname(outputFile), "evidence-manifest.json"),
    `${JSON.stringify(
      {
        schemaVersion: evidence.schemaVersion,
        experimentId: evidence.metadata.experimentId,
        status: evidence.status,
        sha256: evidence.manifestSha256,
      },
      null,
      2,
    )}\n`,
  );
  if (evidence.status !== "final" && process.env.ALLOW_INCOMPLETE_EVIDENCE !== "true") {
    throw new Error(`Evidence package status is ${evidence.status}`);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
