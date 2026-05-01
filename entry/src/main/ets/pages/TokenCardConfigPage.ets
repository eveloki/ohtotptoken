import { TokenConfig, otpType } from '../utils/TokenConfig';
import { TokenStore } from '../utils/TokenStore';
import { TokenCardStore, CardConfig } from '../utils/TokenCardStore';
import { formProvider, formBindingData } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { AppWindowInfo } from '../entryability/EntryAbility';
import { AppStorageV2 } from '@kit.ArkUI';

@Entry
@ComponentV2
export struct TokenCardConfigPage {
  pathStack: NavPathStack = new NavPathStack();
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local tokens: TokenConfig[] = [];
  @Local selectedUUIDs: string[] = [];
  @Local formId: string = '';
  @Local formName: string = 'tokenCard_1x2';
  @Local maxSelect: number = 1;

  aboutToAppear(): void {
    this.formName = AppStorage.get<string>('card_config_formName') ?? 'tokenCard_1x2';
    this.formId = AppStorage.get<string>('card_config_formId') ?? '';
    AppStorage.setOrCreate('card_config_formId', '');
    this.maxSelect = this.formName === 'tokenCard_2x2' ? 2 : 1;

    const tkStore = TokenStore.getInstance();
    tkStore.LoadTokenByDataBase().then(() => {
      tkStore.getTokens().then((tokens: TokenConfig[]) => {
        this.tokens = tokens;
      });
    });

    const cardStore = TokenCardStore.getInstance();
    cardStore.getCardConfig(this.formId).then((config: CardConfig | null) => {
      if (config) {
        this.selectedUUIDs = [...config.tokenUUIDs];
      }
    });
  }

  build() {
    NavDestination() {
      Column() {
        Text(`选择令牌 (最多${this.maxSelect}个)`)
          .fontSize(16)
          .fontColor($r('app.color.str_main'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16, top: 12, bottom: 8 })

        List({ space: 4 }) {
          ForEach(this.tokens, (token: TokenConfig) => {
            ListItem() {
              this.TokenItemBuilder(token)
            }
          }, (token: TokenConfig) => token.TokenUUID)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12 })

        Row() {
          Button('取消')
            .fontSize(16)
            .fontColor($r('app.color.str_gray'))
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.pathStack.pop();
            })

          Button('确认')
            .fontSize(16)
            .fontColor($r('app.color.white'))
            .backgroundColor($r('app.color.button_blue'))
            .enabled(this.selectedUUIDs.length > 0)
            .onClick(() => {
              this.saveAndRefresh();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .padding({ left: 24, right: 24, top: 12, bottom: 12 })
      }
      .width('100%')
      .height('100%')
    }
    .title('配置卡片令牌')
    .hideTitleBar(false)
    .margin({ top: this.window.AvoidTopHeight, bottom: this.window.AvoidBottomHeight})
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  TokenItemBuilder(token: TokenConfig) {
    Row() {
      SymbolGlyph($r('sys.symbol.key_fill'))
        .fontSize(20)
        .fontColor([$r('app.color.item_fg')])

      Column() {
        Text(token.TokenIssuer || token.TokenName)
          .fontSize(14)
          .fontColor($r('app.color.str_main'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (token.TokenIssuer && token.TokenName) {
          Text(token.TokenName)
            .fontSize(12)
            .fontColor($r('app.color.str_gray'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.selectedUUIDs.includes(token.TokenUUID)) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.card_selected_icon')])
      } else {
        SymbolGlyph($r('sys.symbol.circle'))
          .fontSize(22)
          .fontColor([$r('app.color.card_unselected_icon')])
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_item_bg'))
    .onClick(() => {
      const idx = this.selectedUUIDs.indexOf(token.TokenUUID);
      if (idx >= 0) {
        this.selectedUUIDs.splice(idx, 1);
      } else if (this.selectedUUIDs.length < this.maxSelect) {
        this.selectedUUIDs.push(token.TokenUUID);
      }
    })
  }

  private async saveAndRefresh(): Promise<void> {
    const cardConfig: CardConfig = {
      formId: this.formId,
      formName: this.formName,
      tokenUUIDs: [...this.selectedUUIDs],
    };

    const cardStore = TokenCardStore.getInstance();
    await cardStore.saveCardConfig(cardConfig);

    if (!this.formId) {
      hilog.error(0, 'TokenCardConfig', 'formId is empty, cannot update card');
      promptAction.showToast({ message: 'formId为空，无法更新卡片' });
      this.pathStack.pop();
      return;
    }

    try {
      const formData = await cardStore.generateCardData(this.formId, cardConfig);
      hilog.info(0, 'TokenCardConfig', `formData: ${JSON.stringify(formData)}`);
      const formBindingDataObj = formBindingData.createFormBindingData(formData);
      await formProvider.updateForm(this.formId, formBindingDataObj);
      hilog.info(0, 'TokenCardConfig', `updateForm success, formId: ${this.formId}`);
      promptAction.showToast({ message: '卡片更新成功' });
    } catch (err) {
      const errMsg = (err as BusinessError).message;
      hilog.error(0, 'TokenCardConfig', `updateForm error: ${errMsg}`);
      promptAction.showToast({ message: `卡片更新失败: ${errMsg}` });
    }

    this.pathStack.pop();
  }
}
