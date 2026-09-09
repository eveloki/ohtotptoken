import { describe, it, expect } from '@ohos/hypium';
import { ProtoWriter } from 'common';
import { ProtoReader } from 'common';

/**
 * Steam protobuf 手写编解码单元测试。
 *
 * 前几组是「黄金向量」：期望字节直接按 protobuf 编码规范手算，
 * 用于锁定 wire format（tag = field<<3|wire、varint 小端 7bit 分组、
 * fixed64 小端 8 字节、length-delimited = tag + varint(len) + 内容）。
 * 其余为往返测试，覆盖本项目实际用到的字段类型。
 */

function toArray(bytes: Uint8Array): number[] {
  const out: number[] = [];
  for (let i = 0; i < bytes.length; i++) {
    out.push(bytes[i]);
  }
  return out;
}

export default function steamProtoTest() {
  describe('steamProtoTest', () => {
    it('varint_golden_uint32_150', 0, () => {
      const w = new ProtoWriter();
      w.writeUint32(1, 150);
      // tag=0x08 (field1,wire0), 150 = 0x96 0x01
      expect(toArray(w.finish())).assertDeepEquals([0x08, 0x96, 0x01]);
    });

    it('string_golden', 0, () => {
      const w = new ProtoWriter();
      w.writeString(2, 'testing');
      // tag=0x12 (field2,wire2), len=7
      expect(toArray(w.finish()))
        .assertDeepEquals([0x12, 0x07, 0x74, 0x65, 0x73, 0x74, 0x69, 0x6E, 0x67]);
    });

    it('fixed64_golden_little_endian', 0, () => {
      const w = new ProtoWriter();
      w.writeFixed64(1, 0x0102030405060708n);
      // tag=0x09 (field1,wire1), 小端 8 字节
      expect(toArray(w.finish()))
        .assertDeepEquals([0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]);
    });

    it('nested_message_golden', 0, () => {
      const inner = new ProtoWriter();
      inner.writeUint32(1, 1);
      const outer = new ProtoWriter();
      outer.writeMessage(3, inner);
      // tag=0x1A (field3,wire2), len=2, inner=[0x08,0x01]
      expect(toArray(outer.finish())).assertDeepEquals([0x1A, 0x02, 0x08, 0x01]);
    });

    it('bool_golden', 0, () => {
      const w = new ProtoWriter();
      w.writeBool(5, true);
      expect(toArray(w.finish())).assertDeepEquals([0x28, 0x01]);
    });

    it('int32_negative_roundtrip', 0, () => {
      // Steam 的 os_type 传 -500，必须按 64 位补码编成 10 字节 varint
      const w = new ProtoWriter();
      w.writeInt32(3, -500);
      const bytes = w.finish();
      expect(bytes.length).assertEqual(11); // tag(1) + 10 字节 varint
      const r = new ProtoReader(bytes);
      expect(r.next()).assertTrue();
      expect(r.field()).assertEqual(3);
      expect(r.readInt32()).assertEqual(-500);
    });

    it('uint64_large_roundtrip', 0, () => {
      // steamid 会超出 2^53，用 bigint 承载
      const steamid = 76561198000000000n;
      const w = new ProtoWriter();
      w.writeUint64(4, steamid);
      const r = new ProtoReader(w.finish());
      expect(r.next()).assertTrue();
      expect(r.readUint64()).assertEqual(steamid);
    });

    it('fixed64_steamid_roundtrip', 0, () => {
      const steamid = 76561197960287930n;
      const w = new ProtoWriter();
      w.writeFixed64(1, steamid);
      const r = new ProtoReader(w.finish());
      expect(r.next()).assertTrue();
      expect(r.wireType()).assertEqual(1);
      expect(r.readFixed64()).assertEqual(steamid);
    });

    it('float32_read_golden_1_0', 0, () => {
      // field3 wire5: tag=0x1D, 1.0f = 0x3F800000 → 小端 00 00 80 3F
      const r = new ProtoReader(Uint8Array.from([0x1D, 0x00, 0x00, 0x80, 0x3F]));
      expect(r.next()).assertTrue();
      expect(r.field()).assertEqual(3);
      expect(r.readFloat32()).assertEqual(1.0);
    });

    it('mixed_message_roundtrip', 0, () => {
      const details = new ProtoWriter();
      details.writeString(1, 'Authenticator');
      details.writeInt32(2, 3);
      details.writeInt32(3, -500);
      details.writeUint32(4, 528);

      const w = new ProtoWriter();
      w.writeString(2, 'account_name');
      w.writeString(3, 'ZW5jcnlwdGVk');
      w.writeUint64(4, 1788953926n);
      w.writeInt32(7, 1);
      w.writeMessage(9, details);
      w.writeUint32(11, 0);
      w.writeInt32(12, 2);

      const r = new ProtoReader(w.finish());
      let account = '';
      let timestamp = 0n;
      let osType = 0;
      let deviceName = '';
      let persistence = 0;
      let qos = 0;
      let seen = 0;
      while (r.next()) {
        switch (r.field()) {
          case 2: account = r.readString(); break;
          case 4: timestamp = r.readUint64(); break;
          case 7: persistence = r.readInt32(); break;
          case 9: {
            const d = r.readMessage();
            while (d.next()) {
              switch (d.field()) {
                case 1: deviceName = d.readString(); break;
                case 3: osType = d.readInt32(); break;
                default: d.skip(); break;
              }
            }
            break;
          }
          case 12: qos = r.readInt32(); break;
          default: r.skip(); break;
        }
        seen = seen + 1;
      }
      expect(seen).assertEqual(7);
      expect(account).assertEqual('account_name');
      expect(timestamp).assertEqual(1788953926n);
      expect(persistence).assertEqual(1);
      expect(deviceName).assertEqual('Authenticator');
      expect(osType).assertEqual(-500);
      expect(qos).assertEqual(2);
    });

    it('skip_unknown_field', 0, () => {
      const w = new ProtoWriter();
      w.writeUint32(1, 7);
      w.writeString(99, 'ignored');
      w.writeFixed64(100, 123n);
      w.writeUint32(2, 9);

      const r = new ProtoReader(w.finish());
      let first = 0;
      let second = 0;
      while (r.next()) {
        switch (r.field()) {
          case 1: first = r.readUint32(); break;
          case 2: second = r.readUint32(); break;
          default: r.skip(); break;
        }
      }
      expect(first).assertEqual(7);
      expect(second).assertEqual(9);
    });
  });
}
