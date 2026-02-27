import { ALLOWED_EMAIL_SUFFIX } from "../shared/constants";
import { AppError } from "./errors";

export function ensureSupportedEmail(
  email: string,
  emailVerified: boolean,
): void {
  const normalizedEmail = email.trim().toLowerCase();
  const domain = normalizedEmail.split("@")[1];

  if (!domain || `@${domain}` !== ALLOWED_EMAIL_SUFFIX) {
    throw new AppError(
      "UNSUPPORTED_EMAIL_DOMAIN",
      "UNSUPPORTED_EMAIL_DOMAIN: 不支持该邮箱",
      403,
    );
  }

  if (!emailVerified) {
    throw new AppError("EMAIL_NOT_VERIFIED", "EMAIL_NOT_VERIFIED", 403);
  }
}
