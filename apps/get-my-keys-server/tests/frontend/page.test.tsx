// @vitest-environment jsdom

import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import HomePage from "../../app/page";
import {
  AGENT_LAUNCHER_DOWNLOAD_API_PATH,
  KEY_API_PATH,
} from "../../lib/shared/constants";

vi.mock("../../components/google-login", () => ({
  GoogleLogin: ({
    disabled,
    onToken,
  }: {
    disabled?: boolean;
    onToken: (token: string) => void;
  }) => (
    <button disabled={disabled} onClick={() => onToken("mock-google-token")}>
      Mock Google Login
    </button>
  ),
}));

describe("HomePage", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn());
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("posts token to prefixed API path and renders masked key", async () => {
    const expectedBaseUrl = window.location.origin;

    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({
          key: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          maskedKey: "aaaaaa******************************************************aaaa",
          profile: {
            sub: "sub-1",
            email: "alice@onekey.so",
          },
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json",
          },
        },
      ),
    );

    render(<HomePage />);

    await userEvent.click(screen.getByRole("button", { name: "Mock Google Login" }));

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(
        KEY_API_PATH,
        expect.objectContaining({ method: "POST" }),
      );
    });

    expect(
      screen.getByText("aaaaaa******************************************************aaaa"),
    ).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: "Base URL" })).toHaveValue(expectedBaseUrl);
    expect(
      screen.queryByText(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      ),
    ).not.toBeInTheDocument();
  });

  it("does not render launcher download button before key is generated", () => {
    render(<HomePage />);

    expect(screen.queryByRole("link", { name: "下载 Codex 启动器 →" })).not.toBeInTheDocument();
  });

  it("renders launcher download button in Your Key panel after key is generated", async () => {
    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({
          key: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          maskedKey: "aaaaaa******************************************************aaaa",
          profile: {
            sub: "sub-1",
            email: "alice@onekey.so",
          },
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json",
          },
        },
      ),
    );

    render(<HomePage />);
    await userEvent.click(screen.getByRole("button", { name: "Mock Google Login" }));

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(
        KEY_API_PATH,
        expect.objectContaining({ method: "POST" }),
      );
    });

    expect(screen.getByRole("link", { name: "下载 Codex 启动器 →" })).toHaveAttribute(
      "href",
      AGENT_LAUNCHER_DOWNLOAD_API_PATH,
    );
  });

  it("renders backend error message when request is rejected", async () => {
    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({
          error: {
            code: "UNSUPPORTED_EMAIL_DOMAIN",
            message: "UNSUPPORTED_EMAIL_DOMAIN: 不支持该邮箱",
          },
        }),
        {
          status: 403,
          headers: {
            "content-type": "application/json",
          },
        },
      ),
    );

    render(<HomePage />);

    await userEvent.click(
      screen.getByRole("button", { name: "Mock Google Login" }),
    );

    await waitFor(() => {
      expect(
        screen.getByText("UNSUPPORTED_EMAIL_DOMAIN: 不支持该邮箱"),
      ).toBeInTheDocument();
    });
  });
});
