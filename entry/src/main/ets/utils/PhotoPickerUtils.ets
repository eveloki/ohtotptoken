import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PhotoPickerUtils';

/**
 * 通过系统图库选择器(PhotoViewPicker)选择图片
 * @param maxSelectNumber 最大选择数量
 * @returns 选中图片的URI数组，取消或失败返回空数组
 */
export async function selectPhotos(maxSelectNumber: number): Promise<string[]> {
  try {
    const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    photoSelectOptions.maxSelectNumber = maxSelectNumber;

    const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const result: photoAccessHelper.PhotoSelectResult = await photoViewPicker.select(photoSelectOptions);

    if (!result || !result.photoUris || result.photoUris.length === 0) {
      return [];
    }
    return result.photoUris;
  } catch (e) {
    hilog.error(0x0000, TAG, 'selectPhotos error: ' + JSON.stringify(e));
    return [];
  }
}

/**
 * 将源文件复制到目标目录，按时间戳+扩展名生成文件名
 * @param srcUri 源文件URI
 * @param destDir 目标目录路径（不带前缀file://）
 * @returns 新文件的file://路径
 */
export async function copyFileToDir(srcUri: string, destDir: string): Promise<string> {
  const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
  const timestamp = Date.now();
  let fileName = '';
  const srcPath = srcUri.toLowerCase();
  if (srcPath.includes('.png')) {
    fileName = `icon_${timestamp}.png`;
  } else if (srcPath.includes('.jpg') || srcPath.includes('.jpeg')) {
    fileName = `icon_${timestamp}.jpg`;
  } else if (srcPath.includes('.svg')) {
    fileName = `icon_${timestamp}.svg`;
  } else if (srcPath.includes('.webp')) {
    fileName = `icon_${timestamp}.webp`;
  } else if (srcPath.includes('.bmp')) {
    fileName = `icon_${timestamp}.bmp`;
  } else if (srcPath.includes('.gif')) {
    fileName = `icon_${timestamp}.gif`;
  } else {
    fileName = `icon_${timestamp}.png`;
  }

  const destPath = destDir + '/' + fileName;
  fs.copyFileSync(srcFile.fd, destPath);
  fs.closeSync(srcFile.fd);
  return 'file://' + destPath;
}

/**
 * 图片尺寸信息
 */
interface ImageDimensions {
  width: number;
  height: number;
}

/**
 * 获取图片的宽高尺寸
 * 通过 fileIo.openSync 打开文件 -> image.createImageSource(fd) -> getImageInfo() 获取 ImageInfo.size
 * @param uri 图片文件URI
 * @returns 图片尺寸，非图片或读取失败返回null
 */
export async function getImageDimensions(uri: string): Promise<ImageDimensions | null> {
  try {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const imageSource: image.ImageSource = image.createImageSource(file.fd);
    const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
    const result: ImageDimensions = { width: imageInfo.size.width, height: imageInfo.size.height };
    await imageSource.release();
    fs.closeSync(file);
    return result;
  } catch (e) {
    hilog.error(0x0000, TAG, 'getImageDimensions error: ' + JSON.stringify(e));
    return null;
  }
}

/**
 * 将 PixelMap 打包为 PNG 并保存到目标目录
 * 通过 ImagePacker.packToData() 将 PixelMap 编码为 PNG ArrayBuffer，再写入文件
 * @param pm 要保存的 PixelMap（通常是裁剪后的结果）
 * @param destDir 目标目录路径
 * @returns 新文件的file://路径
 */
export async function savePixelMapToFile(pm: PixelMap, destDir: string): Promise<string> {
  const imagePackerApi = image.createImagePacker();
  const packOpts: image.PackingOption = { format: 'image/png', quality: 100 };
  const buffer: ArrayBuffer = await imagePackerApi.packToData(pm, packOpts);
  await imagePackerApi.release();

  const timestamp = Date.now();
  const fileName = `icon_${timestamp}.png`;
  const destPath = destDir + '/' + fileName;

  const file = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
  fs.writeSync(file.fd, buffer);
  fs.closeSync(file.fd);

  return 'file://' + destPath;
}
