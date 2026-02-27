import type { NextConfig } from "next";
import { NEXT_BASE_PATH } from "./lib/shared/constants";

const nextConfig: NextConfig = {
  basePath: NEXT_BASE_PATH,
  env: {
    NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID:
      process.env.NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID ?? process.env.GOOGLE_OAUTH_CLIENT_ID ?? "",
  },
  async redirects() {
    return [
      {
        source: "/",
        destination: NEXT_BASE_PATH,
        permanent: false,
        basePath: false,
      },
    ];
  },
};

export default nextConfig;
