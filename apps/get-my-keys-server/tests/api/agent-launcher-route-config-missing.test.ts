import { describe, expect, it, vi } from "vitest";

const readFileMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/shared/constants", () => ({
  AGENT_LAUNCHER_FILE_PATH: "",
}));

vi.mock("node:fs/promises", () => ({
  readFile: readFileMock,
}));

import { GET } from "../../app/api/agent-launcher/route";

describe("GET /api/agent-launcher missing env", () => {
  it("returns SERVER_CONFIG_MISSING when AGENT_LAUNCHER_FILE_PATH is absent", async () => {
    const response = await GET();

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "SERVER_CONFIG_MISSING",
        message: "SERVER_CONFIG_MISSING: missing AGENT_LAUNCHER_FILE_PATH",
      },
    });
    expect(readFileMock).not.toHaveBeenCalled();
  });
});
