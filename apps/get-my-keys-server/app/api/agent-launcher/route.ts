import path from "node:path";
import { readFile } from "node:fs/promises";

import { NextResponse } from "next/server";

import { AGENT_LAUNCHER_FILE_PATH } from "@/lib/shared/constants";
import { AppError, isAppError } from "@/lib/server/errors";

export const runtime = "nodejs";

function ensureLauncherConfigReady(): string {
  if (!AGENT_LAUNCHER_FILE_PATH) {
    throw new AppError(
      "SERVER_CONFIG_MISSING",
      "SERVER_CONFIG_MISSING: missing AGENT_LAUNCHER_FILE_PATH",
      500,
    );
  }

  return AGENT_LAUNCHER_FILE_PATH;
}

export async function GET(): Promise<Response> {
  try {
    const launcherFilePath = ensureLauncherConfigReady();
    const fileContent = await readFile(launcherFilePath);
    const fileName = path.basename(launcherFilePath) || "agent-launcher.bin";

    return new Response(fileContent, {
      status: 200,
      headers: {
        "content-type": "application/octet-stream",
        "content-disposition": `attachment; filename="${fileName}"`,
        "cache-control": "no-store",
      },
    });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      return NextResponse.json(
        {
          error: {
            code: "LAUNCHER_FILE_NOT_FOUND",
            message: "LAUNCHER_FILE_NOT_FOUND: file not found",
          },
        },
        { status: 404 },
      );
    }

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
