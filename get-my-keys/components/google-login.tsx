"use client";

import { useEffect, useRef, useState } from "react";

import { GOOGLE_OAUTH_CLIENT_ID } from "@/lib/shared/constants";

type GoogleCredentialResponse = {
  credential?: string;
};

type GoogleIdentity = {
  accounts: {
    id: {
      initialize: (input: {
        client_id: string;
        callback: (response: GoogleCredentialResponse) => void;
      }) => void;
      renderButton: (
        element: HTMLElement,
        options: { theme?: string; size?: string; width?: number },
      ) => void;
    };
  };
};

declare global {
  interface Window {
    google?: GoogleIdentity;
  }
}

type GoogleLoginProps = {
  disabled?: boolean;
  onToken: (token: string) => void;
};

export function GoogleLogin({ disabled = false, onToken }: GoogleLoginProps) {
  const buttonContainerRef = useRef<HTMLDivElement>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    const initializeButton = () => {
      if (!mounted || !buttonContainerRef.current || !window.google?.accounts?.id) {
        return;
      }

      buttonContainerRef.current.innerHTML = "";

      window.google.accounts.id.initialize({
        client_id: GOOGLE_OAUTH_CLIENT_ID,
        callback: (response: GoogleCredentialResponse) => {
          if (!response.credential) {
            setLoadError("Google 登录未返回 token");
            return;
          }

          onToken(response.credential);
        },
      });

      window.google.accounts.id.renderButton(buttonContainerRef.current, {
        theme: "outline",
        size: "large",
        width: 280,
      });
    };

    const scriptId = "google-gsi-script";
    const existingScript = document.getElementById(scriptId) as
      | HTMLScriptElement
      | null;

    if (window.google?.accounts?.id) {
      initializeButton();
    } else if (existingScript) {
      existingScript.addEventListener("load", initializeButton);
      existingScript.addEventListener("error", () => {
        if (mounted) setLoadError("Google 登录脚本加载失败");
      });
    } else {
      const script = document.createElement("script");
      script.id = scriptId;
      script.src = "https://accounts.google.com/gsi/client";
      script.async = true;
      script.defer = true;
      script.addEventListener("load", initializeButton);
      script.addEventListener("error", () => {
        if (mounted) setLoadError("Google 登录脚本加载失败");
      });
      document.head.appendChild(script);
    }

    return () => {
      mounted = false;
    };
  }, [onToken]);

  return (
    <section aria-label="google-login">
      <div aria-disabled={disabled} ref={buttonContainerRef} />
      {disabled ? <p className="hint">正在处理登录结果...</p> : null}
      {loadError ? <p className="error">{loadError}</p> : null}
    </section>
  );
}
