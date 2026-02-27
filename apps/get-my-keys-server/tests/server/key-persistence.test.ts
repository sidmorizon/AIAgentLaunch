import path from "node:path";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";

import { describe, expect, it } from "vitest";

import { persistGeneratedKey } from "../../lib/server/key-persistence";

describe("persistGeneratedKey", () => {
  it("deduplicates persisted keys and verifies saved content", async () => {
    const baseDir = await mkdtemp(path.join(tmpdir(), "get-my-keys-store-"));
    const keyFilePath = path.join(baseDir, "keys.txt");

    await persistGeneratedKey({
      key: "1k-aaa@onekey.so",
      keyFilePath,
      syncYamlPath: path.join(baseDir, "missing.yaml"),
    });
    await persistGeneratedKey({
      key: "1k-aaa@onekey.so",
      keyFilePath,
      syncYamlPath: path.join(baseDir, "missing.yaml"),
    });

    const content = await readFile(keyFilePath, "utf8");
    expect(content).toBe("1k-aaa@onekey.so\n");
  });

  it("serializes concurrent writes and keeps unique keys", async () => {
    const baseDir = await mkdtemp(path.join(tmpdir(), "get-my-keys-concurrent-"));
    const keyFilePath = path.join(baseDir, "keys.txt");

    await Promise.all([
      persistGeneratedKey({ key: "1k-a@onekey.so", keyFilePath }),
      persistGeneratedKey({ key: "1k-b@onekey.so", keyFilePath }),
      persistGeneratedKey({ key: "1k-a@onekey.so", keyFilePath }),
      persistGeneratedKey({ key: "1k-c@onekey.so", keyFilePath }),
      persistGeneratedKey({ key: "1k-b@onekey.so", keyFilePath }),
    ]);

    const content = await readFile(keyFilePath, "utf8");
    const values = content
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);

    expect(new Set(values)).toEqual(
      new Set(["1k-a@onekey.so", "1k-b@onekey.so", "1k-c@onekey.so"]),
    );
    expect(values).toHaveLength(3);
  });

  it("rewrites yaml api-keys by removing @onekey.so entries and syncing from key file", async () => {
    const baseDir = await mkdtemp(path.join(tmpdir(), "get-my-keys-yaml-"));
    const keyFilePath = path.join(baseDir, "keys.txt");
    const yamlPath = path.join(baseDir, "config.yaml");

    await writeFile(
      yamlPath,
      [
        "ws-auth: false",
        "nonstream-keepalive-interval: 0",
        "api-keys:",
        "  - keep-me",
        "  - old@onekey.so",
        "  - keep-me",
        "  - old2@onekey.so",
      ].join("\n") + "\n",
      "utf8",
    );

    await persistGeneratedKey({ key: "1k-new-a@onekey.so", keyFilePath, syncYamlPath: yamlPath });
    await persistGeneratedKey({ key: "1k-new-a@onekey.so", keyFilePath, syncYamlPath: yamlPath });
    await persistGeneratedKey({ key: "1k-new-b@onekey.so", keyFilePath, syncYamlPath: yamlPath });

    const yamlContent = await readFile(yamlPath, "utf8");

    expect(yamlContent).toContain("ws-auth: false");
    expect(yamlContent).toContain("nonstream-keepalive-interval: 0");
    expect(yamlContent).toContain("api-keys:");
    expect(yamlContent).toContain("  - keep-me");
    expect(yamlContent).toContain("  - 1k-new-a@onekey.so");
    expect(yamlContent).toContain("  - 1k-new-b@onekey.so");
    expect(yamlContent).not.toContain("old@onekey.so");
    expect(yamlContent).not.toContain("old2@onekey.so");
  });
});
