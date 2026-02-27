import { beforeEach, describe, expect, it, vi } from "vitest";

const readFileMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/shared/constants", () => ({
  AGENT_LAUNCHER_FILE_PATH: "/opt/onekey/agent-launcher.sh",
}));

vi.mock("node:fs/promises", () => ({
  readFile: readFileMock,
}));

import { GET } from "../../app/api/agent-launcher/route";

describe("GET /api/agent-launcher", () => {
  beforeEach(() => {
    readFileMock.mockReset();
  });

  it("returns launcher file as attachment", async () => {
    readFileMock.mockResolvedValue(Buffer.from("#!/bin/bash\necho launch", "utf8"));

    const response = await GET();

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("application/octet-stream");
    expect(response.headers.get("content-disposition")).toBe(
      'attachment; filename="agent-launcher.sh"',
    );
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(readFileMock).toHaveBeenCalledWith("/opt/onekey/agent-launcher.sh");

    const content = Buffer.from(await response.arrayBuffer()).toString("utf8");
    expect(content).toBe("#!/bin/bash\necho launch");
  });

  it("returns 404 when launcher file does not exist", async () => {
    const noEntryError = new Error("ENOENT");
    (noEntryError as NodeJS.ErrnoException).code = "ENOENT";
    readFileMock.mockRejectedValue(noEntryError);

    const response = await GET();

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "LAUNCHER_FILE_NOT_FOUND",
        message: "LAUNCHER_FILE_NOT_FOUND: file not found",
      },
    });
  });
});
