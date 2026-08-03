import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

test("validates the experiment policy structure without IAM simulator permission", () => {
  const output = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-iam-structure-"));
  const result = spawnSync(
    process.execPath,
    [
      "scripts/validate-experiment-iam.mjs",
      "arn:aws:iam::557947229844:role/eepistore-infra-experiment-role",
      output,
      "structure",
    ],
    { cwd: path.resolve("../.."), encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  const evidence = JSON.parse(fs.readFileSync(path.join(output, "policy-structure.json"), "utf8"));
  assert.equal(evidence.status, "passed");
  assert.equal(evidence.validAgentScope, true);
});
