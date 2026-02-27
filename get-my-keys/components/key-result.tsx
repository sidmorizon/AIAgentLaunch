"use client";

import { useEffect, useState } from "react";

import { copyText } from "@/lib/shared/clipboard";
import { COPY_FEEDBACK_MS } from "@/lib/shared/constants";

type KeyResultProps = {
  keyValue: string;
  maskedKey: string;
};

export function KeyResult({ keyValue, maskedKey }: KeyResultProps) {
  const [copiedTarget, setCopiedTarget] = useState<"baseUrl" | "key" | null>(null);
  const baseUrl = typeof window === "undefined" ? "/v1" : `${window.location.origin}/v1`;

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

  return (
    <section className="card key-card" aria-label="key-result">
      <div className="key-header">
        <p className="eyebrow">Runtime Credentials</p>
        <h2>Your Key</h2>
      </div>

      <div className="credential-block">
        <div className="credential-title-row">
          <p>Base URL</p>
          <button
            className="copy-button secondary"
            onClick={() => handleCopy(baseUrl, "baseUrl")}
            type="button"
          >
            {copiedTarget === "baseUrl" ? "已复制" : "复制 Base URL"}
          </button>
        </div>
        <p className="code-line">{baseUrl}</p>
      </div>

      <div className="credential-block">
        <div className="credential-title-row">
          <p>Access Key</p>
          <button className="copy-button" onClick={() => handleCopy(keyValue, "key")} type="button">
            {copiedTarget === "key" ? "已复制" : "复制 Key"}
          </button>
        </div>
        <p className="masked-key">{maskedKey}</p>
      </div>
    </section>
  );
}
