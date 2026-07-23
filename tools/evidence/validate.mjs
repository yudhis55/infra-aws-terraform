import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const schemaPath = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "schema",
  "experiment-evidence.schema.json",
);
const schema = JSON.parse(fs.readFileSync(schemaPath, "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: true });
addFormats(ajv);
const validate = ajv.compile(schema);

export function validateEvidence(value) {
  if (!validate(value)) {
    const details = ajv.errorsText(validate.errors, { separator: "\n" });
    throw new Error(`Evidence schema validation failed:\n${details}`);
  }
  return value;
}
