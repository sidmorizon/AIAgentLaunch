import { readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

describe("server startup script", () => {
  it("contains git pull, rebuild, and service start steps in order", () => {
    const scriptPath = path.resolve(process.cwd(), "scripts/server-start.sh");
    const script = readFileSync(scriptPath, "utf-8");

    const gitPullIndex = script.indexOf("git pull --ff-only");
    const installIndex = script.indexOf("npm ci");
    const buildIndex = script.indexOf("npm run build");
    const startIndex = script.indexOf("npm run start");

    expect(script).toContain('PORT="${PORT:-3721}"');
    expect(gitPullIndex).toBeGreaterThan(-1);
    expect(installIndex).toBeGreaterThan(gitPullIndex);
    expect(buildIndex).toBeGreaterThan(installIndex);
    expect(startIndex).toBeGreaterThan(buildIndex);
  });
});
