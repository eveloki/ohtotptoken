
export function colorHex(color: number): string {
  return `#${(color >>> 0).toString(16).padStart(8, '0')}`;
}

export function hexColor(hex: string): number {
  if (hex.length < 7) return 0;
  if (hex[0] != '#') return 0;
  const r_pos = hex.length < 9 ? 1 : 3;
  const r = parseInt(hex.substring(r_pos, r_pos + 2), 16);
  const g = parseInt(hex.substring(r_pos + 2, r_pos + 4), 16);
  const b = parseInt(hex.substring(r_pos + 4, r_pos + 6), 16);
  return setRgba(r, g, b, 255);
}

// scale: 0~1
export function scaleRgba(rgba: number, scale: number): number {
  const safe_scale = scale > 1 ? 1 : scale < 0 ? 0 : scale;
  const r: number = Math.floor((rgba >>> 16) & 0xff * safe_scale);
  const g: number = Math.floor((rgba >>> 8) & 0xff * safe_scale);
  const b: number = Math.floor(rgba & 0xff * safe_scale);
  return setRgba(r, g, b, 255);
}

// ratio: 0~1
export function mixRgba(rgba0: number, rgba1: number, ratio: number): number {
  const safe_ratio = ratio > 1 ? 1 : ratio < 0 ? 0 : ratio;
  const r0: number = (rgba0 >>> 16) & 0xff * safe_ratio;
  const g0: number = (rgba0 >>> 8) & 0xff * safe_ratio;
  const b0: number = rgba0 & 0xff * safe_ratio;
  const r1: number = (rgba1 >>> 16) & 0xff * (1 - safe_ratio);
  const g1: number = (rgba1 >>> 8) & 0xff * (1 - safe_ratio);
  const b1: number = rgba1 & 0xff * (1 - safe_ratio);
  const r2 = r0 + r1;
  const g2 = g0 + g1;
  const b2 = b0 + b1;
  const safe_r = r2 > 255 ? 255 : r2 < 0 ? 0 : r2;
  const safe_g = g2 > 255 ? 255 : g2 < 0 ? 0 : g2;
  const safe_b = b2 > 255 ? 255 : b2 < 0 ? 0 : b2;
  return setRgba(safe_r, safe_g, safe_b, 255);
}

export function setRgba(red: number, green: number, blue: number, opacity: number): number {
  return (opacity << 24) | (red << 16) | (green << 8) | blue;
}