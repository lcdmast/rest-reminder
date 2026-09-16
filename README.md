# 专注休息

工作娱乐固重要，身体更重要。圣上保重龙体。

macOS 菜单栏小工具。在你设定的一周时段里，累计对着屏幕的时间；到点后全屏置顶弹出一杯会冒热气的咖啡，请你离开屏幕歇一歇。

锁屏、合盖、不在有效时段，都不计时。

## 需要什么

- macOS（Apple Silicon 或 Intel 均可）
- 系统自带的 `swiftc`（安装过 Xcode 或 Command Line Tools 即可）

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

会编译程序、拷到 `~/Applications/RestReminder`，并写入登录项。之后每次登录，菜单栏都会出现咖啡杯。

## 用法

点菜单栏咖啡杯：

| 菜单 | 作用 |
| --- | --- |
| 设置有效时段… | 按周一到周日，设定几点到几点才计时提醒 |
| 提醒间隔 | 15 / 20 / 25 / 30 / 45 / 60 / 90 分钟，或自定义 |
| 推迟时长 | 点「再忙片刻」后再等几分钟 |
| 现在休息 | 立刻弹出，方便看效果 |
| 暂停提醒 | 开会时先关掉 |
| 退出 | 退出当前进程 |

弹窗：

- 标题「圣上保重龙体」
- 中间是动态冒热气的咖啡杯，每次会轮换一条久坐看屏的坏处（眼睛、颈椎、腰椎、循环、代谢等）和此刻能做的动作
- 「已阅」或回车：关掉，按间隔开始下一轮
- 「再忙片刻」或 `Esc`：稍后再提醒

默认有效时段是工作日 9:00–22:00、周末 10:00–22:00。设置里还有快捷方案：工作日 9–22、每天 9–22、仅工作日白天。结束时间早于开始时间，表示跨过午夜，比如 22:00 到次日 2:00。

锁屏、合盖休眠或切换用户时会暂停计时，解锁后接着算剩下的时间。不在有效时段也不计时、不弹窗。

## 常见命令

```bash
./start.sh              # 编译并运行
./start.sh --now        # 立刻弹一次
./start.sh --install    # 安装开机自启
./start.sh --uninstall  # 取消开机自启
./start.sh --interval 25 --snooze 5
```

## 卸载

```bash
./start.sh --uninstall
```

## 说明

- 源码只有一个文件：`RestReminder.swift`
- 开机自启走 macOS LaunchAgent
- 崩溃退出时会自动再拉起；正常点「退出」不会反复重启

## License

个人使用，可自行修改。
