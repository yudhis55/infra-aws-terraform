import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const runner = await readFile(new URL("./run-k6-on-agent.sh", import.meta.url), "utf8");

test("keeps successful SSM output limited to the encoded k6 summary", () => {
  assert.match(runner, /> \/tmp\/eepistore-k6\.log 2>&1/);
  assert.match(runner, /printf K6_SUMMARY_BASE64=.*printf :END/);
  assert.match(runner, /K6_SUMMARY_BASE64=\[A-Za-z0-9\+\/=\]\*:END/);
  assert.match(runner, /summary_payload="\$\{summary_frame#K6_SUMMARY_BASE64=\}"/);
  assert.match(runner, /summary_payload="\$\{summary_payload%:END\}"/);
  assert.doesNotMatch(runner, /printf \\\\n/);
});

test("returns a bounded diagnostic tail when k6 fails", () => {
  assert.match(runner, /tail -c 12000 \/tmp\/eepistore-k6\.log >&2; exit 1/);
});
