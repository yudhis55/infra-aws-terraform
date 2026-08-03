import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { validateEvidence } from "./validate.mjs";

const requiredSections = [
  "delivery",
  "faultInjection",
  "security",
  "functional",
  "wafRateProtection",
  "networkIsolation",
  "scalability",
  "monitoring",
  "cleanup",
  "conformance",
];

export function aggregateCampaign(rawDir, environment = process.env) {
  const campaign = readJson(rawDir, "metadata/campaign.json");
  const lineage = readJson(rawDir, "metadata/lineage.json");
  if (!campaign || !lineage) {
    throw new Error("metadata/campaign.json and metadata/lineage.json are required");
  }

  const cycleR = normalizeCycle(readJson(rawDir, "delivery/cycle-r.json"), "cycle-r");
  const cycleF = normalizeCycle(readJson(rawDir, "delivery/cycle-f.json"), "cycle-f");
  const faults = readJson(rawDir, "security/fault-injection-matrix.json")?.cases ?? [];
  const faultLineages = readJson(rawDir, "metadata/child-fault-lineages.json") ?? [];
  const playwright = readJson(rawDir, "functional/playwright-results.json");
  const zap = readJson(rawDir, "security/zap-summary.json");
  const waf = readJson(rawDir, "security/waf-rate-protection.json");
  const network = readJson(rawDir, "security/network-isolation.json");
  const trials = readTrials(path.join(rawDir, "runtime"));
  const scaling = readJson(rawDir, "runtime/scaling-events.json");
  const monitoring = readJson(rawDir, "monitoring/cloudwatch-metrics.json");
  const applicationErrors = readJson(rawDir, "monitoring/application-errors.json");
  const cleanup = collectCleanup(rawDir);
  const conformance = readJson(rawDir, "conformance/report.json");

  const sections = {
    delivery: deliverySection(cycleR, cycleF, lineage.inputDigest),
    faultInjection: faultSection(faults),
    security: securitySection(zap),
    functional: functionalSection(playwright),
    wafRateProtection: wafSection(waf),
    networkIsolation: networkSection(network),
    scalability: scalabilitySection(trials, scaling),
    monitoring: monitoringSection(monitoring, applicationErrors),
    cleanup: cleanupSection(cleanup),
    conformance: conformanceSection(conformance, cycleR, cycleF, lineage.inputDigest),
  };

  const finalReady = requiredSections.every((name) => {
    const status = sections[name].status;
    return status === "passed" || (name === "scalability" && status === "not-exercised");
  });
  const failed = requiredSections.some((name) => sections[name].status === "failed");
  const requestedStatus = environment.CAMPAIGN_STATUS?.trim();
  const status = requestedStatus || (failed ? "failed" : finalReady ? "final" : "incomplete");

  const output = {
    schemaVersion: "2.0.0",
    status,
    campaign: {
      campaignId: campaign.campaignId,
      region: campaign.region,
      targetUrl: campaign.targetUrl,
      startedAt: campaign.startedAt,
      endedAt: campaign.endedAt ?? null,
      primaryLineage: {
        appCommit: lineage.appCommit,
        infraCommit: lineage.infraCommit,
        imageDigest: lineage.imageDigest,
        inputDigest: lineage.inputDigest,
      },
      cycles: { cycleR, cycleF },
      childFaultLineages: faultLineages,
    },
    ...sections,
    baseline: { manualComparison: null },
    limitations: campaign.limitations ?? [
      "Single-region production-like experiment in ap-southeast-3.",
      "The bounded WAF scenario is not a DDoS or volumetric flooding test.",
      "ASG capacity scaling may be not-exercised when initial EC2 capacity is sufficient.",
      "Manual deployment comparison is outside the final experiment scope.",
    ],
    manifestSha256: "0".repeat(64),
  };
  output.manifestSha256 = digest({ ...output, manifestSha256: undefined });
  validateEvidence(output);
  return output;
}

