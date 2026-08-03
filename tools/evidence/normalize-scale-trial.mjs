import fs from "node:fs";
import { pathToFileURL } from "node:url";

export function normalizeScaleTrial(summary, timeline, metadata) {
  const values = (metric) => metric?.values ?? metric ?? {};
  const p95Ms = values(summary.metrics?.http_req_duration)["p(95)"] ?? null;
  const failureRate = values(summary.metrics?.http_req_failed).rate ?? values(summary.metrics?.http_req_failed).value ?? null;
  const checksRate = values(summary.metrics?.checks).rate ?? values(summary.metrics?.checks).value ?? null;
  const throughputRps = values(summary.metrics?.http_reqs).rate ?? null;
  const samples = timeline.samples ?? [];
  const first = samples[0];
  const baselineDesired = first?.ecs?.desired ?? null;
  const baselineRunning = first?.ecs?.running ?? null;
  const baselineAsg = first?.asg?.inService ?? null;
  const desiredScale = samples.find((sample) => sample.ecs?.desired > baselineDesired);
  const taskReady = desiredScale
    ? samples.find(
        (sample) =>
          Date.parse(sample.timestamp) >= Date.parse(desiredScale.timestamp) &&
          sample.ecs?.running > baselineRunning,
      )
    : null;
  const peakIndex = samples.reduce(
    (best, sample, index) => (sample.ecs?.desired > (samples[best]?.ecs?.desired ?? -1) ? index : best),
    0,
  );
  const scaleIn = samples
    .slice(peakIndex + 1)
    .find(
      (sample) =>
        sample.ecs?.desired <= baselineDesired &&
        sample.ecs?.running <= baselineRunning &&
        sample.ecs?.pending === 0,
    );
  const asgScale = samples.find((sample) => sample.asg?.inService > baselineAsg);
  const asgPending = samples.some((sample) => sample.asg?.pending > 0);
  const ecsServiceScaleOut = desiredScale && taskReady ? "passed" : "failed";
  const asgStatus = asgScale ? "observed-passed" : ecsServiceScaleOut === "passed" ? "not-exercised" : asgPending ? "failed" : "not-exercised";
  const scaleInLatencySeconds = secondsBetween(metadata.loadEndedAt, scaleIn?.timestamp);
  const thresholdsPassed =
    Number.isFinite(p95Ms) && p95Ms < 1000 &&
    Number.isFinite(failureRate) && failureRate < 0.01 &&
    Number.isFinite(checksRate) && checksRate > 0.99 &&
    ecsServiceScaleOut === "passed" &&
    Number.isFinite(scaleInLatencySeconds) && scaleInLatencySeconds <= 1200;

  return {
    runType: metadata.runType ?? "final-trial",
    runStatus: thresholdsPassed ? "passed" : "failed",
    trialId: String(metadata.trialId),
    profileDigest: metadata.profileDigest,
    startedAt: metadata.loadStartedAt,
    endedAt: metadata.collectionEndedAt,
    requests: values(summary.metrics?.http_reqs).count ?? null,
    failureRate,
    checksRate,
    p95Ms,
    throughputRps,
    ecsServiceScaleOut,
    ecsScaleOutLatencySeconds: secondsBetween(metadata.thresholdLoadStartedAt, desiredScale?.timestamp),
    taskReadyLatencySeconds: secondsBetween(desiredScale?.timestamp, taskReady?.timestamp),
    scaleInLatencySeconds,
    asgStatus,
  };
}

function secondsBetween(start, end) {
  if (!start || !end) return null;
  const seconds = (Date.parse(end) - Date.parse(start)) / 1000;
  return Number.isFinite(seconds) && seconds >= 0 ? seconds : null;
}

function main() {
  const [summaryFile, timelineFile, metadataFile, outputFile] = process.argv.slice(2);
  if (!outputFile) throw new Error("Usage: normalize-scale-trial <summary> <timeline> <metadata> <output>");
  const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
  fs.writeFileSync(outputFile, `${JSON.stringify(normalizeScaleTrial(read(summaryFile), read(timelineFile), read(metadataFile)), null, 2)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
