import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const script = fileURLToPath(new URL("./validate-backend-policy.mjs", import.meta.url));
const source = fileURLToPath(
  new URL("../bootstrap/github-oidc/plan-backend-policy.json", import.meta.url),
);

test("accepts only the workload and retained ECR backend prefixes", () => {
  const result = spawnSync(process.execPath, [script, source], {
    encoding: "utf8",
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /PASS backend policy exact state and lockfile scope/);
});

test("rejects a bucket-wide object wildcard", async () => {
  const directory = await mkdtemp(join(tmpdir(), "backend-policy-"));
  const policy = JSON.parse(await readFile(source, "utf8"));
  policy.Statement.find(
    (statement) => statement.Sid === "ReadStateAndManageLockfile",
  ).Resource = "arn:aws:s3:::eepistore-dev-terraform-state/*";
  const unsafePolicy = join(directory, "unsafe.json");
  await writeFile(unsafePolicy, JSON.stringify(policy));

  const result = spawnSync(process.execPath, [script, unsafePolicy], {
    encoding: "utf8",
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unexpected backend object resources/);
});
