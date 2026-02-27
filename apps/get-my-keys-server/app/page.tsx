"use client";

import { useCallback, useState } from "react";

import { GoogleLogin } from "@/components/google-login";
import { KeyResult } from "@/components/key-result";
import { KEY_API_PATH } from "@/lib/shared/constants";

type ApiSuccess = {
  key: string;
  maskedKey: string;
  profile: {
    sub: string;
    email: string;
  };
};

type ApiFailure = {
  error: {
    code: string;
    message: string;
  };
};

export default function HomePage() {
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [result, setResult] = useState<ApiSuccess | null>(null);

  const handleToken = useCallback(async (token: string) => {
    setIsLoading(true);
    setErrorMessage(null);

    try {
      const response = await fetch(KEY_API_PATH, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({ token }),
      });

      const data = (await response.json()) as ApiSuccess | ApiFailure;

      if (!response.ok) {
        setResult(null);
        setErrorMessage((data as ApiFailure).error.message);
        return;
      }

      setResult(data as ApiSuccess);
    } catch {
      setResult(null);
      setErrorMessage("请求失败，请稍后重试");
    } finally {
      setIsLoading(false);
    }
  }, []);

  return (
    <main className="page">
      <div className="noise" aria-hidden="true" />
      <div className="card hero-card">
        <p className="eyebrow">OneKey Internal API</p>
        <h1>Get My Keys</h1>
        <p className="lead">使用 Google 登录后生成专属 Key，并复制可直接调用的接口地址。</p>
        <GoogleLogin disabled={isLoading} onToken={handleToken} />
        {errorMessage ? (
          <p aria-live="polite" className="error">
            {errorMessage}
          </p>
        ) : null}
      </div>

      {result ? <KeyResult keyValue={result.key} maskedKey={result.maskedKey} /> : null}
    </main>
  );
}
