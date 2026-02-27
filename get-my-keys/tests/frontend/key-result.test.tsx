// @vitest-environment jsdom

import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { KeyResult } from "../../components/key-result";
import { COPY_FEEDBACK_MS } from "../../lib/shared/constants";

const copyTextMock = vi.hoisted(() => vi.fn().mockResolvedValue(undefined));

vi.mock("../../lib/shared/clipboard", () => ({
  copyText: copyTextMock,
}));

describe("KeyResult", () => {
  beforeEach(() => {
    copyTextMock.mockReset();
    copyTextMock.mockResolvedValue(undefined);
  });

  afterEach(() => {
    vi.restoreAllMocks();
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

    await user.click(screen.getByRole("button", { name: "复制 Key" }));

    expect(copyTextMock).toHaveBeenCalledWith(
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    );
    expect(screen.getByRole("button", { name: "已复制" })).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "复制 Key" })).toBeInTheDocument();
    }, { timeout: COPY_FEEDBACK_MS + 1200 });
  });

  it("shows baseURL from current origin and can copy it", async () => {
    const user = userEvent.setup();
    const expectedBaseUrl = `${window.location.origin}/v1`;

    render(
      <KeyResult
        keyValue="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        maskedKey="bbbbbb******************************************************bbbb"
      />,
    );

    expect(screen.getByText(expectedBaseUrl)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "复制 Base URL" }));

    expect(copyTextMock).toHaveBeenCalledWith(expectedBaseUrl);
    expect(screen.getByRole("button", { name: "已复制" })).toBeInTheDocument();
  });
});
