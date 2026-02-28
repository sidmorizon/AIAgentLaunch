// @vitest-environment jsdom

import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { KeyResult } from "../../components/key-result";
import {
  AGENT_LAUNCHER_DOWNLOAD_API_PATH,
  COPY_FEEDBACK_MS,
} from "../../lib/shared/constants";

const copyTextMock = vi.hoisted(() => vi.fn().mockResolvedValue(undefined));

vi.mock("../../lib/shared/clipboard", () => ({
  copyText: copyTextMock,
}));

describe("KeyResult", () => {
  beforeEach(() => {
    copyTextMock.mockReset();
    copyTextMock.mockResolvedValue(undefined);
    vi.stubGlobal("fetch", vi.fn());
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it("copies full key and toggles feedback text", async () => {
    const user = userEvent.setup();

    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    await user.click(screen.getAllByRole("button", { name: "复制" })[1]);

    expect(copyTextMock).toHaveBeenCalledWith(
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    );
    expect(screen.getByRole("button", { name: "已复制" })).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getAllByRole("button", { name: "复制" })).toHaveLength(2);
    }, { timeout: COPY_FEEDBACK_MS + 1200 });
  });

  it("shows editable baseURL from current origin and can copy changed value", async () => {
    const user = userEvent.setup();
    const expectedBaseUrl = window.location.origin;
    const customBaseUrl = "https://proxy.example.com/v1";

    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    const baseUrlInput = screen.getByRole("textbox", { name: "Base URL" });
    expect(baseUrlInput).toHaveValue(expectedBaseUrl);

    await user.clear(baseUrlInput);
    await user.type(baseUrlInput, customBaseUrl);

    await user.click(screen.getAllByRole("button", { name: "复制" })[0]);

    expect(copyTextMock).toHaveBeenCalledWith(customBaseUrl);
    expect(screen.getByRole("button", { name: "已复制" })).toBeInTheDocument();
  });

  it("renders launcher download button in Your Key panel", () => {
    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    expect(screen.getByRole("link", { name: "下载 Codex 启动器 →" })).toHaveAttribute(
      "href",
      AGENT_LAUNCHER_DOWNLOAD_API_PATH,
    );
  });

  it("tests OpenAI connectivity with edited base URL and key, then renders models", async () => {
    const user = userEvent.setup();
    const customBaseUrl = "https://proxy.example.com/v2/";

    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({
          data: [{ id: "gpt-4o-mini" }, { id: "gpt-5" }],
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json",
          },
        },
      ),
    );

    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    const baseUrlInput = screen.getByRole("textbox", { name: "Base URL" });
    await user.clear(baseUrlInput);
    await user.type(baseUrlInput, customBaseUrl);
    await user.click(screen.getByRole("button", { name: "测试 API" }));

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith("https://proxy.example.com/v2/models", {
        method: "GET",
        headers: {
          authorization:
            "Bearer bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        },
      });
    });

    expect(screen.getByText("gpt-4o-mini")).toBeInTheDocument();
    expect(screen.getByText("gpt-5")).toBeInTheDocument();
  });

  it("shows api test error message when model request fails", async () => {
    const user = userEvent.setup();

    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({
          error: { message: "invalid api key" },
        }),
        {
          status: 401,
          headers: {
            "content-type": "application/json",
          },
        },
      ),
    );

    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    await user.click(screen.getByRole("button", { name: "测试 API" }));

    await waitFor(() => {
      expect(screen.getByText("invalid api key")).toBeInTheDocument();
    });
  });

  it("shows validation error when baseURL is empty", async () => {
    const user = userEvent.setup();

    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    const baseUrlInput = screen.getByRole("textbox", { name: "Base URL" });
    await user.clear(baseUrlInput);

    await user.click(screen.getByRole("button", { name: "测试 API" }));

    expect(fetch).not.toHaveBeenCalled();
    expect(screen.getByText("请输入 Base URL")).toBeInTheDocument();
  });
});
