# 休息提醒

macOS 菜单栏小工具。到点后全屏置顶弹出一杯会冒热气的咖啡，提醒你离开屏幕休息一会儿。

适合长时间对着电脑写代码、改稿、看文档的时候用。

## 需要什么

- macOS（Apple Silicon 或 Intel 均可）
- 系统自带的 `swiftc`（安装过 Xcode 或 Command Line Tools 即可）

检查编译器：

```bash
swiftc --version
xcode-select -p
```

如果没有，先装命令行工具：

```bash
xcode-select --install
```

## 安装并开机自启

```bash
git clone https://github.com/lcdmast/rest-reminder.git
cd rest-reminder
chmod +x start.sh
./start.sh --install
```

这一步会：

1. 编译 `RestReminder.swift`
2. 把程序拷到 `~/Applications/RestReminder`
3. 写入登录项 `~/Library/LaunchAgents/com.local.rest-reminder.plist`

之后每次开机、每次登录，菜单栏右侧都会出现咖啡杯图标。点菜单里的「退出」只结束当前这次运行，下次开机仍会自动启动。

## 用法

点菜单栏咖啡杯：

| 菜单 | 作用 |
| --- | --- |
| 现在休息 | 立刻弹出提醒，方便看效果 |
| 提醒间隔 | 15 / 20 / 25 / 30 / 45 / 60 / 90 分钟，或自定义 1–180 分钟 |
| 推迟时长 | 点「推迟」后再等几分钟 |
| 暂停提醒 | 开会时先关掉，开完再继续 |
| 退出 | 退出当前进程 |

弹窗本身：

- 标题是「休息休息」，中间是动态冒热气的咖啡杯
- 「好，休息」或回车：关掉，按你设的间隔开始下一轮
- 「推迟 N 分钟」或 `Esc`：稍后再提醒

间隔和推迟时长会记在系统里，重启电脑不用重设。

## 常见命令

```bash
./start.sh              # 编译并运行（不装开机自启）
./start.sh --now        # 立刻弹一次
./start.sh --install    # 安装开机自启
./start.sh --uninstall  # 取消开机自启并删除 ~/Applications/RestReminder
./start.sh --interval 25 --snooze 5
```

`--interval` 只在这次启动时写入设置。日常改时间，直接点菜单栏更方便。

## 卸载

```bash
cd rest-reminder
./start.sh --uninstall
```

会取消登录项，并删掉 `~/Applications/RestReminder`。源码文件夹可以再手动删。

## 说明

- 源码只有一个文件：`RestReminder.swift`
- 开机自启走的是 macOS LaunchAgent，不需要把它拖进「系统设置 → 通用 → 登录项」
- 如果以后换了电脑或重新编译，再执行一次 `./start.sh --install` 即可
- 崩溃退出时 launchd 会自动再拉起；正常点「退出」不会反复重启

## License

个人使用，可自行修改。
