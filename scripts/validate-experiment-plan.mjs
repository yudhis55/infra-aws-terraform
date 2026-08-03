import fs from "node:fs";

const [planFile = "tfplan.json", mode = "off"] = process.argv.slice(2);
const plan = JSON.parse(fs.readFileSync(planFile, "utf8"));
const changes = (plan.resource_changes ?? []).filter(
  ({ change }) => !(change.actions.length === 1 && change.actions[0] === "no-op"),
);

const allowed = {
  agent: [/^module\.experiment\./],
  "rate-test": [/^module\.security\.aws_wafv2_(web_acl|ip_set)\./],
  performance: [/^module\.security\.aws_wafv2_(web_acl|ip_set)\./],
  cleanup: [/^module\.experiment\./, /^module\.security\.aws_wafv2_(web_acl|ip_set)\./],
  "drift-recovery": [/^module\.networking\.aws_security_group\.alb$/],
};

if (!allowed[mode]) throw new Error(`Unsupported experiment plan mode: ${mode}`);
const unexpected = changes.filter(({ address }) => !allowed[mode].some((pattern) => pattern.test(address)));
const replacements = changes.filter(({ change }) =>
  ["delete,create", "create,delete"].includes(change.actions.join(",")),
);
if (unexpected.length || replacements.length) {
  throw new Error(
    JSON.stringify(
      {
        mode,
        unexpected: unexpected.map(({ address, change }) => ({ address, actions: change.actions })),
        replacements: replacements.map(({ address }) => address),
      },
      null,
      2,
    ),
  );
}

if (mode === "drift-recovery") {
  if (changes.length !== 1 || changes[0].change.actions.join(",") !== "update") {
    throw new Error("drift-recovery must contain exactly one in-place update");
  }
  const { before = {}, after = {} } = changes[0].change;
  const changedKeys = [...new Set([...Object.keys(before), ...Object.keys(after)])].filter(
    (key) => JSON.stringify(before[key]) !== JSON.stringify(after[key]),
  );
  if (changedKeys.some((key) => !["tags", "tags_all"].includes(key))) {
    throw new Error(`drift-recovery changed unexpected attributes: ${changedKeys.join(", ")}`);
  }
  if (before.tags?.ExperimentDrift !== "controlled" || after.tags?.ExperimentDrift != null) {
    throw new Error("drift-recovery must remove only the controlled ExperimentDrift tag");
  }
}

console.log(
  JSON.stringify({ status: "passed", mode, reviewedChanges: changes.length, addresses: changes.map(({ address }) => address) }),
);
