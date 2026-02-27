import { describe, expect, it } from "vitest";

import { buildKey } from "../../lib/server/keygen";

describe("buildKey", () => {
  it("generates deterministic compact base64url-like key with prefix and email suffix", () => {
    const key = buildKey({
      sub: "google-sub-123",
      email: "alice@onekey.so",
      salt: "my-fixed-salt",
    });

    expect(key).toBe("1k-kqqLZ63_IBK8JcKFAmlcXQ-GEStIgMzjRakfMuxfuks-alice@onekey.so");
  });

  it("changes output when any input field changes", () => {
    const base = buildKey({
      sub: "sub-a",
      email: "alice@onekey.so",
      salt: "salt-a",
    });

    expect(
      buildKey({ sub: "sub-b", email: "alice@onekey.so", salt: "salt-a" }),
    ).not.toBe(base);
    expect(
      buildKey({ sub: "sub-a", email: "bob@onekey.so", salt: "salt-a" }),
    ).not.toBe(base);
    expect(
      buildKey({ sub: "sub-a", email: "alice@onekey.so", salt: "salt-b" }),
    ).not.toBe(base);
  });
});
