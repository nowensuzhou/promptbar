# 提示语快捷插入和管理【秘籍】

一款原生 macOS 菜单栏应用，用全局快捷键快速搜索并插入常用短语。

![提示语快捷插入和管理【秘籍】设置界面](docs/screenshots/settings.png)

## 功能

- 按 `⌘⇧Space` 呼出快捷短语面板
- 鼠标单击或上下方向键选择，按回车插入
- 支持搜索当前分类中的短语
- 分类和短语均支持新建、编辑、删除
- 在设置窗口中双击短语会立即插入到最近使用的应用
- 设置窗口中选中短语后，可点击“插入”发送到最近使用的应用
- 快捷面板会自动插入到你按快捷键前正在使用的应用
- 自动保存到 `~/Library/Application Support/QuickInsert/shortcuts.json`
- 插入后自动恢复原剪贴板内容

## 安装

构建后双击 `build/QuickInsert-1.0.0.dmg`，将应用拖到“应用程序”文件夹，然后打开应用。

应用会显示 Dock 图标，双击或再次启动时会自动打开设置窗口。菜单栏中也会创建“插”图标；如果菜单栏图标过多，macOS 可能暂时不显示它，此时仍可使用 Dock 图标或 `⌘⇧Space`。

如果 macOS 提示“无法验证开发者”，可在“系统设置 > 隐私与安全性”中点击“仍要打开”，或对 `.app` 执行：

```bash
xattr -dr com.apple.quarantine /Applications/QuickInsert.app
```

本机构建使用固定 `com.quickinsert.mac` 标识的临时签名。在辅助功能中完成一次授权后，正常更新不应再要求重新授权；如果手动重新打包时签名要求变化，仍需重新允许。

第一次插入时，需要在：

`系统设置 > 隐私与安全性 > 辅助功能`

中允许“提示语快捷插入和管理【秘籍】”。这是 macOS 用来向其他应用发送粘贴快捷键所必需的权限。

如果之前已允许过权限，但更新或重新安装后仍无法插入，请在辅助功能列表中先移除旧记录，再重新添加一次。

## 从源码构建

当前构建脚本使用 macOS Command Line Tools 自带的 Swift 编译器，目标为 Apple Silicon Mac、macOS 14.0 及以上：

```bash
./Scripts/build.sh
```

产物位于 `build/`：

- `QuickInsert.app`
- `QuickInsert-1.0.0.dmg`
- `QuickInsert-1.0.0.pkg`
- `QuickInsert-1.0.0.zip`

构建使用本机临时签名，适合个人安装和测试；正式分发前需要使用 Apple Developer 证书签名并完成 notarization。

## 开源协议

本项目基于 [MIT License](LICENSE) 发布。