function normalizeCycle(value, cycleId) {
  if (!value) {
    return {
      cycleId,
      runType: "baseline",
      runStatus: "not-exercised",
      inputDigest: `sha256:${"0".repeat(64)}`,
      githubRunIds: {},
      timings: {},
      notes: ["Cycle evidence is missing."],
    };
  }
  return {
    cycleId,
    runType: "baseline",
    runStatus: value.runStatus,
    inputDigest: value.inputDigest,
    githubRunIds: value.githubRunIds ?? {},
    timings: value.timings ?? {},
    notes: value.notes ?? [],
  };
}

function deliverySection(cycleR, cycleF, inputDigest) {
  const matchingInputs = [cycleR.inputDigest, cycleF.inputDigest].every(
    (value) => value === inputDigest,
  );
  const passed = [cycleR, cycleF].every((cycle) => cycle.runStatus === "passed");
  return section(passed && matchingInputs ? "passed" : "failed", {
    cycleR: cycleR.timings,
    cycleF: cycleF.timings,
    matchingInputs,
  });
}

function faultSection(cases) {
  if (cases.length === 0) return section("missing", { cases: [], summary: null });
  const requiredFaultIds = [
    "FI-IAC-01",
    "FI-IAC-02",
    "FI-IAC-03",
    "FI-SCA-01",
    "FI-IMG-01",
    "FI-AUTH-01",
  ];
  const valid = cases.filter((item) => item.runStatus !== "invalid-fixture");
  const detected = valid.filter((item) => item.detected === true);
  const blockingSeverity = valid.filter((item) => ["high", "critical"].includes(item.severity));
  const blocked = blockingSeverity.filter((item) => item.deliveryBlocked === true);
  const observedIds = [...new Set(cases.map((item) => item.faultId))].sort();
  const completeMatrix =
    observedIds.length === requiredFaultIds.length &&
    requiredFaultIds.every((faultId) => observedIds.includes(faultId));
  const allPassed =
    completeMatrix &&
    valid.length === requiredFaultIds.length &&
    valid.every((item) => item.runStatus === "passed");
  const status = allPassed
    ? "passed"
    : cases.some((item) => item.runStatus === "failed")
      ? "failed"
      : "partial";
  return section(status, {
    cases,
    summary: {
      requiredCases: requiredFaultIds.length,
      completeMatrix,
      totalCases: cases.length,
      validCases: valid.length,
      invalidFixtures: cases.length - valid.length,
      detectedCases: detected.length,
      detectionCoverage: ratio(detected.length, valid.length),
      highCriticalCases: blockingSeverity.length,
      blockedHighCriticalCases: blocked.length,
      gateBlockRate: ratio(blocked.length, blockingSeverity.length),
    },
  });
}

function securitySection(zap) {
  if (!zap) return section("missing", {});
  const confirmed = zap.findings?.filter((finding) => finding.triageStatus === "confirmed") ?? [];
  const residualHighCritical = confirmed.filter((finding) =>
    ["high", "critical"].includes(String(finding.severity).toLowerCase()),
  );
  return section(residualHighCritical.length === 0 ? "passed" : "failed", {
    ...zap,
    residualConfirmedHighCritical: residualHighCritical.length,
  });
}

function functionalSection(playwright) {
  if (!playwright?.stats) return section("missing", {});
  const { expected = 0, unexpected = 0, flaky = 0, skipped = 0 } = playwright.stats;
  return section(
    expected > 0 && unexpected === 0 && flaky === 0 && skipped === 0 ? "passed" : "failed",
    { expected, unexpected, flaky, skipped, durationMs: playwright.stats.duration ?? null },
  );
}

