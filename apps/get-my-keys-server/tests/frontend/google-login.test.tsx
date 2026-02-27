// @vitest-environment jsdom

import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

describe("GoogleLogin", () => {
  const originalServerClientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const originalClientId = process.env.NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID;

  beforeEach(() => {
    delete process.env.GOOGLE_OAUTH_CLIENT_ID;
    delete process.env.NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID;
    vi.resetModules();
  });

  afterEach(() => {
    if (typeof originalServerClientId === "string") {
      process.env.GOOGLE_OAUTH_CLIENT_ID = originalServerClientId;
    } else {
      delete process.env.GOOGLE_OAUTH_CLIENT_ID;
    }

    if (typeof originalClientId === "string") {
      process.env.NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID = originalClientId;
    } else {
      delete process.env.NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID;
    }
  });

  it("shows config error when google oauth client id is missing", async () => {
    const { GoogleLogin } = await import("../../components/google-login");
    render(<GoogleLogin onToken={vi.fn()} />);

    expect(
      await screen.findByText("SERVER_CONFIG_MISSING: 缺少 GOOGLE_OAUTH_CLIENT_ID"),
    ).toBeInTheDocument();
  });
});
