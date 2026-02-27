import { beforeEach, describe, expect, it, vi } from "vitest";

import { AppError } from "../../lib/server/errors";

const verifyGoogleTokenMock = vi.hoisted(() => vi.fn());
const ensureSupportedEmailMock = vi.hoisted(() => vi.fn());

vi.mock("../../lib/server/google-auth", () => ({
  verifyGoogleToken: verifyGoogleTokenMock,
}));

vi.mock("../../lib/server/authz-email", () => ({
  ensureSupportedEmail: ensureSupportedEmailMock,
}));

import { POST } from "../../app/api/key/route";

describe("POST /api/key", () => {
  beforeEach(() => {
    verifyGoogleTokenMock.mockReset();
    ensureSupportedEmailMock.mockReset();
  });

  it("returns 400 when token is missing", async () => {
    const response = await POST(
      new Request("http://localhost/api/key", {
        method: "POST",
        body: JSON.stringify({}),
      }),
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "BAD_REQUEST",
        message: "token is required",
      },
    });
  });

  it("returns 401 when Google token is invalid", async () => {
    verifyGoogleTokenMock.mockRejectedValue(
      new AppError("INVALID_GOOGLE_TOKEN", "INVALID_GOOGLE_TOKEN", 401),
    );

    const response = await POST(
      new Request("http://localhost/api/key", {
        method: "POST",
        body: JSON.stringify({ token: "invalid-token" }),
      }),
    );

    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "INVALID_GOOGLE_TOKEN",
        message: "INVALID_GOOGLE_TOKEN",
      },
    });
  });

  it("returns 422 when required claims are missing", async () => {
    verifyGoogleTokenMock.mockRejectedValue(
      new AppError("INVALID_TOKEN_CLAIMS", "INVALID_TOKEN_CLAIMS", 422),
    );

    const response = await POST(
      new Request("http://localhost/api/key", {
        method: "POST",
        body: JSON.stringify({ token: "token" }),
      }),
    );

    expect(response.status).toBe(422);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "INVALID_TOKEN_CLAIMS",
        message: "INVALID_TOKEN_CLAIMS",
      },
    });
  });

  it("returns 403 when email domain is unsupported", async () => {
    verifyGoogleTokenMock.mockResolvedValue({
      sub: "sub-1",
      email: "user@gmail.com",
      emailVerified: true,
    });
    ensureSupportedEmailMock.mockImplementation(() => {
      throw new AppError(
        "UNSUPPORTED_EMAIL_DOMAIN",
        "UNSUPPORTED_EMAIL_DOMAIN: 不支持该邮箱",
        403,
      );
    });

    const response = await POST(
      new Request("http://localhost/api/key", {
        method: "POST",
        body: JSON.stringify({ token: "valid-token" }),
      }),
    );

    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "UNSUPPORTED_EMAIL_DOMAIN",
        message: "UNSUPPORTED_EMAIL_DOMAIN: 不支持该邮箱",
      },
    });
  });

  it("returns computed key and masked key on success", async () => {
    verifyGoogleTokenMock.mockResolvedValue({
      sub: "sub-123",
      email: "alice@onekey.so",
      emailVerified: true,
    });

    const response = await POST(
      new Request("http://localhost/api/key", {
        method: "POST",
        body: JSON.stringify({ token: "valid-token" }),
      }),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      key: "1k-KJ4eTuzOyRZ4KPiuWNBQbI_bokLBnqXhcnnHDfQoP5Q-alice@onekey.so",
      maskedKey: "1k-KJ4****************************************************y.so",
      profile: {
        sub: "sub-123",
        email: "alice@onekey.so",
      },
    });

    expect(ensureSupportedEmailMock).toHaveBeenCalledWith("alice@onekey.so", true);
  });
});
