import { TokenItem } from "../components/TokenItem";
import { AppPreference, TokenPreference, EVENT_NAMES } from "../utils/AppPreference";
import { TokenConfig } from "../utils/TokenConfig";
import { TokenStore } from "../utils/TokenStore";
import { GenericDataSource } from "../utils/GenericDataSource";
import { AppWindowInfo } from "../entryability/EntryAbility";
import { AppStorageV2 } from "@kit.ArkUI";
import { common } from "@kit.AbilityKit";
import { CommonConstants } from "../utils/CommonConstants";
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from "@kit.UIDesignKit";

let tkStore = TokenStore.getInstance();

@Preview
@ComponentV2
export struct TokenSortPage {
  @Require @Param scrollEffectType: ScrollEffectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;
  @Local window: AppWindowInfo = AppStorageV2.connect(AppWindowInfo) as AppWindowInfo;
  @Local tokens: TokenConfig[] = [];
  @Local dataSource: GenericDataSource<TokenConfig> = new GenericDataSource([]);
  @Local dragToken: TokenConfig | undefined = undefined;

  // 使用 AppStorage 获取 context
  private appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;
  private onTokenChangedHandler: () => void = () => {};

  aboutToAppear(): void {
    this.onTokenChangedHandler = () => this.loadTokens();
    this.appCtx.eventHub?.on(EVENT_NAMES.TOKEN_CHANGED, this.onTokenChangedHandler);
    this.loadTokens();
  }

  aboutToDisappear(): void {
    this.appCtx.eventHub?.off(EVENT_NAMES.TOKEN_CHANGED, this.onTokenChangedHandler);
  }

  private async loadTokens(): Promise<void> {
    this.tokens = await tkStore.getTokens();
    this.dataSource.updateData(this.tokens);
  }

  @Builder
  DragPreviewBuilder() {
    if (this.dragToken) {
      Column() {
        TokenItem({
          Config: this.dragToken,
          sortMode: true,
          Update: async (conf_new) => {
            await tkStore.updateToken(conf_new);
          }
        })
      }
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        List({ space: this.token_preference.app_appearance_item_space }) {
          // 顶部避让区域
          ListItem()
            .height(CommonConstants.AVOID_TOP_BASE_HEIGHT)

          LazyForEach(this.dataSource, (token: TokenConfig, index: number) => {
            ListItem() {
              TokenItem({
                Config: token,
                sortMode: true,
                Update: async (conf_new) => {
                  await tkStore.updateToken(conf_new);
                }
              })
            }
          }, (item: TokenConfig) => {
            return item.TokenUUID
          })

          // 底部安全区域
          ListItem()
            .height(80 + this.window.AvoidBottomHeight)
        }
        .alignListItem(ListItemAlign.Center)
        .lanes({ minLength: 400, maxLength: this.token_preference.app_appearance_item_max_width })
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onItemDragStart((event: ItemDragInfo, itemIndex: number): CustomBuilder => {
          this.dragToken = this.tokens[itemIndex];
          return () => { this.DragPreviewBuilder(); };
        })
        .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean): void => {
          if (isSuccess && itemIndex !== insertIndex) {
            const moved = this.tokens.splice(itemIndex, 1)[0];
            this.tokens.splice(insertIndex, 0, moved);
            this.dataSource.updateData(this.tokens);
            tkStore.updateTokenRank(itemIndex, insertIndex);
          }
        })
      }
      .backgroundColor($r('app.color.window_background'))
      .width('100%')
      .height('100%')
    }
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.icon_primary')
            }
          },
          backgroundStyle: {
            maskExtraHeight: 0
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            maskExtraHeight: 0
          }
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: this.scrollEffectType
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: {
          mainTitle: $r('app.string.token_sort_page_title'),
        },
      }
    })
  }
}
