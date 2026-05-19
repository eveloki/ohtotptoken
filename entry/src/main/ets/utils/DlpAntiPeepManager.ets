import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'DlpAntiPeepManager';

/**
 * 防窥保护管理器
 * 封装 DlpAntiPeep API 的完整生命周期管理
 */
export class DlpAntiPeepManager {
  private static instance: DlpAntiPeepManager;
  private isSubscribed: boolean = false;
  private hasShownMask: boolean = false;
  private onStatusChange?: (status: dlpAntiPeep.DlpAntiPeepStatus) => void;

  public static getInstance(): DlpAntiPeepManager {
    if (!DlpAntiPeepManager.instance) {
      DlpAntiPeepManager.instance = new DlpAntiPeepManager();
    }
    return DlpAntiPeepManager.instance;
  }

  /**
   * 检查当前设备是否支持防窥保护能力
   */
  public isSupported(): boolean {
    return canIUse('SystemCapability.Security.DlpAntiPeep');
  }

  /**
   * 检查当前应用是否已开启防窥保护开关
   */
  public async isSwitchOn(): Promise<boolean> {
    try {
      return await dlpAntiPeep.isDlpAntiPeepSwitchOn();
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(err.code, TAG, `isDlpAntiPeepSwitchOn failed. Code: ${err.code}, message: ${err.message}`);
      return false;
    }
  }

  /**
   * 启动防窥保护
   * @param windowClass 主窗口实例，用于获取 windowId 以拉起蒙层
   * @param context UIAbilityContext，用于 requestAntiPeepOptions 弹窗
   */
  public async start(windowClass: window.Window, context: common.UIAbilityContext): Promise<void> {
    if (!this.isSupported()) {
      hilog.warn(0x0000, TAG, 'Device does not support DlpAntiPeep, skip initialization.');
      return;
    }

    if (this.isSubscribed) {
      hilog.info(0x0000, TAG, 'DlpAntiPeep already subscribed, skip.');
      return;
    }

    try {
      const isOpen = await this.isSwitchOn();
      if (isOpen) {
        this.subscribe(windowClass);
      } else {
        // 开关未开启，弹窗引导用户设置
        const result = await dlpAntiPeep.requestAntiPeepOptions(context);
        hilog.info(0x0000, TAG, `requestAntiPeepOptions result: ${result}`);
        if (result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
            result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) {
          this.subscribe(windowClass);
        }
      }
    } catch (error) {
      const err = error as BusinessError;
      if (err.code === 1020600004) {
        hilog.warn(err.code, TAG, 'Facial recognition not set, cannot enable DlpAntiPeep.');
      } else {
        hilog.error(err.code, TAG, `Failed to start DlpAntiPeep. Code: ${err.code}, message: ${err.message}`);
      }
    }
  }

  /**
   * 订阅防窥保护通知
   */
  private subscribe(windowClass: window.Window): void {
    try {
      this.onStatusChange = (status: dlpAntiPeep.DlpAntiPeepStatus) => {
        this.handleStatusChange(status, windowClass);
      };
      dlpAntiPeep.on('dlpAntiPeep', this.onStatusChange);
      this.isSubscribed = true;
      hilog.info(0x0000, TAG, 'DlpAntiPeep subscribed successfully.');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(err.code, TAG, `Failed to subscribe DlpAntiPeep. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * 处理窥视状态变化
   */
  private handleStatusChange(status: dlpAntiPeep.DlpAntiPeepStatus, windowClass: window.Window): void {
    hilog.info(0x0000, TAG, `DlpAntiPeep status changed: ${status}`);
    if (status === dlpAntiPeep.DlpAntiPeepStatus.PASS) {
      // 无人窥视，恢复正常
    } else if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) {
      // 有人窥视，拉起系统蒙层
      if (!this.hasShownMask) {
        this.showMaskLayer(windowClass);
      }
    }
  }

  /**
   * 停止防窥保护（取消订阅）
   */
  public stop(): void {
    if (!this.isSubscribed) {
      return;
    }
    try {
      if (this.onStatusChange) {
        dlpAntiPeep.off('dlpAntiPeep', this.onStatusChange);
        this.onStatusChange = undefined;
      } else {
        dlpAntiPeep.off('dlpAntiPeep');
      }
      this.isSubscribed = false;
      this.hasShownMask = false;
      hilog.info(0x0000, TAG, 'DlpAntiPeep unsubscribed successfully.');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(err.code, TAG, `Failed to unsubscribe DlpAntiPeep. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * 拉起系统级防窥蒙层
   */
  private async showMaskLayer(windowClass: window.Window): Promise<void> {
    try {
      const windowId = windowClass.getWindowProperties().id;
      await dlpAntiPeep.setAntiPeepMaskLayer(windowId);
      this.hasShownMask = true;
      hilog.info(0x0000, TAG, 'Anti-peep mask layer shown.');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(err.code, TAG, `Failed to set mask layer. Code: ${err.code}, message: ${err.message}`);
    }
  }

  /**
   * 重置蒙层标志（页面重新进入时调用，确保能再次响应窥视事件）
   */
  public resetMaskFlag(): void {
    this.hasShownMask = false;
  }
}