function wafSection(waf) {
  if (!waf) return section("missing", {});
  const total = Number(waf.totalRequests ?? 0);
  const blocked = Number(waf.blockedRequests ?? 0);
  const correlated = waf.metricCorrelated === true && waf.sampleCorrelated === true;
  const passed = blocked > 0 && correlated && waf.cleanupStatus === "passed" && waf.scopeViolation !== true;
  const status = passed ? "passed" : blocked > 0 && !correlated ? "partial" : "failed";
  return section(status, {
    ...waf,
    blockRatio: ratio(blocked, total),
    timeToDetectSeconds: secondsBetween(waf.startedAt, waf.firstBlockAt),
  });
}

function networkSection(network) {
  if (!network?.attempts?.length) return section("missing", {});
  const vpcAttempts = network.attempts.filter(
    (attempt) => attempt.control === "vpc-network" && attempt.expected === "denied",
  );
  const positiveAttempts = network.attempts.filter((attempt) => attempt.control === "positive-network");
  const policyAttempts = network.attempts.filter((attempt) => attempt.control === "storage-policy");
  const outcomesMatch = network.attempts.every((attempt) => attempt.actual === attempt.expected);
  const flowCorrelated = vpcAttempts.every((attempt) => attempt.flowLogAction === "REJECT");
  const status = outcomesMatch && flowCorrelated ? "passed" : outcomesMatch ? "partial" : "failed";
  return section(status, {
    attempts: network.attempts,
    summary: {
      totalAttempts: network.attempts.length,
      matchedOutcomes: network.attempts.filter((attempt) => attempt.actual === attempt.expected).length,
      correlatedVpcRejects: vpcAttempts.filter((attempt) => attempt.flowLogAction === "REJECT").length,
      vpcAttempts: vpcAttempts.length,
      storagePolicyAttempts: policyAttempts.length,
      positiveControlAttempts: positiveAttempts.length,
    },
  });
}

function scalabilitySection(trials, scaling) {
  if (trials.length === 0) return section("missing", { trials: [], aggregate: null });
  const finalTrials = trials.filter((trial) => trial.runType === "final-trial");
  const serviceObserved = finalTrials.filter((trial) => trial.ecsServiceScaleOut === "passed").length;
  const allThresholds = finalTrials.every((trial) => trial.runStatus === "passed");
  const servicePassed = finalTrials.length === 3 && serviceObserved === 3;
  const asgStatus = scaling?.asgStatus ?? "not-exercised";
  const status = allThresholds && servicePassed ? "passed" : "failed";
  return section(status, {
    trials: finalTrials,
    aggregate: summarizeTrials(finalTrials),
    ecsService: {
      status: servicePassed ? "passed" : "failed",
      observedTrials: serviceObserved,
      requiredTrials: 3,
    },
    asg: {
      status: asgStatus,
      activities: scaling?.asgActivities ?? [],
    },
  });
}

function monitoringSection(metrics, errors) {
  if (!metrics || !errors) return section("missing", {});
  const requiredSeries = metrics.requiredSeries ?? [];
  const populatedSeries = metrics.populatedSeries ?? [];
  const missing = requiredSeries.filter((name) => !populatedSeries.includes(name));
  const errorCount = errors.events?.length ?? 0;
  return section(missing.length === 0 && errorCount === 0 ? "passed" : missing.length ? "partial" : "failed", {
    requiredSeries,
    populatedSeries,
    missingSeries: missing,
    applicationErrorEvents: errorCount,
    series: (metrics.MetricDataResults ?? []).map((metric) => ({
      id: metric.Id,
      label: metric.Label ?? metric.Id,
      statusCode: metric.StatusCode,
      timestamps: metric.Timestamps ?? [],
      values: metric.Values ?? [],
    })),
  });
}

function collectCleanup(rawDir) {
  return {
    database: readJson(rawDir, "cleanup/database-cleanup.json"),
    s3: readJson(rawDir, "cleanup/s3-cleanup.json"),
    agent: readJson(rawDir, "cleanup/agent-cleanup.json"),
    terraformExperiment: readJson(rawDir, "cleanup/terraform-experiment-cleanup.json"),
  };
}

