export const NEXT_BASE_PATH = "/get-my-keys";
export const KEY_API_PATH = `${NEXT_BASE_PATH}/api/key`;
export const AGENT_LAUNCHER_DOWNLOAD_API_PATH = `${NEXT_BASE_PATH}/api/agent-launcher`;
export const COPY_FEEDBACK_MS = 1500;

const NEXT_PUBLIC_GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID?.trim() ?? "";
const SERVER_GOOGLE_CLIENT_ID = process.env.GOOGLE_OAUTH_CLIENT_ID?.trim() ?? "";

export const GOOGLE_OAUTH_CLIENT_ID =
  NEXT_PUBLIC_GOOGLE_CLIENT_ID || SERVER_GOOGLE_CLIENT_ID;
export const KEY_SALT = process.env.KEY_SALT?.trim() ?? "";
export const KEY_PREFIX = process.env.KEY_PREFIX?.trim() ?? "";
export const ALLOWED_EMAIL_SUFFIX = process.env.ALLOWED_EMAIL_SUFFIX?.trim() ?? "";
export const KEY_PERSIST_FILE_PATH = process.env.KEY_PERSIST_FILE_PATH?.trim() ?? "";
export const KEY_SYNC_YAML_FILE_PATH = process.env.KEY_SYNC_YAML_FILE_PATH?.trim() ?? "";
export const AGENT_LAUNCHER_FILE_PATH = process.env.AGENT_LAUNCHER_FILE_PATH?.trim() ?? "";
