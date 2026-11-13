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

const client = new Client({ name: "cham-rea-research", version: "1.0.0" });
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

const call = async (name, args, timeout = 1_500_000) => {
  const result = await client.callTool(
    { name, arguments: args },
    { timeout },
  );
  await save(`${name.replaceAll("_", "-")}.json`, result);
  if (result.isError) {
    throw new Error(`REA MCP ${name} failed: ${JSON.stringify(result.content)}`);
  }
  return result;
};

try {
  await client.connect(transport, { timeout: 30_000 });
  const catalog = await client.listTools({}, { timeout: 30_000 });
  await save("mcp-tool-catalog.json", catalog);

  const available = new Set(catalog.tools.map(({ name }) => name));
  for (const required of ["open_binary", "binary_overview", "batch_decompile"]) {
    if (!available.has(required)) {
      throw new Error(`REA MCP server does not advertise required tool: ${required}`);
    }
  }

  await call("open_binary", {
    path: binaryPath,
    provider_id: "ghidra",
  });
  await call("binary_overview", {});
  await call(
    "batch_decompile",
    {
      addresses: ["0x9a5c", "0x9a74", "0x9a8c", "0xba18", "0xbdc4", "0xcecc"],
      detail: "complete",
    },
    1_500_000,
  );

  await save("mcp-session-summary.json", {
    target: binaryPath,
    provider: "ghidra",
    workflow: "one persistent REA MCP session; one batch_decompile call",
    addresses: ["0x9a5c", "0x9a74", "0x9a8c", "0xba18", "0xbdc4", "0xcecc"],
    completed_at: new Date().toISOString(),
  });
} finally {
  await client.close();
}
