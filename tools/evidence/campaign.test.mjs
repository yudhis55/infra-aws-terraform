import assert from "node:assert/strict";
import test from "node:test";
import { assertCycleInput, buildCampaignMetadata } from "./campaign.mjs";

const input = {
  appCommit: "a".repeat(40),
  infraCommit: "b".repeat(40),
  imageDigest: `sha256:${"c".repeat(64)}`,
  region: "ap-southeast-3",
  targetUrl: "https://eepistore.web.id",
  mediaUrl: "https://media.eepistore.web.id",
  startedAt: "2026-08-04T01:00:00Z",
  profile: { maxVus: 30, rateLimit: 100 },
};

test("builds a deterministic campaign and scientific input digest", () => {
  const first = buildCampaignMetadata(input);
  const second = buildCampaignMetadata({ ...input, profile: { rateLimit: 100, maxVus: 30 } });
  assert.equal(first.campaign.campaignId, "campaign-20260804-aaaaaaa-bbbbbbb");
  assert.equal(first.lineage.inputDigest, second.lineage.inputDigest);
});

test("rejects a mutable image tag", () => {
  assert.throws(() => buildCampaignMetadata({ ...input, imageDigest: "image:latest" }), /immutable/);
});

test("rejects a cycle from a different frozen input", () => {
  const { lineage } = buildCampaignMetadata(input);
  assert.throws(
    () => assertCycleInput(lineage, { cycleId: "cycle-f", inputDigest: `sha256:${"e".repeat(64)}` }),
    /does not match/,
  );
});
