import { NextResponse } from "next/server";

import { KEY_SALT } from "@/lib/shared/constants";
import { maskKey } from "@/lib/shared/mask-key";
import { ensureSupportedEmail } from "@/lib/server/authz-email";
import { buildKey } from "@/lib/server/keygen";
import { AppError, isAppError } from "@/lib/server/errors";
import { verifyGoogleToken } from "@/lib/server/google-auth";

export const runtime = "nodejs";

export async function POST(request: Request): Promise<Response> {
  try {
    const body = (await request.json().catch(() => ({}))) as { token?: unknown };

    if (typeof body.token !== "string" || body.token.trim().length === 0) {
      throw new AppError("BAD_REQUEST", "token is required", 400);
    }

    const identity = await verifyGoogleToken(body.token);
    ensureSupportedEmail(identity.email, identity.emailVerified);

    const key = buildKey({
      sub: identity.sub,
      email: identity.email,
      salt: KEY_SALT,
    });

    return NextResponse.json({
      key,
      maskedKey: maskKey(key),
      profile: {
        sub: identity.sub,
        email: identity.email,
      },
    });
  } catch (error) {
    if (isAppError(error)) {
      return NextResponse.json(
        {
          error: {
            code: error.code,
            message: error.message,
          },
        },
        { status: error.status },
      );
    }

    return NextResponse.json(
      {
        error: {
          code: "INTERNAL_ERROR",
          message: "INTERNAL_ERROR",
        },
      },
      { status: 500 },
    );
  }
}
