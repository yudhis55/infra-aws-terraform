import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

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
    { cwd: repoRoot, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  const evidence = JSON.parse(fs.readFileSync(path.join(output, "policy-structure.json"), "utf8"));
  assert.equal(evidence.status, "passed");
  assert.equal(evidence.validAgentScope, true);
});

test("allows only the Eepistore repository reads needed for image provenance", () => {
  const policy = JSON.parse(
    fs.readFileSync(
      path.join(repoRoot, "bootstrap/github-oidc/experiment-evidence-policy.json"),
      "utf8",
    ),
  );
  const statement = policy.Statement.find(
    (candidate) => candidate.Sid === "VerifyPublishedImageProvenance",
  );

  assert.deepEqual(statement.Action, ["ecr:DescribeImages", "ecr:DescribeRepositories"]);
  assert.equal(
    statement.Resource,
    "arn:aws:ecr:ap-southeast-3:557947229844:repository/eepistore-repo",
  );
});
