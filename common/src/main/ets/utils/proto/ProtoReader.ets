/**
 * Steam protobuf 解码器（ArkTS 手写实现）。
 *
 * 与 `ProtoWriter` 配对；wireType 判定与字节扫描方式参考
 * `.ai/Aigis-master/entry/src/main/ets/crypto/googleAuth.ets:90-138`，
 * 但改用「字段迭代器 + 强类型读取」结构，避免 Aigis 元组下标与字段号强耦合的写法
 * （Steam 消息字段号有跳号，例如 CTwoFactor_RemoveAuthenticator_Request 只有 2/5/6/7）。
 *
 * 使用方式：
 *   const r = new ProtoReader(bytes);
 *   while (r.next()) {
 *     switch (r.field()) {
 *       case 1: steamid = r.readFixed64(); break;
 *       case 2: accountName = r.readString(); break;
 *       default: r.skip();
 *     }
 *   }
 */

import { buffer } from '@kit.ArkTS';
import { WIRE_VARINT, WIRE_FIXED64, WIRE_LEN, WIRE_FIXED32 } from './ProtoWriter';

export class ProtoReader {
  private buf: Uint8Array;
  private pos: number = 0;
  private fieldNo: number = 0;
  private wire: number = 0;

  constructor(buf: Uint8Array) {
    this.buf = buf;
  }

  /** 当前字段号（`next()` 之后有效） */
  field(): number {
    return this.fieldNo;
  }

  /** 当前 wireType（`next()` 之后有效） */
  wireType(): number {
    return this.wire;
  }

  eof(): boolean {
    return this.pos >= this.buf.length;
  }

  private require(count: number): void {
    if (this.pos + count > this.buf.length) {
      throw new Error(`protobuf 数据截断: 需要 ${count} 字节, 剩余 ${this.buf.length - this.pos}`);
    }
  }

  /** 读取下一个字段的 tag；返回 false 表示已到末尾 */
  next(): boolean {
    if (this.pos >= this.buf.length) {
      return false;
    }
    const tag: number = Number(this.readVarint() & 0xffffffffn);
    this.fieldNo = tag >>> 3;
    this.wire = tag & 0x07;
    return true;
  }

  readVarint(): bigint {
    let result: bigint = 0n;
    let shift: bigint = 0n;
    for (let i = 0; i < 10; i++) {
      this.require(1);
      const byte: number = this.buf[this.pos];
      this.pos = this.pos + 1;
      result = result | (BigInt(byte & 0x7f) << shift);
      if ((byte & 0x80) === 0) {
        return result;
      }
      shift = shift + 7n;
    }
    throw new Error('protobuf varint 超过 10 字节');
  }

  readUint32(): number {
    return Number(this.readVarint() & 0xffffffffn);
  }

  readInt32(): number {
    const raw: number = Number(this.readVarint() & 0xffffffffn);
    return raw > 0x7fffffff ? raw - 0x100000000 : raw;
  }

  readBool(): boolean {
    return this.readVarint() !== 0n;
  }

  readUint64(): bigint {
    return this.readVarint();
  }

  /** fixed64：小端 8 字节 */
  readFixed64(): bigint {
    this.require(8);
    let value: bigint = 0n;
    for (let i = 7; i >= 0; i--) {
      value = (value << 8n) | BigInt(this.buf[this.pos + i]);
    }
    this.pos = this.pos + 8;
    return value;
  }

  /** 仅 float（wireType 5）：小端 IEEE754 单精度 */
  readFloat32(): number {
    this.require(4);
    const tmp: Uint8Array = new Uint8Array(4);
    tmp[0] = this.buf[this.pos];
    tmp[1] = this.buf[this.pos + 1];
    tmp[2] = this.buf[this.pos + 2];
    tmp[3] = this.buf[this.pos + 3];
    this.pos = this.pos + 4;
    return new Float32Array(tmp.buffer)[0];
  }

  private readLength(): number {
    const len: number = Number(this.readVarint());
    if (len < 0 || this.pos + len > this.buf.length) {
      throw new Error(`protobuf length-delimited 越界: len=${len}`);
    }
    return len;
  }

  readBytes(): Uint8Array {
    const len: number = this.readLength();
    const out: Uint8Array = new Uint8Array(len);
    out.set(this.buf.subarray(this.pos, this.pos + len));
    this.pos = this.pos + len;
    return out;
  }

  readString(): string {
    // 与 ProtoWriter.writeString 对称：统一用 buffer 做 UTF-8 解码，
    // 避免 util.TextDecoder 在不同运行时行为不一致。
    const bytes: Uint8Array = this.readBytes();
    return buffer.from(bytes.buffer as ArrayBuffer).toString('utf-8');
  }

  /** 嵌套消息：返回独立的子 reader */
  readMessage(): ProtoReader {
    return new ProtoReader(this.readBytes());
  }

  /** 跳过当前字段（遇到未使用字段时调用） */
  skip(): void {
    switch (this.wire) {
      case WIRE_VARINT:
        this.readVarint();
        break;
      case WIRE_FIXED64:
        this.require(8);
        this.pos = this.pos + 8;
        break;
      case WIRE_LEN: {
        // 注意：必须先取长度再推进 pos。写成 `this.pos = this.pos + this.readLength()`
        // 会先读取旧的 pos，导致丢掉长度 varint 本身占用的字节而错位。
        const len: number = this.readLength();
        this.pos = this.pos + len;
        break;
      }
      case WIRE_FIXED32:
        this.require(4);
        this.pos = this.pos + 4;
        break;
      default:
        throw new Error(`protobuf 未知 wireType: ${this.wire} (field ${this.fieldNo})`);
    }
  }
}
