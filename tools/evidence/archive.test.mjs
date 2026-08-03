import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createArchive, verifyArchive } from "./archive.mjs";

test("creates a sanitized archive and detects tampering", () => {
  const source = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-source-"));
  const archive = fs.mkdtempSync(path.join(os.tmpdir(), "eepistore-archive-"));
  fs.writeFileSync(path.join(source, "experiment-evidence.json"), "{}\n");
  fs.writeFileSync(path.join(source, "TF_VAR_secret.json"), "do-not-copy\n");
  fs.mkdirSync(path.join(source, "monitoring"));
  fs.writeFileSync(path.join(source, "monitoring", "metrics.json"), "{}\n");
  const index = createArchive(source, archive);
  assert.equal(index.entries.length, 2);
  assert.equal(fs.existsSync(path.join(archive, "TF_VAR_secret.json")), false);
  assert.equal(verifyArchive(archive).entries.length, 2);
  fs.writeFileSync(path.join(archive, "monitoring", "metrics.json"), "tampered\n");
  assert.throws(() => verifyArchive(archive), /verification failed/);
});
