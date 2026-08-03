import fs from "node:fs";
import { pathToFileURL } from "node:url";

export function correlateNetwork(network, query) {
  const records = (query.results ?? []).map((fields) =>
    Object.fromEntries(fields.map(({ field, value }) => [field, value])),
  );
  return {
    attempts: (network.attempts ?? []).map((attempt) => {
      const match = records.find(
        (record) =>
          record.dstAddr === attempt.destinationIp &&
          Number(record.dstPort) === Number(attempt.port) &&
          record.action,
      );
      return { ...attempt, flowLogAction: match?.action ?? null, flowLogStatus: match?.logStatus ?? null };
    }),
    flowLogQueryStatus: query.status ?? "Unknown",
    flowLogRecordCount: records.length,
  };
}

function main() {
  const [networkFile, queryFile, outputFile] = process.argv.slice(2);
  if (!outputFile) throw new Error("Usage: correlate-network <network> <flow-query> <output>");
  const read = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
  fs.writeFileSync(outputFile, `${JSON.stringify(correlateNetwork(read(networkFile), read(queryFile)), null, 2)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
