import assert from "node:assert/strict";
import test from "node:test";
import { normalizeScaleTrial } from "./normalize-scale-trial.mjs";

test("separates ECS service scale-out from unexercised ASG capacity scaling", () => {
  const summary = { metrics: {
    http_req_duration: { values: { "p(95)": 400 } },
    http_req_failed: { values: { rate: 0 } },
    checks: { values: { rate: 1 } },
    http_reqs: { values: { count: 1000, rate: 20 } },
  } };
  const timeline = { samples: [
    { timestamp: "2026-08-04T00:00:00Z", ecs: { desired: 2, running: 2, pending: 0 }, asg: { inService: 2, pending: 0 } },
    { timestamp: "2026-08-04T00:02:00Z", ecs: { desired: 3, running: 2, pending: 1 }, asg: { inService: 2, pending: 0 } },
    { timestamp: "2026-08-04T00:04:00Z", ecs: { desired: 3, running: 3, pending: 0 }, asg: { inService: 2, pending: 0 } },
    { timestamp: "2026-08-04T00:20:00Z", ecs: { desired: 2, running: 2, pending: 0 }, asg: { inService: 2, pending: 0 } },
  ] };
  const result = normalizeScaleTrial(summary, timeline, {
    trialId: 1,
    profileDigest: `sha256:${"a".repeat(64)}`,
    loadStartedAt: "2026-08-04T00:00:00Z",
    thresholdLoadStartedAt: "2026-08-04T00:01:00Z",
    loadEndedAt: "2026-08-04T00:10:00Z",
    collectionEndedAt: "2026-08-04T00:20:00Z",
  });
  assert.equal(result.runStatus, "passed");
  assert.equal(result.ecsScaleOutLatencySeconds, 60);
  assert.equal(result.taskReadyLatencySeconds, 120);
  assert.equal(result.asgStatus, "not-exercised");
});

test("measures the first completed scale-in from peak after load ends", () => {
  const summary = { metrics: {
    http_req_duration: { values: { "p(95)": 300 } },
    http_req_failed: { values: { rate: 0 } },
    checks: { values: { rate: 1 } },
    http_reqs: { values: { count: 2000, rate: 25 } },
  } };
  const timeline = { samples: [
    { timestamp: "2026-08-10T00:00:00Z", ecs: { desired: 2, running: 2, pending: 0 }, asg: { inService: 2, pending: 0 } },
    { timestamp: "2026-08-10T00:08:00Z", ecs: { desired: 6, running: 4, pending: 2 }, asg: { inService: 4, pending: 0 } },
    { timestamp: "2026-08-10T00:10:00Z", ecs: { desired: 6, running: 6, pending: 0 }, asg: { inService: 6, pending: 0 } },
    { timestamp: "2026-08-10T00:21:00Z", ecs: { desired: 5, running: 5, pending: 0 }, asg: { inService: 6, pending: 0 } },
  ] };
  const result = normalizeScaleTrial(summary, timeline, {
    trialId: 1,
    profileDigest: `sha256:${"b".repeat(64)}`,
    loadStartedAt: "2026-08-10T00:00:00Z",
    thresholdLoadStartedAt: "2026-08-10T00:05:00Z",
    loadEndedAt: "2026-08-10T00:15:00Z",
    collectionEndedAt: "2026-08-10T00:25:00Z",
  });
  assert.equal(result.runStatus, "passed");
  assert.equal(result.scaleInLatencySeconds, 360);
  assert.equal(result.ecsServiceScaleOut, "passed");
  assert.equal(result.asgStatus, "observed-passed");
});
