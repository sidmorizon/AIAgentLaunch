import { describe, expect, it, vi } from "vitest";

const readFileMock = vi.hoisted(() => vi.fn());
const remoteLauncherUrl = vi.hoisted(() => "https://cdn.example.com/agent-launcher.sh");

vi.mock("@/lib/shared/constants", () => ({
  AGENT_LAUNCHER_FILE_PATH: remoteLauncherUrl,
}));

vi.mock("node:fs/promises", () => ({
  readFile: readFileMock,
}));

import { GET } from "../../app/api/agent-launcher/route";

describe("GET /api/agent-launcher remote URL", () => {
  it("redirects to remote launcher URL without reading local file", async () => {
    const response = await GET();

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(remoteLauncherUrl);
    expect(readFileMock).not.toHaveBeenCalled();
  });
});
