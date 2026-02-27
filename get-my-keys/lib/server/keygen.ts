import crypto from "node:crypto";

import { KEY_PREFIX } from "../shared/constants";

export function buildKey(input: { sub: string; email: string; salt: string }): string {
  const raw = `${input.sub}:${input.email}:${input.salt}`;
  const compactHash = crypto.createHash("sha256").update(raw).digest("base64url");

  return `${KEY_PREFIX}${compactHash}-${input.email}`;
}
