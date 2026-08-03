import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const ajv = new Ajv2020({ allErrors: true, strict: true });
addFormats(ajv);

const schemaDirectory = path.join(path.dirname(fileURLToPath(import.meta.url)), "schema");
const schemaFiles = {
  "1.0.0": "experiment-evidence.schema.json",
  "2.0.0": "experiment-evidence-2.0.0.schema.json",
};
const validators = new Map(
  Object.entries(schemaFiles).map(([version, file]) => {
    const schema = JSON.parse(fs.readFileSync(path.join(schemaDirectory, file), "utf8"));
    return [version, ajv.compile(schema)];
  }),
);

export function validateEvidence(value) {
  const validate = validators.get(value?.schemaVersion);
  if (!validate) {
    throw new Error(`Unsupported evidence schema version: ${value?.schemaVersion ?? "missing"}`);
  }
  if (!validate(value)) {
    const details = ajv.errorsText(validate.errors, { separator: "\n" });
    throw new Error(`Evidence schema validation failed:\n${details}`);
  }
  return value;
}
