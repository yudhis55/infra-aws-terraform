import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

export function buildCampaignMetadata(input) {
  requireCommit(input.appCommit, "appCommit");
  requireCommit(input.infraCommit, "infraCommit");
  if (!/^sha256:[0-9a-f]{64}$/.test(input.imageDigest ?? "")) {
    throw new Error("imageDigest must be an immutable sha256 digest");
  }
  if (input.region !== "ap-southeast-3") throw new Error("Unexpected AWS region");
  const target = new URL(input.targetUrl);
  if (target.protocol !== "https:" || target.hostname !== "eepistore.web.id") {
    throw new Error("targetUrl must be the owned HTTPS Eepistore domain");
  }

  const scientificInput = {
    appCommit: input.appCommit,
    infraCommit: input.infraCommit,
    imageDigest: input.imageDigest,
    region: input.region,
    targetUrl: input.targetUrl,
    mediaUrl: input.mediaUrl,
    profile: input.profile,
  };
  const inputDigest = `sha256:${digest(stableStringify(scientificInput))}`;
  const date = input.startedAt.slice(0, 10).replaceAll("-", "");
  return {
    campaign: {
      campaignId: `campaign-${date}-${input.appCommit.slice(0, 7)}-${input.infraCommit.slice(0, 7)}`,
      region: input.region,
      targetUrl: input.targetUrl,
      startedAt: input.startedAt,
      endedAt: null,
    },
    lineage: {
      appCommit: input.appCommit,
      infraCommit: input.infraCommit,
      imageDigest: input.imageDigest,
      inputDigest,
    },
    scientificInput,
  };
}

export function assertCycleInput(campaignLineage, cycle) {
  if (cycle.inputDigest !== campaignLineage.inputDigest) {
    throw new Error(`${cycle.cycleId} does not match the frozen campaign input`);
  }
  return cycle;
}

function requireCommit(value, name) {
  if (!/^[0-9a-f]{40}$/.test(value ?? "")) throw new Error(`${name} must be a 40-character SHA`);
}

function stableStringify(value) {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function digest(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function main() {
  const inputFile = process.argv[2];
  const outputDir = process.argv[3] ?? "experiment-evidence/metadata";
  if (!inputFile) throw new Error("Usage: node campaign.mjs <input.json> [output-directory]");
  const metadata = buildCampaignMetadata(JSON.parse(fs.readFileSync(inputFile, "utf8")));
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(path.join(outputDir, "campaign.json"), `${JSON.stringify(metadata.campaign, null, 2)}\n`);
  fs.writeFileSync(path.join(outputDir, "lineage.json"), `${JSON.stringify(metadata.lineage, null, 2)}\n`);
  fs.writeFileSync(path.join(outputDir, "experiment-profile.json"), `${JSON.stringify(metadata.scientificInput, null, 2)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
