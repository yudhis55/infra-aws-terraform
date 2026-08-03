import { readFile } from "node:fs/promises";

const policyPath = process.argv[2];

if (!policyPath) {
  throw new Error("usage: node validate-backend-policy.mjs <policy.json>");
}

const policy = JSON.parse(await readFile(policyPath, "utf8"));
const statements = new Map(policy.Statement.map((statement) => [statement.Sid, statement]));
const stateStatement = statements.get("ReadStateAndManageLockfile");

if (!stateStatement || stateStatement.Effect !== "Allow") {
  throw new Error("ReadStateAndManageLockfile allow statement is required");
}

const expectedActions = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"];
const expectedResources = [
  "arn:aws:s3:::eepistore-dev-terraform-state/eepistore/bootstrap/ecr/*",
  "arn:aws:s3:::eepistore-dev-terraform-state/eepistore/dev/*",
];
const actualActions = [stateStatement.Action].flat().sort();
const actualResources = [stateStatement.Resource].flat().sort();

if (JSON.stringify(actualActions) !== JSON.stringify(expectedActions)) {
  throw new Error(`unexpected backend object actions: ${actualActions.join(",")}`);
}

if (JSON.stringify(actualResources) !== JSON.stringify(expectedResources)) {
  throw new Error(`unexpected backend object resources: ${actualResources.join(",")}`);
}

console.log("PASS backend policy exact state and lockfile scope");
