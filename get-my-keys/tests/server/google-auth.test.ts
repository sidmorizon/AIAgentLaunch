import { beforeEach, describe, expect, it, vi } from "vitest";

const verifyIdTokenMock = vi.hoisted(() => vi.fn());

vi.mock("google-auth-library", () => ({
  OAuth2Client: class {
    verifyIdToken = verifyIdTokenMock;
  },
}));

import { ensureSupportedEmail } from "../../lib/server/authz-email";
import { verifyGoogleToken } from "../../lib/server/google-auth";
import { GOOGLE_OAUTH_CLIENT_ID } from "../../lib/shared/constants";

describe("verifyGoogleToken", () => {
  beforeEach(() => {
    verifyIdTokenMock.mockReset();
  });

  it("throws INVALID_GOOGLE_TOKEN when verification fails", async () => {
    verifyIdTokenMock.mockRejectedValue(new Error("invalid token"));

    await expect(verifyGoogleToken("bad-token")).rejects.toMatchObject({
      code: "INVALID_GOOGLE_TOKEN",
    });
  });

  it("throws INVALID_TOKEN_CLAIMS when required claims are missing", async () => {
    verifyIdTokenMock.mockResolvedValue({
      getPayload: () => ({ email: "alice@onekey.so", email_verified: true }),
    });

    await expect(verifyGoogleToken("token")).rejects.toMatchObject({
      code: "INVALID_TOKEN_CLAIMS",
    });
  });

  it("returns normalized user identity for valid token", async () => {
    verifyIdTokenMock.mockResolvedValue({
      getPayload: () => ({
        sub: "sub-123",
        email: "alice@onekey.so",
        email_verified: true,
      }),
    });

    await expect(verifyGoogleToken("valid-token")).resolves.toEqual({
      sub: "sub-123",
      email: "alice@onekey.so",
      emailVerified: true,
    });

    expect(verifyIdTokenMock).toHaveBeenCalledWith({
      idToken: "valid-token",
      audience: GOOGLE_OAUTH_CLIENT_ID,
    });
  });
});

describe("ensureSupportedEmail", () => {
  it("allows exact @onekey.so email with verified true", () => {
    expect(() => ensureSupportedEmail("alice@onekey.so", true)).not.toThrow();
  });

  it("rejects unsupported domain with clear message", () => {
    expect(() => ensureSupportedEmail("alice@gmail.com", true)).toThrowError(
      /不支持该邮箱/,
    );
  });

  it("rejects subdomain email", () => {
    expect(() => ensureSupportedEmail("alice@mail.onekey.so", true)).toThrowError(
      /UNSUPPORTED_EMAIL_DOMAIN/,
    );
  });

  it("rejects unverified email", () => {
    expect(() => ensureSupportedEmail("alice@onekey.so", false)).toThrowError(
      /EMAIL_NOT_VERIFIED/,
    );
  });
});
