import path from "node:path";
import { execFile } from "node:child_process";
import { appendFile, mkdir, open, readFile, rename, rm, writeFile } from "node:fs/promises";
import type { FileHandle } from "node:fs/promises";
import { promisify } from "node:util";

import {
  KEY_PERSIST_FILE_PATH,
  KEY_PERSIST_LOG_FILE_PATH,
  KEY_SYNC_YAML_FILE_PATH,
} from "../shared/constants";

const LOCK_RETRY_INTERVAL_MS = 20;
const LOCK_RETRY_LIMIT = 250;
const execFileAsync = promisify(execFile);
const RESTART_CLIPROXYAPI_SCRIPT =
  "if command -v systemctl >/dev/null 2>&1; then systemctl --user restart cliproxyapi.service; fi";

type PersistGeneratedKeyInput = {
  key: string;
  keyFilePath?: string;
  syncYamlPath?: string;
  logFilePath?: string;
};

export async function persistGeneratedKey(input: PersistGeneratedKeyInput): Promise<void> {
  const keyFilePath = resolveRuntimePath(input.keyFilePath ?? KEY_PERSIST_FILE_PATH);
  const syncYamlPath = resolveOptionalPath(input.syncYamlPath ?? KEY_SYNC_YAML_FILE_PATH);
  const configuredLogFilePath = resolveOptionalPath(
    input.logFilePath ?? KEY_PERSIST_LOG_FILE_PATH,
  );
  const logFilePath = configuredLogFilePath ?? `${keyFilePath}.log`;

  await withFileLock(`${keyFilePath}.lock`, async () => {
    const existingKeys = await readDedupedLines(keyFilePath);
    const expectedKeys = dedupeValues([...existingKeys, input.key]);

    await writeLinesAtomically(keyFilePath, expectedKeys);

    const persistedKeys = await readDedupedLines(keyFilePath);
    if (!isSameStringArray(expectedKeys, persistedKeys)) {
      throw new Error("PERSISTED_KEY_MISMATCH");
    }

    if (!syncYamlPath) {
      return;
    }

    await syncApiKeysYamlIfExists({
      yamlFilePath: syncYamlPath,
      persistedKeys,
      logFilePath,
    });
  });
}

async function syncApiKeysYamlIfExists(input: {
  yamlFilePath: string;
  persistedKeys: string[];
  logFilePath: string;
}): Promise<void> {
  const yamlSource = await readFileIfExists(input.yamlFilePath);
  if (yamlSource === null) {
    return;
  }

  const existingYamlKeys = parseYamlApiKeys(yamlSource).values;
  const dedupedYamlKeys = dedupeValues(existingYamlKeys);
  const cleanedYamlKeys = dedupedYamlKeys.filter((value) => !value.includes("@onekey.so"));
  const expectedYamlKeys = dedupeValues([...cleanedYamlKeys, ...input.persistedKeys]);
  const nextYaml = replaceYamlApiKeys(yamlSource, expectedYamlKeys);
  if (nextYaml === yamlSource) {
    return;
  }

  await writeTextAtomically(input.yamlFilePath, nextYaml);

  const savedYaml = await readFile(input.yamlFilePath, "utf8");
  const savedKeys = dedupeValues(parseYamlApiKeys(savedYaml).values);
  if (!isSameStringArray(savedKeys, expectedYamlKeys)) {
    throw new Error("SYNC_YAML_MISMATCH");
  }

  await restartCliproxyApiServiceIfAvailable(input.logFilePath);
}

async function restartCliproxyApiServiceIfAvailable(logFilePath: string): Promise<void> {
  await appendRuntimeLog(
    logFilePath,
    "INFO",
    "running restart command: systemctl --user restart cliproxyapi.service",
  );

  try {
    await execFileAsync("bash", ["-lc", RESTART_CLIPROXYAPI_SCRIPT]);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await appendRuntimeLog(logFilePath, "ERROR", `cliproxyapi restart failed: ${message}`);
  }
}

