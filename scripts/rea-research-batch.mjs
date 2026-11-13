import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { Client } from "@modelcontextprotocol/client";
import {
  StdioClientTransport,
  getDefaultEnvironment,
} from "@modelcontextprotocol/client/stdio";

const binaryPath = resolve(process.argv[2] ?? "");
if (!process.argv[2]) {
  throw new Error("Usage: node scripts/rea-research-batch.mjs <arm64-binary>");
}

const outputDir = resolve("research-output");
await mkdir(outputDir, { recursive: true });

const env = Object.fromEntries(
  Object.entries({
    ...getDefaultEnvironment(),
    GHIDRA_INSTALL_DIR: process.env.GHIDRA_INSTALL_DIR,
    REA_ANALYSIS_PROVIDER: "ghidra",
    REA_GHIDRA_STARTUP_TIMEOUT_MS: "1200000",
  }).filter(([, value]) => typeof value === "string"),
);

const client = new Client({ name: "cham-rea-final-research", version: "1.0.0" });
const transport = new StdioClientTransport({
  command: "rea",
  args: ["mcp"],
  env,
});

const save = async (name, value) => {
  await writeFile(
    resolve(outputDir, name),
    `${JSON.stringify(value, null, 2)}\n`,
    "utf8",
  );
};

const call = async (name, args, timeout = 1_500_000, outputName = null) => {
  const result = await client.callTool(
    { name, arguments: args },
    { timeout },
  );
  await save(outputName ?? `${name.replaceAll("_", "-")}.json`, result);
  if (result.isError) {
    throw new Error(`REA MCP ${name} failed: ${JSON.stringify(result.content)}`);
  }
  return result;
};

const knownTargets = [
  // Touch primitive and wrappers.
  "0x9a5c", "0x9a74", "0x9a8c",
  // Tap entry points and known callbacks/helpers.
  "0xb608", "0xba18", "0xbbec", "0xbc90", "0xbdc4",
  "0xbf34", "0xc02c", "0xc18c", "0xc444", "0xc490",
  "0xc628", "0xc944", "0xc96c", "0xc990", "0xc99c",
  "0xcecc", "0xd028", "0x1044c",
  // Touch/HID helpers and timing/eligibility helpers.
  "0xa28c", "0xa464", "0xa9d8", "0x9698", "0x93b8",
  "0x8238", "0x5f30",
];

const featureQueries = [
  "record", "replay", "OCR", "Vision", "HUMAN", "EXTREME",
  "ULTRA", "HOLD", "multiTouch", "fakeTouch", "normalTap",
  "doubleTap", "smartTap",
];

try {
  await client.connect(transport, { timeout: 30_000 });
  const catalog = await client.listTools({}, { timeout: 30_000 });
  await save("mcp-tool-catalog.json", catalog);

  const available = new Set(catalog.tools.map(({ name }) => name));
  for (const required of [
    "open_binary", "binary_overview", "batch_decompile", "trace_feature",
  ]) {
    if (!available.has(required)) {
      throw new Error(`REA MCP server does not advertise required tool: ${required}`);
    }
  }

  await call("open_binary", {
    path: binaryPath,
    provider_id: "ghidra",
  });
  await call("binary_overview", {});

  // Discover feature strings and their referencing procedures in this same
  // imported Ghidra Program. Save each trace separately for auditability.
  const discoveredTargets = new Set(knownTargets);
  const traceSummary = [];
  for (const query of featureQueries) {
    const result = await call(
      "trace_feature",
      { query, case_sensitive: false, detail: "complete" },
      300_000,
      `trace-feature-${query.replace(/[^a-z0-9]+/gi, "-").toLowerCase()}.json`,
    );
    const normalized = result.structuredContent?.normalized_result;
    const matches = normalized?.matches ?? [];
    const references = normalized?.references ?? [];
    let added = 0;

    for (const match of matches) {
      if (match.type === "procedure" && /^0x[0-9a-f]+$/i.test(match.address ?? "")) {
        if (!discoveredTargets.has(match.address)) added++;
        discoveredTargets.add(match.address);
      }
    }
    for (const reference of references) {
      const procedure = reference.containing_procedure?.procedure;
      const address = procedure?.address;
      if (
        reference.containing_procedure?.found === true &&
        procedure?.classification?.external !== true &&
        /^0x[0-9a-f]+$/i.test(address ?? "")
      ) {
        if (!discoveredTargets.has(address)) added++;
        discoveredTargets.add(address);
      }
    }
    traceSummary.push({
      query,
      matched_items: matches.length,
      references: references.length,
      newly_added_procedures: added,
      truncated: normalized?.truncated ?? null,
      residual_unknowns: normalized?.residual_unknowns ?? [],
    });
  }

  // One final, consolidated decompilation request. Cap only protects the
  // workflow from unexpectedly broad string matches; all known targets stay.
  const targets = [...discoveredTargets].slice(0, 160);
  await call(
    "batch_decompile",
    { addresses: targets, detail: "complete" },
    2_400_000,
    "final-batch-decompile.json",
  );

  await save("final-research-summary.json", {
    target: binaryPath,
    provider: "ghidra",
    workflow: "one persistent REA MCP session; one feature-discovery pass; one final batch_decompile call",
    phase: "consolidated Touch/HID, Tap modes, Recorder/Replay, and OCR/Vision research",
    known_targets: knownTargets,
    feature_queries: featureQueries,
    trace_summary: traceSummary,
    decompile_target_count: targets.length,
    decompile_targets: targets,
    target_cap: 160,
    completed_at: new Date().toISOString(),
  });
} finally {
  await client.close();
}
