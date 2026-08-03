import assert from "node:assert/strict";
import test from "node:test";
import { correlateNetwork } from "./correlate-network.mjs";

test("correlates a denied attempt to an exact destination and port", () => {
  const result = correlateNetwork(
    { attempts: [{ id: "rds", destinationIp: "10.0.3.4", port: 5432, actual: "denied" }] },
    { status: "Complete", results: [[
      { field: "dstAddr", value: "10.0.3.4" },
      { field: "dstPort", value: "5432" },
      { field: "action", value: "REJECT" },
      { field: "logStatus", value: "OK" },
    ]] },
  );
  assert.equal(result.attempts[0].flowLogAction, "REJECT");
  assert.equal(result.flowLogQueryStatus, "Complete");
});
