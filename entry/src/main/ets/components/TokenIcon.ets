import { ConfigurationConstant } from "@kit.AbilityKit";
import { TokenIconPacks } from "../utils/TokenUtils";
import { fileIo } from "@kit.CoreFileKit";
import { TokenPreference } from "../utils/AppPreference";
import { AppStorageV2 } from "@kit.ArkUI";

@Preview
@ComponentV2
export struct TokenIcon {
  @Require @Param issuer: string = '';
  @Param icon_path: string = '';
  @Param bypassColorFilter: boolean = false;
  @Local icon: ResourceStr | undefined = this.getIconResourceStr(TokenIconPacks.getIconByIssuer(this.issuer));
  @Local applyColorFilter: boolean = this.bypassColorFilter ? false : TokenIconPacks.selected_icon_pack === 0;

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;

  @Monitor("issuer")
  onStrChange(monitor: IMonitor) {
    monitor.dirty.forEach((path: string) => {
      this.refreshIcon((monitor.value(path)?.now as string).trim());
    });
  }

  @Monitor("icon_path")
  onIconPathChange(monitor: IMonitor) {
    monitor.dirty.forEach((path: string) => {
      this.refreshIcon(this.issuer, (monitor.value(path)?.now as string).trim());
    });
  }

  refreshIcon(issuer: string, path: string = ''): void {
    this.icon = this.getIconResourceStr(TokenIconPacks.getIconByIssuer(issuer), path);
  }

  validateUri(uri: string): ResourceStr | undefined {
    if (uri === undefined) {
      return undefined;
    }
    if (uri.length < 10) {
      return undefined;
    }
    if (uri.startsWith('rawfile://')) {
      return $rawfile(uri.slice(10));
    }
    if (!fileIo.accessSync(uri.slice(7))){
      return undefined;
    }
    return uri;
  }

  getIconResourceStr(uri: string, path: string = ''): ResourceStr | undefined {
    if (path === '') {
      path = this.icon_path;
    }
    if (path !== '' && path !== undefined) {
      return this.validateUri(this.icon_path);
    }
    return this.validateUri(uri);
  }

  onIconPackChanged(): void {
    this.applyColorFilter = this.bypassColorFilter ? false : TokenIconPacks.selected_icon_pack === 0;
    this.refreshIcon(this.issuer);
  }

  aboutToAppear(): void {
    this.refreshIcon(this.issuer);
    getContext(this).eventHub.on('onIconPackChanged', () => this.onIconPackChanged());
  }

  stringToColor(str: string): string {
    let hash: number = 0;
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }

    let color: string = "#";
    for (let i = 0; i < 3; i++) {
      const value: number = (hash >> (i * 8)) & 0xff;
      const hex: string = "00" + value.toString(16);
      color += hex.substring(hex.length - 2);
    }

    return color;
  }

  build() {
    Stack() {
      if (this.token_preference.app_appearance_logo_background) {
        Shape() {}
        .align(Alignment.Center)
        .backgroundColor(this.token_preference.app_appearance_logo_background_color)
        .height(this.token_preference.app_appearance_logo_background_size)
        .width(this.token_preference.app_appearance_logo_background_size)
        .borderRadius(this.token_preference.app_appearance_logo_background_radius)
      }
      if (this.icon === undefined) {
        Shape() {
          Text(this.issuer.charAt(0).toUpperCase() )
            .fontWeight(FontWeight.Bold)
            .fontSize(26)
            .fontColor(0xFFFFFF)
            .textAlign(TextAlign.Center)
            .height(this.token_preference.app_appearance_logo_size)
            .width(this.token_preference.app_appearance_logo_size)
        }
        .backgroundColor(this.stringToColor(this.issuer))
        .height(this.token_preference.app_appearance_logo_size)
        .width(this.token_preference.app_appearance_logo_size)
        .borderRadius(20)
      } else {
        if (
          this.token_preference.app_appearance_logo_dark_filter &&
          this.applyColorFilter && AppStorage.get<number>('currentColorMode') === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
          Image(this.icon)
            .height(this.token_preference.app_appearance_logo_size)
            .width(this.token_preference.app_appearance_logo_size)
            .fillColor(this.token_preference.app_appearance_logo_dark_filter_color)
            .objectFit(ImageFit.Contain)
        } else {
          Image(this.icon)
            .height(this.token_preference.app_appearance_logo_size)
            .width(this.token_preference.app_appearance_logo_size)
            .objectFit(ImageFit.Contain)
        }
      }
    }
  }
}