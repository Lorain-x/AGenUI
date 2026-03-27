import { Context } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo as fs } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;
const TAG = 'ResourceCopyUtil';

/**
 * 将 rawfile 中的指定目录下所有文件拷贝到应用沙箱目录
 *
 * @param context      - Ability 上下文，用于访问 resourceManager 和 filesDir
 * @param rawfileDir   - rawfile 中的源目录名，例如 'ui_templates'
 * @param sandboxSubDir - 沙箱内的目标子路径，例如 'data/ui_templates'；不传则与 rawfileDir 同名
 * @returns 拷贝目标目录的沙箱绝对路径
 */
export async function copyRawfileDirToSandbox(
  context: Context,
  rawfileDir: string,
  sandboxSubDir?: string
): Promise<string> {
  const resourceManager = context.resourceManager;
  const targetSubDir = sandboxSubDir ?? rawfileDir;
  const sandboxTargetDir = `${context.filesDir}/${targetSubDir}`;

  // 确保目标目录存在（支持多级路径逐级创建）
  const parts = targetSubDir.split('/');
  let buildPath = context.filesDir;
  for (const part of parts) {
    if (part.length === 0) {
      continue;
    }
    buildPath = `${buildPath}/${part}`;
    if (!fs.accessSync(buildPath)) {
      fs.mkdirSync(buildPath);
      hilog.info(DOMAIN, TAG, 'Created sandbox directory: %{public}s', buildPath);
    }
  }

  // 获取 rawfile 目录下所有文件列表
  const fileList: string[] = resourceManager.getRawFileListSync(rawfileDir);
  hilog.info(DOMAIN, TAG, 'Found %{public}d files in rawfile/%{public}s', fileList.length, rawfileDir);

  for (const fileName of fileList) {
    const rawfilePath = `${rawfileDir}/${fileName}`;
    const sandboxFilePath = `${sandboxTargetDir}/${fileName}`;

    try {
      // 读取 rawfile 中的文件内容
      const rawfileContent: Uint8Array = resourceManager.getRawFileContentSync(rawfilePath);

      // 写入到沙箱目标路径
      const file = fs.openSync(sandboxFilePath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, rawfileContent.buffer);
      fs.closeSync(file);

      hilog.info(DOMAIN, TAG, 'Copied: %{public}s -> %{public}s', rawfilePath, sandboxFilePath);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to copy file %{public}s: %{public}s', rawfilePath, JSON.stringify(err));
    }
  }

  hilog.info(DOMAIN, TAG, 'All files copied to sandbox: %{public}s', sandboxTargetDir);
  return sandboxTargetDir;
}
