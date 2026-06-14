export function platformPackageName(platform?: string, arch?: string): string | undefined;
export function resolveBinary(options?: { env?: Record<string, string | undefined>; platform?: string; arch?: string }): string;
