import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const roleArn =
  process.argv[2] ?? "arn:aws:iam::557947229844:role/eepistore-infra-experiment-role";
const outputDirectory = process.argv[3] ?? "iam-validation-evidence";
const validationMode = process.argv[4] ?? "simulate";
const accountId = "557947229844";
const region = "ap-southeast-3";
const clusterArn = `arn:aws:ecs:${region}:${accountId}:cluster/eepistore-cluster`;
const aws = process.platform === "win32" ? "aws.exe" : "aws";

fs.mkdirSync(outputDirectory, { recursive: true });

if (validationMode === "structure") {
  const policy = JSON.parse(
    fs.readFileSync("bootstrap/github-oidc/experiment-evidence-policy.json", "utf8"),
  );
  const statements = policy.Statement ?? [];
  const allowedActions = statements
    .filter(({ Effect }) => Effect === "Allow")
    .flatMap(({ Action }) => (Array.isArray(Action) ? Action : [Action]));
  const prohibitedActions = [
    "iam:CreateRole",
    "iam:PutRolePolicy",
    "ecs:RegisterTaskDefinition",
    "ecs:UpdateService",
    "ec2:TerminateInstances",
    "rds:DeleteDBInstance",
    "s3:DeleteBucket",
    "secretsmanager:PutSecretValue",
    "wafv2:UpdateWebACL",
  ];
  const requiredSids = [
    "ReadTerraformState",
    "UseOnlyApprovedRunShellDocument",
    "RunCommandsOnlyOnTaggedAgent",
    "AssumeOnlyTemporaryDriftRole",
    "VerifyPublishedImageProvenance",
  ];
  const presentSids = new Set(statements.map(({ Sid }) => Sid));
  const violations = prohibitedActions.filter((action) => allowedActions.includes(action));
  const missingSids = requiredSids.filter((sid) => !presentSids.has(sid));
  const taggedAgent = statements.find(({ Sid }) => Sid === "RunCommandsOnlyOnTaggedAgent");
  const validAgentScope =
    taggedAgent?.Resource === "arn:aws:ec2:ap-southeast-3:557947229844:instance/*" &&
    taggedAgent?.Condition?.StringLike?.["ssm:resourceTag/ExperimentId"] === "campaign-*";
  if (violations.length || missingSids.length || !validAgentScope) {
    throw new Error(JSON.stringify({ violations, missingSids, validAgentScope }, null, 2));
  }
  fs.writeFileSync(
    path.join(outputDirectory, "policy-structure.json"),
    `${JSON.stringify(
      {
        status: "passed",
        validationMode,
        roleArn,
        requiredStatements: requiredSids.length,
        prohibitedActions: prohibitedActions.length,
        validAgentScope,
      },
      null,
      2,
    )}\n`,
  );
  process.exit(0);
}

if (validationMode !== "simulate") {
  throw new Error(`Unsupported validation mode: ${validationMode}`);
}

function runAws(args) {
  const result = spawnSync(aws, args, { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(result.stderr || `AWS CLI exited with ${result.status}`);
  }
  return JSON.parse(result.stdout);
}

function assertSimulation(expected, actionNames, resourceArns, contextEntries = []) {
  const result = runAws([
    "iam",
    "simulate-principal-policy",
    "--policy-source-arn",
    roleArn,
    "--action-names",
    ...actionNames,
    "--resource-arns",
    ...resourceArns,
    ...(contextEntries.length > 0 ? ["--context-entries", ...contextEntries] : []),
    "--output",
    "json",
  ]);
  const unexpected = result.EvaluationResults.filter(
    ({ EvalDecision }) => EvalDecision !== expected,
  );
  if (unexpected.length > 0) {
    throw new Error(
      `Expected ${expected}: ${JSON.stringify(
        unexpected.map(({ EvalActionName, EvalDecision }) => ({
          action: EvalActionName,
          decision: EvalDecision,
        })),
      )}`,
    );
  }
}

const findings = runAws([
  "accessanalyzer",
  "validate-policy",
  "--policy-document",
  "file://bootstrap/github-oidc/experiment-evidence-policy.json",
  "--policy-type",
  "IDENTITY_POLICY",
  "--output",
  "json",
]);
fs.writeFileSync(
  path.join(outputDirectory, "policy-findings.json"),
  `${JSON.stringify(findings, null, 2)}\n`,
);
if (findings.findings.some(({ findingType }) => findingType !== "SUGGESTION")) {
  throw new Error("IAM Access Analyzer returned a non-suggestion finding");
}

assertSimulation(
  "allowed",
  ["s3:GetBucketLocation", "s3:ListBucket"],
  ["arn:aws:s3:::eepistore-dev-terraform-state"],
);
assertSimulation(
  "allowed",
  ["sts:AssumeRole"],
  [`arn:aws:iam::${accountId}:role/eepistore-experiment-drift-role`],
);
assertSimulation(
  "allowed",
  ["s3:GetObject"],
  ["arn:aws:s3:::eepistore-dev-terraform-state/eepistore/dev/terraform.tfstate"],
);
assertSimulation(
  "allowed",
  ["kms:Decrypt", "kms:DescribeKey"],
  [`arn:aws:kms:${region}:${accountId}:key/fd2250a6-ed79-4f87-8c18-1d6e14df8e84`],
);
assertSimulation(
  "allowed",
  ["ecs:RunTask"],
  [`arn:aws:ecs:${region}:${accountId}:task-definition/eepistore-task:1`],
  [`ContextKeyName=ecs:cluster,ContextKeyValues=${clusterArn},ContextKeyType=string`],
);
assertSimulation(
  "allowed",
  ["iam:PassRole"],
  [`arn:aws:iam::${accountId}:role/eepistore-ecs-task-example`],
  [
    "ContextKeyName=iam:PassedToService,ContextKeyValues=ecs-tasks.amazonaws.com,ContextKeyType=string",
  ],
);
assertSimulation(
  "allowed",
  ["ecr:DescribeImages", "ecr:DescribeRepositories"],
  [`arn:aws:ecr:${region}:${accountId}:repository/eepistore-repo`],
);
assertSimulation(
  "allowed",
  ["s3:DeleteObject"],
  ["arn:aws:s3:::eepistore-dev-public-media-example/products/experiment-user/image.png"],
);
assertSimulation(
  "allowed",
  ["ssm:SendCommand"],
  ["arn:aws:ssm:ap-southeast-3::document/AWS-RunShellScript"],
);
assertSimulation(
  "allowed",
  ["ssm:SendCommand"],
  [`arn:aws:ec2:${region}:${accountId}:instance/i-0123456789abcdef0`],
  [
    "ContextKeyName=ssm:resourceTag/ExperimentId,ContextKeyValues=campaign-20260804-aaaaaaa-bbbbbbb,ContextKeyType=string",
  ],
);

const deniedActions = [
  "iam:CreateRole",
  "iam:PutRolePolicy",
  "ecs:RegisterTaskDefinition",
  "ecs:UpdateService",
  "ec2:TerminateInstances",
  "rds:DeleteDBInstance",
  "s3:DeleteBucket",
  "secretsmanager:PutSecretValue",
  "cloudformation:CreateStack",
  "ssm:CreateDocument",
  "ssm:DeleteDocument",
  "wafv2:UpdateWebACL",
];
assertSimulation("implicitDeny", deniedActions, ["*"]);

fs.writeFileSync(
  path.join(outputDirectory, "policy-simulation.json"),
  `${JSON.stringify(
    {
      status: "passed",
      roleArn,
      allowedChecks: 10,
      deniedActions: deniedActions.length,
    },
    null,
    2,
  )}\n`,
);
