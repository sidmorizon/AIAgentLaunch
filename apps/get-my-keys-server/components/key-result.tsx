"use client";

import { useEffect, useState } from "react";

import { copyText } from "@/lib/shared/clipboard";
import {
  AGENT_LAUNCHER_DOWNLOAD_API_PATH,
  COPY_FEEDBACK_MS,
} from "@/lib/shared/constants";

type KeyResultProps = {
  keyValue: string;
  maskedKey: string;
};

export function KeyResult({ keyValue, maskedKey }: KeyResultProps) {
  const defaultBaseUrl = typeof window === "undefined" ? "" : window.location.origin;
  const [baseUrl, setBaseUrl] = useState(defaultBaseUrl);
  const [copiedTarget, setCopiedTarget] = useState<"baseUrl" | "key" | null>(null);
  const [isTestingApi, setIsTestingApi] = useState(false);
  const [apiTestError, setApiTestError] = useState<string | null>(null);
  const [supportedModels, setSupportedModels] = useState<string[] | null>(null);

  useEffect(() => {
    if (!copiedTarget) {
      return;
    }

    const timer = window.setTimeout(() => {
      setCopiedTarget(null);
    }, COPY_FEEDBACK_MS);

    return () => {
      window.clearTimeout(timer);
    };
  }, [copiedTarget]);

  const handleCopy = async (value: string, target: "baseUrl" | "key") => {
    await copyText(value);
    setCopiedTarget(target);
  };

  const handleTestApi = async () => {
    setIsTestingApi(true);
    setApiTestError(null);
    setSupportedModels(null);
    const normalizedBaseUrl = baseUrl.trim().replace(/\/+$/, "");

    if (!normalizedBaseUrl) {
      setApiTestError("请输入 Base URL");
      setIsTestingApi(false);
      return;
    }

    try {
      const response = await fetch(`${normalizedBaseUrl}/models`, {
        method: "GET",
        headers: {
          authorization: `Bearer ${keyValue}`,
        },
      });

      const payload = (await response.json().catch(() => null)) as
        | { data?: unknown; error?: { message?: unknown }; message?: unknown }
        | null;

      if (!response.ok) {
        const message =
          typeof payload?.error?.message === "string"
            ? payload.error.message
            : typeof payload?.message === "string"
              ? payload.message
              : `请求失败 (${response.status})`;
        setApiTestError(message);
        return;
      }

      const models = Array.isArray(payload?.data)
        ? payload.data
            .map((item) => {
              if (typeof item === "object" && item !== null && "id" in item) {
                const modelId = (item as { id?: unknown }).id;
                return typeof modelId === "string" ? modelId : null;
              }

              return null;
            })
            .filter((modelId): modelId is string => modelId !== null)
        : [];

      setSupportedModels(models);
    } catch {
      setApiTestError("请求失败，请稍后重试");
    } finally {
      setIsTestingApi(false);
    }
  };

  return (
    <section className="card key-card" aria-label="key-result">
      <div className="key-header">
        <p className="eyebrow">Runtime Credentials</p>
        <h2>Your Key</h2>
        <a className="copy-button secondary launcher-download-button" href={AGENT_LAUNCHER_DOWNLOAD_API_PATH}>
          下载 Codex 启动器 →
        </a> 
      </div>

      <div className="credential-block">
        <div className="credential-title-row">
          <p>Base URL</p>
          <button
            className="copy-button secondary"
            onClick={() => handleCopy(baseUrl, "baseUrl")}
            type="button"
          >
            {copiedTarget === "baseUrl" ? "已复制" : "复制"}
          </button>
        </div>
        <input
          aria-label="Base URL"
          autoComplete="off"
          className="code-line base-url-input"
          onChange={(event) => setBaseUrl(event.target.value)}
          spellCheck={false}
          type="text"
          value={baseUrl}
        />
      </div>

      <div className="credential-block">
        <div className="credential-title-row">
          <p>API Key</p>
          <button className="copy-button" onClick={() => handleCopy(keyValue, "key")} type="button">
            {copiedTarget === "key" ? "已复制" : "复制"}
          </button>
        </div>
        <p className="masked-key">{maskedKey}</p>
        <div className="api-test-panel">
          <button className="copy-button secondary" disabled={isTestingApi} onClick={handleTestApi} type="button">
            {isTestingApi ? "测试中..." : "测试 API"}
          </button>
          {apiTestError ? (
            <p aria-live="polite" className="error">
              {apiTestError}
            </p>
          ) : null}
          {supportedModels ? (
            <>
              <p className="hint">
                {supportedModels.length > 0
                  ? `连通成功，返回 ${supportedModels.length} 个模型`
                  : "连通成功，但未返回模型列表"}
              </p>
              {supportedModels.length > 0 ? (
                <ul className="model-list" aria-label="supported-model-list">
                  {supportedModels.map((modelId) => (
                    <li key={modelId}>{modelId}</li>
                  ))}
                </ul>
              ) : null}
            </>
          ) : null}
        </div>
      </div>
    </section>
  );
}
