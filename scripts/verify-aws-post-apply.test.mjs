import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const verifier = await readFile(new URL("./verify-aws-post-apply.sh", import.meta.url), "utf8");

test("keeps health strict and retries readiness within a bounded window", () => {
  assert.match(verifier, /verify_json_endpoint "health" "\$application_url\/api\/health"\n/);
  assert.match(verifier, /verify_json_endpoint "readiness" "\$application_url\/api\/readiness" 12 15/);
});

test("records endpoint attempt counts without weakening status=ok", () => {
  assert.match(verifier, /jq -e '\.status == "ok"'/);
  assert.match(verifier, /\{status:"passed",attempts:\$attempts,httpStatus:\$status\}/);
  assert.match(verifier, /FAIL runtime-\$\{name\}:.+after \$attempts attempt\(s\)/);
});
