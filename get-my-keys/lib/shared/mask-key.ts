export function maskKey(key: string): string {
  if (key.length <= 10) {
    return "*".repeat(key.length);
  }

  const start = key.slice(0, 6);
  const end = key.slice(-4);
  const middle = "*".repeat(key.length - 10);

  return `${start}${middle}${end}`;
}
