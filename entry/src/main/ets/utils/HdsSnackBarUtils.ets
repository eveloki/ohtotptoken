import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
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
import { common, ConfigurationConstant } from '@kit.AbilityKit';

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

const SnackBarIconColorMapLight: Record<SnackBarNotifyType, SymbolGlyphModifier> = {
  [SnackBarNotifyType.INFO]: new SymbolGlyphModifier().fontColor([Color.Blue]),
  [SnackBarNotifyType.WARNING]: new SymbolGlyphModifier().fontColor([Color.Orange]),
  [SnackBarNotifyType.ERROR]: new SymbolGlyphModifier().fontColor([Color.Red]),
  [SnackBarNotifyType.SUCCESS]: new SymbolGlyphModifier().fontColor([Color.Green])
};

const SnackBarIconColorMapDark: Record<SnackBarNotifyType, SymbolGlyphModifier> = {
  [SnackBarNotifyType.INFO]: new SymbolGlyphModifier().fontColor([0xFF8FD3FF]),
  [SnackBarNotifyType.WARNING]: new SymbolGlyphModifier().fontColor([0xFFFFC266]),
  [SnackBarNotifyType.ERROR]: new SymbolGlyphModifier().fontColor([0xFFFF8A8A]),
  [SnackBarNotifyType.SUCCESS]: new SymbolGlyphModifier().fontColor([0xFF7EE7A3])
};

let snackBar: HdsSnackBar | undefined;

function getUiContext(): UIContext | undefined {
  const windowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  return windowInfo.uiContext;
}

function getUiAbilityContext(): common.UIAbilityContext | undefined {
  const windowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  return windowInfo.Context;
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
  const abilityContext = getUiAbilityContext();
  if (!uiContext) {
    return;
  }

  if (!snackBar) {
    snackBar = new HdsSnackBar(uiContext);
  }

  const useDarkColors = abilityContext?.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  const iconOptions: SnackBarIconOptions = {
    icon: SnackBarIconMap[type],
    iconType: SnackBarIconType.SMALL,
    iconSymbolModifier: useDarkColors ? SnackBarIconColorMapDark[type] : SnackBarIconColorMapLight[type],
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
