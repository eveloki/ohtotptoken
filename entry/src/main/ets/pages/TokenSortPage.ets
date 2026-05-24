import { TokenItem } from "../components/TokenItem";
import { AppPreference, TokenPreference, EVENT_NAMES } from "../utils/AppPreference";
import { TokenConfig } from "../utils/TokenConfig";
import { TokenStore } from "../utils/TokenStore";
import { GenericDataSource } from "../utils/GenericDataSource";
import { AppWindowInfo } from "../entryability/EntryAbility";
import { AppStorageV2, curves } from "@kit.ArkUI";
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

  // 拖拽排序状态
  @Local dragItem: string = "";          // 当前拖拽的 TokenUUID
  @Local scaleItem: string = "";         // 当前缩放的 TokenUUID
  @Local neighborUUID: string = "";      // 相邻项的 TokenUUID
  @Local neighborScale: number = 1;      // 相邻项的缩放比例
  @Local offsetY: number = 0;            // Y轴偏移量

  private dragRefOffset: number = 0;
  private sortListScroller: Scroller = new Scroller();

  // 使用 AppStorage 获取 context
  private appCtx: common.UIAbilityContext = AppStorage.get('appContext') as common.UIAbilityContext;
  private onTokenChangedHandler: () => void = () => {};

  @Computed
  get itemInterval(): number {
    return (this.token_preference.app_appearance_item_height as number) +
      (this.token_preference.app_appearance_item_space as number);
  }

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

  /** 根据当前 tokens 顺序重新分配 RankScore 并持久化 */
  private async persistFullOrder(): Promise<void> {
    for (let i = 0; i < this.tokens.length; i++) {
      this.tokens[i].RankScore = i;
      await tkStore.updateToken(this.tokens[i]);
    }
  }

  /** 根据 UUID 查找 token 的缩放比例 */
  scaleSelect(uuid: string): number {
    if (this.scaleItem === uuid) {
      return 1.05;
    } else if (this.neighborUUID === uuid) {
      return this.neighborScale;
    } else {
      return 1;
    }
  }

  /** 在数组中移动项目位置 */
  itemMove(fromIndex: number, toIndex: number): void {
    if (fromIndex < 0 || toIndex < 0 || fromIndex >= this.tokens.length || toIndex >= this.tokens.length) {
      return;
    }
    const tmp = this.tokens.splice(fromIndex, 1);
    this.tokens.splice(toIndex, 0, tmp[0]);
    this.dataSource.updateData(this.tokens);
  }

  build() {
    HdsNavDestination() {
      Column() {
        List({ space: this.token_preference.app_appearance_item_space, scroller: this.sortListScroller }) {
          // 顶部避让区域
          ListItem()
            .height(CommonConstants.AVOID_TOP_BASE_HEIGHT + this.window.AvoidTopHeight)

          ForEach(this.tokens, (token: TokenConfig, index: number) => {
            ListItem() {
              TokenItem({
                Config: token,
                sortMode: true,
                Update: async (conf_new) => {
                  await tkStore.updateToken(conf_new);
                }
              })
            }
            .draggable(false) // 不使用系统拖拽，使用自定义手势
            .shadow(this.scaleItem === token.TokenUUID ?
              { radius: 70, color: '#15000000', offsetX: 0, offsetY: 0 } :
              { radius: 0, color: '#15000000', offsetX: 0, offsetY: 0 })
            .animation({ curve: Curve.Sharp, duration: 300 })
            .scale({ x: this.scaleSelect(token.TokenUUID), y: this.scaleSelect(token.TokenUUID) })
            .zIndex(this.dragItem === token.TokenUUID ? 1 : 0)
            .translate(this.dragItem === token.TokenUUID ? { y: this.offsetY } : { y: 0 })
            .gesture(
              GestureGroup(GestureMode.Sequence,
                // 长按手势：触发缩放效果
                LongPressGesture({ repeat: true })
                  .onAction(() => {
                    this.getUIContext().animateTo({ curve: Curve.Friction, duration: 300 }, () => {
                      this.scaleItem = token.TokenUUID;
                    });
                  })
                  .onActionEnd(() => {
                    this.getUIContext().animateTo({ curve: Curve.Friction, duration: 300 }, () => {
                      this.scaleItem = "";
                    });
                  }),
                // 滑动手势：拖拽排序
                PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
                  .onActionStart(() => {
                    this.dragItem = token.TokenUUID;
                    this.dragRefOffset = 0;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    this.offsetY = event.offsetY - this.dragRefOffset;
                    this.neighborUUID = "";
                    // 通过 UUID 查找当前索引（避免闭包中 index 过期）
                    const currentIndex = this.tokens.findIndex(t => t.TokenUUID === token.TokenUUID);
                    if (currentIndex < 0) {
                      return;
                    }
                    const itemIntv = this.itemInterval;
                    const curveValue: ICurve = curves.initCurve(Curve.Sharp);
                    let value: number = 0;

                    // 根据位移计算相邻项的缩放
                    if (this.offsetY < 0) {
                      value = curveValue.interpolate(-this.offsetY / itemIntv);
                      if (currentIndex > 0) {
                        this.neighborUUID = this.tokens[currentIndex - 1].TokenUUID;
                      }
                      this.neighborScale = 1 - value / 20;
                    } else if (this.offsetY > 0) {
                      value = curveValue.interpolate(this.offsetY / itemIntv);
                      if (currentIndex < this.tokens.length - 1) {
                        this.neighborUUID = this.tokens[currentIndex + 1].TokenUUID;
                      }
                      this.neighborScale = 1 - value / 20;
                    }

                    // 根据位移交换排序
                    if (this.offsetY > itemIntv / 2) {
                      this.getUIContext().animateTo(
                        { curve: curves.interpolatingSpring(0, 1, 400, 38) }, () => {
                          this.offsetY -= itemIntv;
                          this.dragRefOffset += itemIntv;
                          this.itemMove(currentIndex, currentIndex + 1);
                        });
                    } else if (this.offsetY < -itemIntv / 2) {
                      this.getUIContext().animateTo(
                        { curve: curves.interpolatingSpring(0, 1, 400, 38) }, () => {
                          this.offsetY += itemIntv;
                          this.dragRefOffset -= itemIntv;
                          this.itemMove(currentIndex, currentIndex - 1);
                        });
                    }
                  })
                  .onActionEnd(() => {
                    this.getUIContext().animateTo(
                      { curve: curves.interpolatingSpring(0, 1, 400, 38) }, () => {
                        this.dragItem = "";
                        this.neighborUUID = "";
                      });
                    this.getUIContext().animateTo(
                      { curve: curves.interpolatingSpring(14, 1, 170, 17), delay: 150 }, () => {
                        this.scaleItem = "";
                      });
                    // 持久化排序
                    this.persistFullOrder();
                  })
              )
            )
          }, (item: TokenConfig, index: number) => {
            return `${item.TokenUUID}_${index}`;
          })

          // 底部安全区域
          ListItem()
            .height(24)
        }
        .alignListItem(ListItemAlign.Center)
        .lanes({ minLength: 400, maxLength: this.token_preference.app_appearance_item_max_width })
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .backgroundColor($r('app.color.window_background'))
      .width('100%')
      .height('100%')
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
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
    .bindToScrollable([this.sortListScroller])
  }
}
