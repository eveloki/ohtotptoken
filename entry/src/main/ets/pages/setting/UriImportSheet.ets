import { AppStorageV2 } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { AppWindowInfo, TokenConfig, ScanBarCode, parseOtpAuthUris, readFileContent,
  showSelectFilePicker, showSnackBar, SnackBarNotifyType } from 'common';
import { MaterialTheme } from '../../components/MaterialTheme';
import { TokenBatchOperation } from '../../utils/TokenBatchOperation';
import { TokenProgressDialog, TokenProgressDialogParams } from '../../dialogs/TokenProgressDialog';
import { TokenImportHandler } from '../../utils/BackupImportOperation';
import { AddTokenActionButton, ADD_TOKEN_PAGE_INSET, ADD_TOKEN_BOTTOM_ACTION_INSET } from '../../components/AddTokenForm';

@ComponentV2
export struct UriImportSheet {
  @Require @Param scrollEffectStyle: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Event backupReload: TokenImportHandler = async () => {};
  @Event onVisibilityChange: (visible: boolean) => void = () => {};
  @Local uriText: string = '';
  @Local isReading: boolean = false;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;

  private pageInfos: NavPathStack | null = null;

  private appendText(value: string): void {
    if (value.trim() !== '') {
      this.uriText = this.uriText.trimEnd() === '' ? value : `${this.uriText.trimEnd()}\n${value}`;
    }
  }

  private async selectFile(): Promise<void> {
    if (this.isReading) {
      return;
    }
    this.isReading = true;
    try {
      const uris = await showSelectFilePicker(1, ['Text File|.txt,.json']);
      if (uris.length > 0 && uris[0] !== '') {
        this.appendText(await readFileContent(uris[0]));
      }
    } catch (_) {
      showSnackBar($r('app.string.uri_import_file_failed'), SnackBarNotifyType.ERROR);
    } finally {
      this.isReading = false;
    }
  }

  private async scanCode(): Promise<void> {
    if (this.isReading) {
      return;
    }
    this.isReading = true;
    try {
      this.appendText(await ScanBarCode());
    } catch (error) {
      if ((error as BusinessError).code !== 1000500002) {
        showSnackBar($r('app.string.toast_scan_failed'), SnackBarNotifyType.ERROR);
      }
    } finally {
      this.isReading = false;
    }
  }

  private async submit(): Promise<void> {
    if (this.isReading || TokenBatchOperation.isBusy() || this.uriText.trim() === '') {
      return;
    }
    const tokens = parseOtpAuthUris(this.uriText.split('\n').map((line: string) => line.trim()));
    if (tokens.length === 0) {
      showSnackBar($r('app.string.uri_import_invalid'), SnackBarNotifyType.ERROR);
      return;
    }
    this.isReading = true;
    try {
      await TokenBatchOperation.run(this, $r('app.string.token_batch_import_title'),
        async (report) => { await this.backupReload(tokens, report); });
      showSnackBar($r('app.string.toast_multi_token_update', tokens.length), SnackBarNotifyType.SUCCESS);
      this.pageInfos?.pop();
    } catch (_) {
      // 保存失败保留 URI 输入，允许用户重试，不能直接退回上级页面。
      showSnackBar($r('app.string.token_batch_import_failed'), SnackBarNotifyType.ERROR);
    } finally {
      this.isReading = false;
    }
  }

  @Builder
  buildTokenProgressDialog(params: TokenProgressDialogParams) {
    TokenProgressDialog({ params: params })
  }

  build() {
    HdsNavDestination() {
      Column({ space: 16 }) {
        Text($r('app.string.tab_token_add_uri_desc'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        TextArea({ placeholder: $r('app.string.tab_token_add_uri_desc'), text: this.uriText })
          .id('uri_import_input')
          .accessibilityText($r('app.string.tab_token_add_uri_title'))
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .width('100%')
          .layoutWeight(1)
          .onChange((value: string) => this.uriText = value)
        AddTokenActionButton({
          text: $r('app.string.dialog_btn_confirm'),
          buttonEnabled: this.uriText.trim() !== '' && !this.isReading,
          loading: this.isReading,
          action: () => this.submit()
        })
      }
      .width('100%')
      .height('100%')
      .padding({
        left: ADD_TOKEN_PAGE_INSET,
        right: ADD_TOKEN_PAGE_INSET,
        top: 16,
        bottom: Math.max(ADD_TOKEN_BOTTOM_ACTION_INSET, this.window.AvoidBottomHeight)
      })
    }
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .titleBar({
      enableComponentSafeArea: true,
      style: {
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            backIconStyle: { iconColor: $r('sys.color.icon_primary') },
            menuStyle: { iconColor: $r('sys.color.icon_primary') }
          }
        },
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: this.scrollEffectStyle },
        systemMaterialEffect: {
          materialType: MaterialTheme.hdsMaterialType(),
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: { mainTitle: $r('app.string.tab_token_add_uri_title') },
        menu: {
          value: [{
            content: {
              label: $r('app.string.uri_import_file'),
              icon: $r('sys.symbol.folder'),
              isEnabled: !this.isReading,
              action: () => this.selectFile()
            }
          }, {
            content: {
              label: $r('app.string.app_scan_code'),
              icon: $r('sys.symbol.qrcode'),
              isEnabled: !this.isReading,
              action: () => this.scanCode()
            }
          }]
        }
      }
    })
    .onBackPressed(() => this.isReading)
    .onShown(() => this.onVisibilityChange(true))
    .onHidden(() => this.onVisibilityChange(false))
    .onWillDisappear(() => this.onVisibilityChange(false))
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
  }
}
