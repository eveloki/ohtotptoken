/**
 * CommonUtils — 通用工具函数
 *
 * 此文件导出纯函数，可安全在 @Concurrent 装饰的 TaskPool 函数中通过 import 引入。
 */

/** 数字补零：小于 10 时前补 '0'，用于日期/时间格式化 */
export function padZero(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}
