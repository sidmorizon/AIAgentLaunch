import { NextResponse } from "next/server";

import {
  ALLOWED_EMAIL_SUFFIX,
  GOOGLE_OAUTH_CLIENT_ID,
  KEY_PERSIST_FILE_PATH,
  KEY_PREFIX,
  KEY_SALT,
  KEY_SYNC_YAML_FILE_PATH,
} from "@/lib/shared/constants";
import { maskKey } from "@/lib/shared/mask-key";
import { ensureSupportedEmail } from "@/lib/server/authz-email";
import { buildKey } from "@/lib/server/keygen";
import { AppError, isAppError } from "@/lib/server/errors";
import { verifyGoogleToken } from "@/lib/server/google-auth";
import { persistGeneratedKey } from "@/lib/server/key-persistence";

export const runtime = "nodejs";

function ensureServerConfigReady(): void {
  const missingConfig: string[] = [];

  if (!GOOGLE_OAUTH_CLIENT_ID) {
    missingConfig.push("GOOGLE_OAUTH_CLIENT_ID");
  }
  if (!KEY_SALT) {
    missingConfig.push("KEY_SALT");
  }
  if (!KEY_PREFIX) {
    missingConfig.push("KEY_PREFIX");
  }
  if (!ALLOWED_EMAIL_SUFFIX) {
    missingConfig.push("ALLOWED_EMAIL_SUFFIX");
  }
  if (!KEY_PERSIST_FILE_PATH) {
    missingConfig.push("KEY_PERSIST_FILE_PATH");
  }
  if (!KEY_SYNC_YAML_FILE_PATH) {
    missingConfig.push("KEY_SYNC_YAML_FILE_PATH");
  }

  if (missingConfig.length > 0) {
    throw new AppError(
      "SERVER_CONFIG_MISSING",
      `SERVER_CONFIG_MISSING: missing ${missingConfig.join(", ")}`,
      500,
    );
  }
}

export async function POST(request: Request): Promise<Response> {
  try {
    const body = (await request.json().catch(() => ({}))) as { token?: unknown };

    if (typeof body.token !== "string" || body.token.trim().length === 0) {
      throw new AppError("BAD_REQUEST", "token is required", 400);
    }

    ensureServerConfigReady();

    const identity = await verifyGoogleToken(body.token);
    ensureSupportedEmail(identity.email, identity.emailVerified);

    const key = buildKey({
      sub: identity.sub,
      email: identity.email,
      salt: KEY_SALT,
    });
    await persistGeneratedKey({
      key,
      keyFilePath: KEY_PERSIST_FILE_PATH,
      syncYamlPath: KEY_SYNC_YAML_FILE_PATH,
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