function cleanupSection(cleanup) {
  if (Object.values(cleanup).some((value) => !value)) return section("missing", cleanup);
  const residual = {
    users: cleanup.database.remainingUsers ?? null,
    stores: cleanup.database.remainingStores ?? null,
    orders: cleanup.database.remainingOrders ?? null,
    products: cleanup.database.remainingProducts ?? null,
    payments: cleanup.database.remainingPayments ?? null,
    rateLimitBuckets: cleanup.database.remainingRateLimitBuckets ?? null,
    publicObjects: cleanup.s3.remainingPublicObjects ?? null,
    privateObjects: cleanup.s3.remainingPrivateObjects ?? null,
    agents: cleanup.agent.remainingAgents ?? null,
    temporaryResources: cleanup.terraformExperiment.remainingTemporaryResources ?? null,
  };
  const passed = Object.values(residual).every((value) => value === 0);
  return section(passed ? "passed" : "failed", { ...cleanup, residual });
}

function conformanceSection(report, cycleR, cycleF, inputDigest) {
  if (!report) return section("missing", {});
  const sameInput = cycleR.inputDigest === inputDigest && cycleF.inputDigest === inputDigest;
  const driftPassed =
    report.controlledDrift?.status === "passed" &&
    report.controlledDrift?.recoveryPlanUpdates === 1 &&
    report.controlledDrift?.remainingControlledDriftTags === 0 &&
    report.controlledDrift?.noChangeAfterRecovery === true;
  const passed =
    report.status === "passed" &&
    sameInput &&
    report.semanticDifferences?.length === 0 &&
    driftPassed;
  return section(passed ? "passed" : "failed", { ...report, sameInput });
}

function readTrials(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs
    .readdirSync(directory)
    .filter((name) => /^scale-trial-[1-3]\.json$/.test(name))
    .sort()
    .map((name) => readJson(directory, name));
}

function summarizeTrials(trials) {
  if (trials.length === 0) return null;
  return {
    trialCount: trials.length,
    p95Ms: distribution(trials.map((trial) => trial.p95Ms)),
    throughputRps: distribution(trials.map((trial) => trial.throughputRps)),
    failureRate: distribution(trials.map((trial) => trial.failureRate)),
    ecsScaleOutLatencySeconds: distribution(
      trials.map((trial) => trial.ecsScaleOutLatencySeconds),
    ),
    taskReadyLatencySeconds: distribution(trials.map((trial) => trial.taskReadyLatencySeconds)),
    scaleInLatencySeconds: distribution(trials.map((trial) => trial.scaleInLatencySeconds)),
  };
}

function distribution(values) {
  const valid = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (valid.length === 0) return null;
  const middle = Math.floor(valid.length / 2);
  const median = valid.length % 2 ? valid[middle] : (valid[middle - 1] + valid[middle]) / 2;
  return {
    values: valid,
    median,
    min: valid[0],
    max: valid.at(-1),
    range: valid.at(-1) - valid[0],
  };
}

function ratio(numerator, denominator) {
  return denominator > 0 ? numerator / denominator : null;
}

function secondsBetween(start, end) {
  if (!start || !end) return null;
  const seconds = (Date.parse(end) - Date.parse(start)) / 1000;
  return Number.isFinite(seconds) && seconds >= 0 ? seconds : null;
}

function section(status, metrics, notes = []) {
  return { status, metrics, notes };
}

function readJson(root, relativePath) {
  const file = path.join(root, relativePath);
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
}

function digest(value) {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function main() {
  const rawDir = process.argv[2] ?? "experiment-evidence";
  const outputFile = process.argv[3] ?? path.join(rawDir, "experiment-evidence.json");
  const evidence = aggregateCampaign(rawDir);
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, `${JSON.stringify(evidence, null, 2)}\n`);
  if (evidence.status !== "final" && process.env.ALLOW_INCOMPLETE_EVIDENCE !== "true") {
    throw new Error(`Campaign evidence status is ${evidence.status}`);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
