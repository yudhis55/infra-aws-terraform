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
