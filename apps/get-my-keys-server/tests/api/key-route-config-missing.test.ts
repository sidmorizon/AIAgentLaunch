import { describe, expect, it, vi } from "vitest";

const verifyGoogleTokenMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/shared/constants", () => ({
  NEXT_BASE_PATH: "/get-my-keys",
  KEY_API_PATH: "/get-my-keys/api/key",
  COPY_FEEDBACK_MS: 1500,
  GOOGLE_OAUTH_CLIENT_ID: "test-google-client-id",
  KEY_SALT: "",
  KEY_PREFIX: "1k-",
  ALLOWED_EMAIL_SUFFIX: "@onekey.so",
  KEY_PERSIST_FILE_PATH: "data/get-my-keys/generated-keys.txt",
  KEY_SYNC_YAML_FILE_PATH: "data/get-my-keys/router-config.yaml",
}));

vi.mock("../../lib/server/google-auth", () => ({
  verifyGoogleToken: verifyGoogleTokenMock,
}));

import { POST } from "../../app/api/key/route";

describe("POST /api/key missing env", () => {
  it("returns SERVER_CONFIG_MISSING when KEY_SALT is absent", async () => {
    const response = await POST(
      new Request("http://localhost/api/key", {
        method: "POST",
        body: JSON.stringify({ token: "valid-token" }),
      }),
    );

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "SERVER_CONFIG_MISSING",
        message: "SERVER_CONFIG_MISSING: missing KEY_SALT",
      },
    });

    expect(verifyGoogleTokenMock).not.toHaveBeenCalled();
  });
});
