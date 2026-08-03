import assert from "node:assert/strict";
import test from "node:test";
import { validateEvidence } from "./validate.mjs";

const hash = (character) => character.repeat(64);
const commit = (character) => character.repeat(40);

function section(status = "missing") {
  return { status, metrics: {}, notes: [] };
}

function campaignEvidence() {
  const inputDigest = `sha256:${hash("d")}`;
  return {
    schemaVersion: "2.0.0",
    status: "draft",
    campaign: {
      campaignId: "campaign-test",
      region: "ap-southeast-3",
      targetUrl: "https://eepistore.web.id",
      startedAt: "2026-08-04T00:00:00Z",
      endedAt: null,
      primaryLineage: {
        appCommit: commit("a"),
        infraCommit: commit("b"),
        imageDigest: `sha256:${hash("c")}`,
        inputDigest,
      },
      cycles: {
        cycleR: {
          cycleId: "cycle-r",
          runType: "baseline",
          runStatus: "not-exercised",
          inputDigest,
          githubRunIds: {},
          timings: {},
        },
        cycleF: {
          cycleId: "cycle-f",
          runType: "baseline",
          runStatus: "not-exercised",
          inputDigest,
          githubRunIds: {},
          timings: {},
        },
      },
      childFaultLineages: [],
    },
    delivery: section(),
    faultInjection: section("not-exercised"),
    security: section(),
    functional: section(),
    wafRateProtection: section("not-exercised"),
    networkIsolation: section("not-exercised"),
    scalability: section("not-exercised"),
    monitoring: section(),
    cleanup: section(),
    conformance: section(),
    baseline: null,
    limitations: [],
    manifestSha256: hash("e"),
  };
}

test("accepts the research campaign schema", () => {
  assert.equal(validateEvidence(campaignEvidence()).schemaVersion, "2.0.0");
});

test("rejects unsupported schema versions", () => {
  assert.throws(
    () => validateEvidence({ schemaVersion: "3.0.0" }),
    /Unsupported evidence schema version/,
  );
});

test("rejects a cycle whose input digest differs in format", () => {
  const evidence = campaignEvidence();
  evidence.campaign.cycles.cycleR.inputDigest = "mutable-input";
  assert.throws(() => validateEvidence(evidence), /Evidence schema validation failed/);
});

test("rejects untracked campaign fields", () => {
  const evidence = campaignEvidence();
  evidence.campaign.unreviewed = true;
  assert.throws(() => validateEvidence(evidence), /Evidence schema validation failed/);
});
