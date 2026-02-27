import { describe, expect, it } from "vitest";

import { maskKey } from "../../lib/shared/mask-key";

describe("maskKey", () => {
  it("masks key as first 6 and last 4 with stars in between", () => {
    expect(maskKey("1234567890abcdef")).toBe("123456******cdef");
  });

  it("returns stars only when key is too short to mask with front/back strategy", () => {
    expect(maskKey("123456789")).toBe("*********");
  });
});
