export type AppErrorCode =
  | "BAD_REQUEST"
  | "INVALID_GOOGLE_TOKEN"
  | "UNSUPPORTED_EMAIL_DOMAIN"
  | "EMAIL_NOT_VERIFIED"
  | "INVALID_TOKEN_CLAIMS"
  | "SERVER_CONFIG_MISSING"
  | "INTERNAL_ERROR";

export class AppError extends Error {
  readonly code: AppErrorCode;
  readonly status: number;

  constructor(code: AppErrorCode, message: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
    this.name = code;
  }
}

export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}
