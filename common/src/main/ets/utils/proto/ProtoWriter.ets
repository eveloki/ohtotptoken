/**
 * Steam protobuf 编码器（ArkTS 手写实现）。
 *
 * 解码思路参考 `.ai/Aigis-master/entry/src/main/ets/crypto/googleAuth.ets`
 * （getProtobufValueOffset + wireType 字节扫描）；Aigis 只实现了解码，
 * 本文件补上编码能力，因为 Steam 的 API 请求体是 protobuf 编码后 base64 传的。
 *
 * 仅覆盖本项目所需的字段类型：
 * - varint（uint32 / int32 / bool / enum / uint64）
 * - length-delimited（string / bytes / 嵌套消息）
 * - fixed64（Steam 的 steamid、serial_number 是 fixed64）
 * - fixed32 只读不写（仅 float 的 interval 字段需要读）
 *
 * 字段号全部取自官方 .proto（已核对 `.ai/Authenticator-main/.../steamapi/protobufs/`），
 * 不做任何重命名，避免与官方定义产生编码歧义。
 */

import { buffer } from '@kit.ArkTS';

export const WIRE_VARINT: number = 0;
export const WIRE_FIXED64: number = 1;
export const WIRE_LEN: number = 2;
export const WIRE_FIXED32: number = 5;

const SHIFT_64: bigint = 1n << 64n;

export class ProtoWriter {
  private buf: Uint8Array = new Uint8Array(128);
  private size: number = 0;

  private ensure(extra: number): void {
    if (this.size + extra <= this.buf.length) {
      return;
    }
    let cap: number = this.buf.length * 2;
    while (cap < this.size + extra) {
      cap = cap * 2;
    }
    const next: Uint8Array = new Uint8Array(cap);
    next.set(this.buf.subarray(0, this.size));
    this.buf = next;
  }

  private put(byte: number): void {
    this.ensure(1);
    this.buf[this.size] = byte & 0xff;
    this.size = this.size + 1;
  }

  private putRaw(data: Uint8Array): void {
    this.ensure(data.length);
    this.buf.set(data, this.size);
    this.size = this.size + data.length;
  }

  private putTag(field: number, wire: number): void {
    this.writeVarint(BigInt((field << 3) | wire));
  }

  /** varint：负数按 64 位补码（10 字节）编码，符合 protobuf 规范 */
  writeVarint(value: bigint): void {
    let v: bigint = value;
    if (v < 0n) {
      v = v + SHIFT_64;
    }
    while (v >= 0x80n) {
      this.put(Number(v & 0x7fn) | 0x80);
      v = v >> 7n;
    }
    this.put(Number(v));
  }

  writeUint32(field: number, value: number): void {
    this.putTag(field, WIRE_VARINT);
    this.writeVarint(BigInt(Math.trunc(value)));
  }

  writeInt32(field: number, value: number): void {
    this.putTag(field, WIRE_VARINT);
    this.writeVarint(BigInt(Math.trunc(value)));
  }

  writeBool(field: number, value: boolean): void {
    this.putTag(field, WIRE_VARINT);
    this.writeVarint(value ? 1n : 0n);
  }

  writeUint64(field: number, value: bigint): void {
    this.putTag(field, WIRE_VARINT);
    this.writeVarint(value);
  }

  /** fixed64：小端 8 字节（Steam 的 steamid / serial_number） */
  writeFixed64(field: number, value: bigint): void {
    this.putTag(field, WIRE_FIXED64);
    let v: bigint = value;
    if (v < 0n) {
      v = v + SHIFT_64;
    }
    for (let i = 0; i < 8; i++) {
      this.put(Number(v & 0xffn));
      v = v >> 8n;
    }
  }

  writeString(field: number, value: string): void {
    // 用 buffer 而非 util.TextEncoder：后者在 LocalUnit/Previewer 运行时
    // 返回空数组（实测 encodeInto 结果为 length=0），会让编解码错位。
    const encoded: buffer.Buffer = buffer.from(value, 'utf-8');
    const bytes: Uint8Array = new Uint8Array(encoded.length);
    for (let i = 0; i < encoded.length; i++) {
      bytes[i] = encoded[i];
    }
    this.putTag(field, WIRE_LEN);
    this.writeVarint(BigInt(bytes.length));
    this.putRaw(bytes);
  }

  writeBytes(field: number, value: Uint8Array): void {
    this.putTag(field, WIRE_LEN);
    this.writeVarint(BigInt(value.length));
    this.putRaw(value);
  }

  /** 嵌套消息：在独立 writer 中构建完成后整体写入（避免长度回填） */
  writeMessage(field: number, body: ProtoWriter): void {
    this.writeBytes(field, body.finish());
  }

  /** 取编码结果（拷贝，避免后续写入影响返回值） */
  finish(): Uint8Array {
    const out: Uint8Array = new Uint8Array(this.size);
    out.set(this.buf.subarray(0, this.size));
    return out;
  }

  getLength(): number {
    return this.size;
  }
}
