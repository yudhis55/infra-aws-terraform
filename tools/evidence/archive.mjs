import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const excludedNames = new Set(["manifest.sha256", "archive-index.json"]);
const sensitivePatterns = [/\.env/i, /tfstate/i, /tfplan/i, /secret/i, /credential/i, /playwright\/\.auth/i];

export function createArchive(sourceDir, outputDir) {
  const files = listFiles(sourceDir).filter((relative) => {
    const normalized = relative.replaceAll("\\", "/");
    return !excludedNames.has(path.basename(relative)) && !sensitivePatterns.some((pattern) => pattern.test(normalized));
  });
  if (!files.includes("experiment-evidence.json")) throw new Error("Canonical evidence is required");
  fs.mkdirSync(outputDir, { recursive: true });
  const entries = files.map((relative) => {
    const source = path.join(sourceDir, relative);
    const destination = path.join(outputDir, relative);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(source, destination);
    return { path: relative.replaceAll("\\", "/"), sha256: fileDigest(source), bytes: fs.statSync(source).size };
  });
  const index = { version: "1.0.0", createdAt: new Date().toISOString(), entries };
  fs.writeFileSync(path.join(outputDir, "archive-index.json"), `${JSON.stringify(index, null, 2)}\n`);
  fs.writeFileSync(
    path.join(outputDir, "manifest.sha256"),
    `${entries.map((entry) => `${entry.sha256}  ${entry.path}`).join("\n")}\n`,
  );
  return index;
}

export function verifyArchive(directory) {
  const index = JSON.parse(fs.readFileSync(path.join(directory, "archive-index.json"), "utf8"));
  const invalid = index.entries.filter((entry) => {
    const file = path.join(directory, entry.path);
    return !fs.existsSync(file) || fileDigest(file) !== entry.sha256 || fs.statSync(file).size !== entry.bytes;
  });
  if (invalid.length) throw new Error(`Archive verification failed: ${invalid.map((entry) => entry.path).join(", ")}`);
  return index;
}

function listFiles(root, current = root) {
  return fs.readdirSync(current, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(current, entry.name);
    return entry.isDirectory() ? listFiles(root, absolute) : [path.relative(root, absolute)];
  });
}

function fileDigest(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function main() {
  const [command, source, output] = process.argv.slice(2);
  if (command === "create") createArchive(source, output);
  else if (command === "verify") verifyArchive(source);
  else throw new Error("Usage: node archive.mjs create <source> <output> | verify <archive>");
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
