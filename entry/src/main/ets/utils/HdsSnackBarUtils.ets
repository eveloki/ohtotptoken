import { AppStorageV2 } from '@kit.ArkUI';
import {
  HdsSnackBar,
  SnackBarIconOptions,
  SnackBarIconType,
  SnackBarMessageOptions,
  SnackBarOperationOptions,
  SnackBarOperationType,
  SnackBarStyleOptions
} from '@kit.UIDesignKit';
import { AppWindowInfo } from '../entryability/EntryAbility';

export enum SnackBarNotifyType {
  INFO = 'INFO',
  WARNING = 'WARNING',
  ERROR = 'ERROR',
  SUCCESS = 'SUCCESS'
}

const SnackBarIconMap: Record<SnackBarNotifyType, ResourceStr | undefined> = {
  [SnackBarNotifyType.INFO]: $r('sys.symbol.info_circle'),
  [SnackBarNotifyType.WARNING]: $r('sys.symbol.exclamationmark_triangle'),
  [SnackBarNotifyType.ERROR]: $r('sys.symbol.xmark_circle'),
  [SnackBarNotifyType.SUCCESS]: $r('sys.symbol.checkmark_circle')
};

let snackBar: HdsSnackBar | undefined;

function getUiContext(): UIContext | undefined {
  const windowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  return windowInfo?.uiContext;
}

export interface SnackBarNotifyOptions {
  title?: ResourceStr;
  duration?: number;
}

export function showSnackBar(
  message: ResourceStr,
  type: SnackBarNotifyType = SnackBarNotifyType.INFO,
  options: SnackBarNotifyOptions = {}
): void {
  const uiContext = getUiContext();
  if (!uiContext) {
    return;
  }

  if (!snackBar) {
    snackBar = new HdsSnackBar(uiContext);
  }

  const iconOptions: SnackBarIconOptions = {
    icon: SnackBarIconMap[type],
    iconType: SnackBarIconType.SMALL
  };

  const messageOptions: SnackBarMessageOptions = {
    content: message
  };

  if (options.title) {
    messageOptions.title = options.title;
  }

  const operationOptions: SnackBarOperationOptions = {
    operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY
  };

  const styleOptions: SnackBarStyleOptions | undefined = options.duration !== undefined
    ? { duration: options.duration }
    : undefined;

  snackBar.show(iconOptions, messageOptions, operationOptions, styleOptions);
}
