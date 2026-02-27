import path from "node:path";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const execFileMock = vi.hoisted(() => vi.fn());

vi.mock("node:child_process", () => ({
  execFile: execFileMock,
}));

import { persistGeneratedKey } from "../../lib/server/key-persistence";

describe("persistGeneratedKey", () => {
  beforeEach(() => {
    execFileMock.mockReset();
    execFileMock.mockImplementation(
      (
        _command: string,
        _args: string[],
        callback: (error: Error | null, stdout: string, stderr: string) => void,
      ) => {
        callback(null, "", "");
      },
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

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
    const logFilePath = path.join(baseDir, "restart.log");

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

    await persistGeneratedKey({
      key: "1k-new-a@onekey.so",
      keyFilePath,
      syncYamlPath: yamlPath,
      logFilePath,
    });
    await persistGeneratedKey({
      key: "1k-new-a@onekey.so",
      keyFilePath,
      syncYamlPath: yamlPath,
      logFilePath,
    });
    await persistGeneratedKey({
      key: "1k-new-b@onekey.so",
      keyFilePath,
      syncYamlPath: yamlPath,
      logFilePath,
    });

    const yamlContent = await readFile(yamlPath, "utf8");

    expect(yamlContent).toContain("ws-auth: false");
    expect(yamlContent).toContain("nonstream-keepalive-interval: 0");
    expect(yamlContent).toContain("api-keys:");
    expect(yamlContent).toContain("  - keep-me");
    expect(yamlContent).toContain("  - 1k-new-a@onekey.so");
    expect(yamlContent).toContain("  - 1k-new-b@onekey.so");
    expect(yamlContent).not.toContain("old@onekey.so");
    expect(yamlContent).not.toContain("old2@onekey.so");
    expect(execFileMock).toHaveBeenCalledWith(
      "bash",
      [
        "-lc",
        "if command -v systemctl >/dev/null 2>&1; then systemctl restart onekey-cliproxyapi.service; fi",
      ],
      expect.any(Function),
    );

    const logContent = await readFile(logFilePath, "utf8");
    expect(logContent).toContain("running restart command: systemctl restart onekey-cliproxyapi.service");
  });

  it("does not restart service when yaml content has no effective change", async () => {
    const baseDir = await mkdtemp(path.join(tmpdir(), "get-my-keys-yaml-nochange-"));
    const keyFilePath = path.join(baseDir, "keys.txt");
    const yamlPath = path.join(baseDir, "config.yaml");
    const logFilePath = path.join(baseDir, "restart.log");

    await writeFile(
      yamlPath,
      [
        "api-keys:",
        "  - keep-me",
        "  - 1k-stable@onekey.so",
      ].join("\n") + "\n",
      "utf8",
    );

    await persistGeneratedKey({
      key: "1k-stable@onekey.so",
      keyFilePath,
      syncYamlPath: yamlPath,
      logFilePath,
    });

    expect(execFileMock).not.toHaveBeenCalled();
    await expect(readFile(logFilePath, "utf8")).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("does not fail key persistence when service restart command fails", async () => {
    const baseDir = await mkdtemp(path.join(tmpdir(), "get-my-keys-yaml-restart-fail-"));
    const keyFilePath = path.join(baseDir, "keys.txt");
    const yamlPath = path.join(baseDir, "config.yaml");
    const logFilePath = path.join(baseDir, "restart.log");

    execFileMock.mockImplementationOnce(
      (
        _command: string,
        _args: string[],
        callback: (error: Error | null, stdout: string, stderr: string) => void,
      ) => {
        callback(new Error("restart failed"), "", "restart failed");
      },
    );

    await writeFile(
      yamlPath,
      [
        "api-keys:",
        "  - old@onekey.so",
      ].join("\n") + "\n",
      "utf8",
    );

    await expect(
      persistGeneratedKey({ key: "1k-fresh@onekey.so", keyFilePath, syncYamlPath: yamlPath, logFilePath }),
    ).resolves.toBeUndefined();

    const yamlContent = await readFile(yamlPath, "utf8");
    expect(yamlContent).toContain("  - 1k-fresh@onekey.so");
    expect(yamlContent).not.toContain("old@onekey.so");

    const logContent = await readFile(logFilePath, "utf8");
    expect(logContent).toContain("running restart command: systemctl restart onekey-cliproxyapi.service");
    expect(logContent).toContain("cliproxyapi restart failed: restart failed");
  });
});