async function appendRuntimeLog(
  logFilePath: string,
  level: "INFO" | "ERROR",
  message: string,
): Promise<void> {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] [${level}] ${message}\n`;

  try {
    await mkdir(path.dirname(logFilePath), { recursive: true });
    await appendFile(logFilePath, line, "utf8");
  } catch (error) {
    const fallback = error instanceof Error ? error.message : String(error);
    console.error(`failed to write runtime log file ${logFilePath}: ${fallback}`);
  }
}

function replaceYamlApiKeys(yamlSource: string, apiKeys: string[]): string {
  const eol = yamlSource.includes("\r\n") ? "\r\n" : "\n";
  const hadTrailingEol = yamlSource.endsWith("\n") || yamlSource.endsWith("\r\n");
  const lines = splitTextLines(yamlSource);
  const section = parseYamlApiKeys(yamlSource);

  const apiKeysIndent = section.startIndex >= 0 ? section.indent : "";
  const apiKeysBlock = [
    `${apiKeysIndent}api-keys:`,
    ...apiKeys.map((value) => `${apiKeysIndent}  - ${value}`),
  ];

  const mergedLines =
    section.startIndex < 0
      ? [...lines, ...apiKeysBlock]
      : [
          ...lines.slice(0, section.startIndex),
          ...apiKeysBlock,
          ...lines.slice(section.endIndex),
        ];

  const body = mergedLines.join(eol);
  return hadTrailingEol || body.length > 0 ? `${body}${eol}` : body;
}

function parseYamlApiKeys(yamlSource: string): {
  startIndex: number;
  endIndex: number;
  indent: string;
  values: string[];
} {
  const lines = splitTextLines(yamlSource);
  const startIndex = lines.findIndex((line) => /^(\s*)api-keys:\s*$/.test(line));

  if (startIndex < 0) {
    return {
      startIndex: -1,
      endIndex: -1,
      indent: "",
      values: [],
    };
  }

  const indent = lines[startIndex].match(/^(\s*)/)?.[1] ?? "";
  let endIndex = startIndex + 1;

  while (endIndex < lines.length) {
    const line = lines[endIndex];
    if (line.trim().length === 0) {
      endIndex += 1;
      continue;
    }

    const currentIndent = line.match(/^(\s*)/)?.[1]?.length ?? 0;
    if (currentIndent <= indent.length) {
      break;
    }

    endIndex += 1;
  }

  const values = lines.slice(startIndex + 1, endIndex).flatMap((line) => {
    const match = line.match(/^\s*-\s*(.+?)\s*$/);
    if (!match) {
      return [];
    }

    const value = stripYamlScalarWrapping(match[1].trim());
    return value.length > 0 ? [value] : [];
  });

  return {
    startIndex,
    endIndex,
    indent,
    values,
  };
}

function stripYamlScalarWrapping(value: string): string {
  if (
    (value.startsWith("\"") && value.endsWith("\"")) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }

  return value;
}

function splitTextLines(text: string): string[] {
  if (text.length === 0) {
    return [];
  }

  return text.replace(/\r\n/g, "\n").replace(/\n$/, "").split("\n");
}

async function withFileLock<T>(lockFilePath: string, task: () => Promise<T>): Promise<T> {
  await mkdir(path.dirname(lockFilePath), { recursive: true });

  let lockHandle: FileHandle | null = null;

  for (let retry = 0; retry < LOCK_RETRY_LIMIT; retry += 1) {
    try {
      lockHandle = await open(lockFilePath, "wx");
      break;
    } catch (error) {
      if (isNodeErrorCode(error, "EEXIST")) {
        await sleep(LOCK_RETRY_INTERVAL_MS);
        continue;
      }

      throw error;
    }
  }

  if (!lockHandle) {
    throw new Error(`LOCK_TIMEOUT: ${lockFilePath}`);
  }

  try {
    return await task();
  } finally {
    await lockHandle.close();
    await rm(lockFilePath, { force: true });
  }
}

async function readDedupedLines(filePath: string): Promise<string[]> {
  const content = await readFileIfExists(filePath);
  if (content === null) {
    return [];
  }

  const values = content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  return dedupeValues(values);
}

async function writeLinesAtomically(filePath: string, lines: string[]): Promise<void> {
  const nextText = lines.length > 0 ? `${lines.join("\n")}\n` : "";
  await writeTextAtomically(filePath, nextText);
}

async function writeTextAtomically(filePath: string, content: string): Promise<void> {
  const dir = path.dirname(filePath);
  await mkdir(dir, { recursive: true });

  const tempFilePath = `${filePath}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(tempFilePath, content, "utf8");
  await rename(tempFilePath, filePath);
}

async function readFileIfExists(filePath: string): Promise<string | null> {
  try {
    return await readFile(filePath, "utf8");
  } catch (error) {
    if (isNodeErrorCode(error, "ENOENT")) {
      return null;
    }

    throw error;
  }
}

function resolveRuntimePath(filePath: string): string {
  return path.isAbsolute(filePath) ? filePath : path.resolve(process.cwd(), filePath);
}

function resolveOptionalPath(filePath: string): string | null {
  const normalized = filePath.trim();
  if (normalized.length === 0) {
    return null;
  }

  return resolveRuntimePath(normalized);
}

function dedupeValues(values: string[]): string[] {
  const seen = new Set<string>();
  const output: string[] = [];

  for (const value of values) {
    if (seen.has(value)) {
      continue;
    }

    seen.add(value);
    output.push(value);
  }

  return output;
}

function isSameStringArray(left: string[], right: string[]): boolean {
  if (left.length !== right.length) {
    return false;
  }

  return left.every((value, index) => value === right[index]);
}

function isNodeErrorCode(error: unknown, code: string): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === code
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
