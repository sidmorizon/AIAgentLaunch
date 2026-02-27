import { OAuth2Client } from "google-auth-library";

import { GOOGLE_OAUTH_CLIENT_ID } from "../shared/constants";
import { AppError, isAppError } from "./errors";

const oauthClient = new OAuth2Client();

export type VerifiedGoogleIdentity = {
  sub: string;
  email: string;
  emailVerified: boolean;
};

export async function verifyGoogleToken(
  token: string,
): Promise<VerifiedGoogleIdentity> {
  try {
    const ticket = await oauthClient.verifyIdToken({
      idToken: token,
      audience: GOOGLE_OAUTH_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    const sub = payload?.sub;
    const email = payload?.email;

    if (!sub || !email) {
      throw new AppError(
        "INVALID_TOKEN_CLAIMS",
        "INVALID_TOKEN_CLAIMS",
        422,
      );
    }

    return {
      sub,
      email,
      emailVerified: payload.email_verified === true,
    };
  } catch (error) {
    if (isAppError(error)) {
      throw error;
    }

    throw new AppError("INVALID_GOOGLE_TOKEN", "INVALID_GOOGLE_TOKEN", 401);
  }
}
