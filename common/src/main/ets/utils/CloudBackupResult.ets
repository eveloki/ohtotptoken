import { CloudBackupRecord } from './CloudBackupCrypto';

export enum CloudBackupFailureReason {
  NONE = 'NONE',
  NOT_READY = 'NOT_READY',
  NOT_SIGNED_IN = 'NOT_SIGNED_IN',
  IDENTITY_UNAVAILABLE = 'IDENTITY_UNAVAILABLE',
  BUSY = 'BUSY',
  CLEANUP_PENDING = 'CLEANUP_PENDING',
  INVALID_TARGET = 'INVALID_TARGET',
  READ_FAILED = 'READ_FAILED',
  WRITE_FAILED = 'WRITE_FAILED',
  FORMAT_INVALID = 'FORMAT_INVALID',
  DECRYPT_FAILED = 'DECRYPT_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  ICON_FAILED = 'ICON_FAILED',
  SYNC_FAILED = 'SYNC_FAILED',
  UNKNOWN = 'UNKNOWN',
}

export class CloudBackupActionResult {
  success: boolean = false;
  reason: CloudBackupFailureReason = CloudBackupFailureReason.NONE;
  partialFailure: boolean = false;
  localComplete: boolean = false;
  syncStartAccepted: boolean = false;
}

export function cloudBackupFailure(reason: CloudBackupFailureReason): CloudBackupActionResult {
  const result = new CloudBackupActionResult();
  result.reason = reason;
  return result;
}

export class CloudBackupHistoryResult {
  records: CloudBackupRecord[] = [];
  success: boolean = false;
  reason: CloudBackupFailureReason = CloudBackupFailureReason.NONE;
}
