# Typephone

Typephone turns an Apple Silicon Mac into a Bluetooth Low Energy keyboard for an iPhone or iPad.

Type on the Mac's physical keyboard and forward the keystrokes to the paired mobile device. Typephone supports mirroring input to both devices or sending it exclusively to the phone.

**Language:** English (default) · [简体中文](#中文说明)

> [!IMPORTANT]
> Typephone is currently an early-stage macOS utility for local development and real-device testing. Local builds are unsigned. A public distribution still requires Apple Developer signing and notarization.

## Highlights

- BLE HID over GATT Profile (HOGP) keyboard implemented with `CoreBluetooth`
- Letters, numbers, punctuation, navigation, keypad, function keys, and modifiers
- Off, mirror, and exclusive routing modes
- Ordered HID notification queue with per-characteristic backpressure handling
- Pairing-enforced encrypted HID input, output, and notifications
- Boot Keyboard and Report Protocol characteristics
- Caps Lock and other keyboard LED feedback from the connected device
- Automatic Bluetooth service rebuild after adapter resets
- Sleep/wake recovery and forced key release during lifecycle transitions
- Input Monitoring and Accessibility permission guidance
- Electron menu bar, control window, diagnostics, theme, and language settings
- Authenticated Electron-to-Swift control channel
- Emergency exit shortcut: `Control + Option + Command + Escape`

## Requirements

- Apple Silicon Mac
- macOS 13 or newer
- Bluetooth enabled
- Xcode with the macOS SDK
- Node.js 22 recommended
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- An iPhone or iPad for real BLE pairing and acceptance testing

Install XcodeGen with Homebrew:

```bash
brew install xcodegen
```

## Quick start

```bash
git clone https://github.com/VicZhang6/Typephone.git
cd Typephone
npm install
npm run dev
```

`npm run dev` performs the following work:

1. Stamps the current version metadata.
2. Generates the Xcode project from `project.yml`.
3. Builds the native Swift helper under `/tmp/MacInputDerived`.
4. Starts the Electron application.
5. Launches the native helper with an authenticated private control channel.

The native helper is intentionally unsandboxed because a global `CGEventTap` cannot provide the required capture and suppression behavior from an App Sandbox process.

## First run

### 1. Grant permissions

Typephone requests macOS permissions when a routing mode is enabled.

| Permission | Used for |
|---|---|
| Input Monitoring | Reading global keyboard events for mirror and exclusive modes |
| Accessibility / Post Event access | Suppressing Mac-side events in exclusive mode |
| Bluetooth | Advertising the Mac as a BLE HID keyboard |

After changing a permission in System Settings, return to Typephone and try enabling the routing mode again. Restarting the app may be necessary after macOS changes a privacy permission.

### 2. Pair the phone

1. Start Typephone. Advertising begins automatically when Bluetooth is ready.
2. On the iPhone or iPad, open **Settings → Bluetooth**.
3. Select **Typephone Keyboard**.
4. Wait until Typephone reports that the HID input characteristic is subscribed.
5. Open Notes or another text field on the mobile device.
6. Select a routing mode and type on the Mac keyboard.

If a previous development build was paired, forget the old **Typephone Keyboard** entry first and pair again.

## Routing modes

| Mode | Mac receives input | iPhone/iPad receives input | Notes |
|---|---:|---:|---|
| Off | Yes | No | Stops keyboard capture |
| Mirror | Yes | Yes | Useful for testing and demonstrations |
| Exclusive | No | Yes | Requires Input Monitoring and Accessibility permissions |

When entering exclusive mode, Typephone allows releases for keys that were already held before the mode switch to continue reaching macOS. This prevents stuck Mac-side keys and modifiers.

### Emergency exit

Press:

```text
Control + Option + Command + Escape
```

This immediately disables routing, sends an all-keys-up HID report, and stops suppressing Mac keyboard events.

The native helper also monitors its Electron parent. If Electron is force-quit or crashes, the helper disables capture and exits automatically.

## Architecture

```text
Mac keyboard
    │
    ▼
CGEventTap ──► RoutingController ──► KeyboardState ──► HIDReportQueue
                      │                                      │
                      │ mirror / exclusive                   ▼
                      └──────────────────────────────► CoreBluetooth
                                                             │
                                                             ▼
                                                       iPhone / iPad

Electron UI ── authenticated loopback JSON ──► Swift helper
```

The application is split into two processes:

- **Electron** owns the menu bar, window, settings, permission guidance, commands, status polling, and diagnostics UI.
- **Swift** owns `CoreBluetooth`, HOGP services, keyboard capture, permissions, sleep/wake handling, HID state, and report delivery.

### Control-channel security

The Electron and Swift processes communicate using newline-delimited JSON over loopback TCP. The channel is not exposed on a fixed port:

- Electron selects a random high port for every helper launch.
- Electron generates a random 256-bit authentication token.
- The port and token are passed through a private inherited pipe, not argv or environment variables.
- Every native request is authenticated before command dispatch.
- Requests larger than 64 KiB are rejected.
- The standalone native menu bar application does not start the Electron control server.

## Development commands

| Command | Purpose |
|---|---|
| `npm run dev` | Build the Debug helper and launch Electron |
| `npm run build:native` | Generate and build the Debug Swift application |
| `npm run build:native:release` | Build the Release Swift application under `build/native` |
| `npm run test:native` | Run the Swift/XCTest suite |
| `npm run check:js` | Check JavaScript syntax and run Node regression tests |
| `npm run start` | Start Electron using an already-built Debug helper |
| `npm run start:native` | Open the standalone Debug Swift menu bar application |
| `npm run dist:dir` | Build an unsigned macOS directory distribution |

## Testing

Run all standard checks:

```bash
npm run check:js
npm run test:native
```

The native tests cover HID reports, key-code mapping, keyboard state, routing transition state, queue ordering, backpressure, and a 5,000-report stress case.

The Node tests cover control-request field integrity. Optional process-level integration tests verify authentication and parent-death cleanup against a built helper:

```bash
MAC_INPUT_TEST_BINARY=/tmp/MacInputDerived/Build/Products/Debug/MacInput.app/Contents/MacOS/MacInput \
  node --test TestsJS/control-integration.test.js
```

Real BLE discovery, pairing, subscriptions, and keyboard delivery still require a physical iPhone or iPad.

## Build an unsigned app

```bash
npm run dist:dir
```

The resulting application is written to:

```text
dist/mac-arm64/Typephone.app
```

The Swift application is embedded at:

```text
Typephone.app/Contents/Resources/native/MacInput.app
```

Production distribution requires:

- An Apple Developer Team
- Signing the Electron application
- Signing the nested Swift helper with the appropriate distribution identity
- Hardened Runtime configuration compatible with the helper
- Notarization and stapling

The current GitHub Release workflow produces an unsigned directory artifact for development use.

## Versioning

Typephone separates the user-facing **Version Name** from the monotonically increasing **Build Number**.

| Field | Example | Updated when |
|---|---|---|
| Version Name | `1.3.0` | A formal patch, minor, or major release is created |
| Build Number | `258` | A CI, development, or release build is created |

The source of truth is [`version.json`](./version.json). Runtime display metadata is generated in `electron/shared/version-stamp.js`.

```bash
# Print current version information
npm run version:print

# Increment only the build number
npm run version:bump-build

# Create a formal version bump
npm run version:release -- patch  # patch, minor, or major

# Synchronize package.json, project.yml, and the runtime stamp
npm run version:stamp
```

CI uses `github.run_number` as the build number without changing the Version Name. The Release workflow can be triggered manually or from a `v*.*.*` tag.

## Repository layout

```text
electron/                 Electron main, preload, renderer, assets, and shared code
Sources/App/              Native application lifecycle and shared state
Sources/Bluetooth/        HOGP services, BLE peripheral, reports, and delivery queue
Sources/Input/            Keyboard capture, key mapping, routing, and state
Sources/System/           Control server, permissions, diagnostics, and sleep/wake
Sources/UI/               Native standalone menu bar UI
Tests/                    Swift/XCTest regression tests
TestsJS/                  Node control-channel and process integration tests
Resources/                Info.plist and native entitlements
project.yml               XcodeGen project definition
scripts/version.js        Version and build-number management
```

## Troubleshooting

### `xcodegen: command not found`

```bash
brew install xcodegen
```

### Native BLE service is offline

Build the native helper before starting Electron:

```bash
npm run build:native
npm run start
```

### The phone cannot find Typephone Keyboard

- Confirm Bluetooth is enabled on both devices.
- Stop and restart advertising from Typephone.
- Forget stale Typephone pairings on the phone.
- Restart Bluetooth on the Mac if CoreBluetooth recently reset.
- Use **Restart / Wait for pairing again** in the Typephone UI.

### Mirror or exclusive mode cannot be enabled

- Check Input Monitoring permission for the native **MacInput** helper.
- Exclusive mode also requires Accessibility permission.
- Restart Typephone after changing macOS privacy permissions.

### Keyboard input appears stuck

Use `Control + Option + Command + Escape`. If the Electron UI has crashed, the native parent watchdog should stop capture automatically. As a final fallback, quit the `MacInput --electron-helper` process or relaunch Typephone.

### Chinese input

Input method composition stays on the mobile device. Switch the iPhone or iPad to its Pinyin keyboard and send Latin HID usages from the Mac. Typephone does not transmit composed Mac IME text as Unicode.

## Real-device acceptance checklist

1. Pair a clean **Typephone Keyboard** entry.
2. Use **Send “a” to iPhone**.
3. Verify mirror and exclusive routing.
4. Verify left/right modifiers and switching modes while a modifier is held.
5. Verify long-press Delete and key repeat behavior.
6. Verify Caps Lock LED feedback.
7. Disconnect and reconnect the phone.
8. Sleep and wake the Mac.
9. Restart Mac Bluetooth and confirm services are rebuilt.
10. Force-quit Electron during exclusive mode and confirm the helper exits.
11. Run sustained typing and the 5,000-report queue stress test.

## Current limitations

- Apple Silicon only
- macOS 13 or newer
- One active BLE central at a time
- No signed/notarized public distribution yet
- No Unicode text injection; the phone controls its own keyboard layout and IME
- Real-device BLE acceptance cannot be fully automated in XCTest

---

## 中文说明

Typephone 可以把 Apple Silicon Mac 变成 iPhone 或 iPad 的蓝牙低功耗键盘。

你可以直接在 Mac 的实体键盘上输入，并把按键转发到已配对的移动设备；也可以选择让 Mac 和手机同时收到输入，或只发送到手机。

> [!IMPORTANT]
> 当前项目仍处于早期开发和真机测试阶段。本地构建未签名；正式发布还需要 Apple Developer 签名与 notarization 公证。

### 功能概览

- 基于 `CoreBluetooth` 实现 BLE HOGP 键盘
- 支持字母、数字、标点、导航键、小键盘、功能键和修饰键
- 支持关闭、镜像、独占三种输入模式
- 有序 HID 通知队列和按特征的背压重试
- HID 输入、输出和通知使用配对后加密链路
- 支持 Boot Keyboard 与 Report Protocol
- 支持 Caps Lock 等键盘 LED 状态反馈
- 蓝牙重置后自动重建服务，支持睡眠/唤醒恢复
- 提供输入监控、辅助功能权限引导
- 提供 Electron 菜单栏、控制窗口、诊断、主题和语言设置
- Electron 与 Swift 之间使用带鉴权的控制通道
- 紧急退出快捷键：`Control + Option + Command + Escape`

### 系统要求

- Apple Silicon Mac
- macOS 13 或更高版本
- 已开启蓝牙
- 安装带 macOS SDK 的 Xcode
- 推荐 Node.js 22
- XcodeGen
- 一台用于真实配对和验收的 iPhone 或 iPad

```bash
brew install xcodegen
```

### 快速开始

```bash
git clone https://github.com/VicZhang6/Typephone.git
cd Typephone
npm install
npm run dev
```

`npm run dev` 会依次完成：版本戳写入、Xcode 工程生成、Swift helper Debug 构建、Electron 启动，以及带鉴权私有控制通道的 native helper 启动。

native helper 有意保持非沙盒运行，因为全局 `CGEventTap` 无法在 App Sandbox 中提供所需的键盘捕获和抑制能力。

### 首次运行

#### 权限

| 权限 | 用途 |
|---|---|
| 输入监控 | 读取全局键盘事件，用于镜像和独占模式 |
| 辅助功能 / Post Event | 在独占模式下抑制 Mac 本地按键 |
| 蓝牙 | 将 Mac 广播为 BLE HID 键盘 |

修改系统权限后，回到 Typephone 再次启用输入模式；必要时重启应用。

#### 配对手机

1. 启动 Typephone，等待蓝牙就绪。
2. 在 iPhone/iPad 打开 **设置 → 蓝牙**。
3. 选择 **Typephone Keyboard**。
4. 等待 Typephone 显示 HID 输入特征已订阅。
5. 打开备忘录等文本输入界面。
6. 选择镜像或独占模式并开始输入。

如果旧开发版本留下了配对记录，请先在手机上忽略旧的 **Typephone Keyboard**，再重新配对。

### 输入模式

| 模式 | Mac 收到输入 | iPhone/iPad 收到输入 | 说明 |
|---|---:|---:|---|
| 关闭 | 是 | 否 | 停止键盘捕获 |
| 镜像 | 是 | 是 | 适合测试和演示 |
| 独占 | 否 | 是 | 需要输入监控和辅助功能权限 |

切入独占模式时，切换前已经按下的键会继续把 release 事件传给 macOS，避免 Mac 侧出现卡键或修饰键粘滞。

#### 紧急退出

按下：

```text
Control + Option + Command + Escape
```

这会立即关闭路由、向手机发送全键释放报告，并停止抑制 Mac 键盘事件。Electron 崩溃或被强制退出时，native helper 也会监控父进程并自动结束。

### 架构与安全

Electron 负责菜单栏、窗口、设置、权限引导、状态轮询和诊断界面；Swift 负责 `CoreBluetooth`、HOGP 服务、键盘捕获、权限、睡眠唤醒、HID 状态和报告发送。

两者通过 loopback TCP 上的换行 JSON 通信，但不会使用固定端口：

- 每次启动随机选择高位端口。
- 每次启动生成随机 256 位 token。
- 端口和 token 通过私有继承管道传递，不出现在 argv 或环境变量中。
- 每个 native 请求在执行前鉴权。
- 超过 64 KiB 的请求会被拒绝。
- standalone native 菜单栏程序不会启动 Electron 控制服务。

### 开发命令

| 命令 | 用途 |
|---|---|
| `npm run dev` | 构建 Debug helper 并启动 Electron |
| `npm run build:native` | 生成并构建 Debug Swift 应用 |
| `npm run build:native:release` | 构建 Release Swift 应用到 `build/native` |
| `npm run test:native` | 运行 Swift/XCTest 测试 |
| `npm run check:js` | 检查 JavaScript 并运行 Node 回归测试 |
| `npm run start` | 使用已构建的 Debug helper 启动 Electron |
| `npm run start:native` | 启动 standalone Debug Swift 菜单栏应用 |
| `npm run dist:dir` | 构建未签名 macOS 目录包 |

### 测试

```bash
npm run check:js
npm run test:native
```

Swift 测试覆盖 HID 报告、键码映射、键盘状态、路由切换状态、队列顺序、背压和 5,000 报告压力场景。真实蓝牙发现、配对、订阅和输入仍需要实体 iPhone/iPad。

可选的 helper 进程集成测试：

```bash
MAC_INPUT_TEST_BINARY=/tmp/MacInputDerived/Build/Products/Debug/MacInput.app/Contents/MacOS/MacInput \
  node --test TestsJS/control-integration.test.js
```

### 构建未签名应用

```bash
npm run dist:dir
```

输出路径：

```text
dist/mac-arm64/Typephone.app
```

Swift helper 位于：

```text
Typephone.app/Contents/Resources/native/MacInput.app
```

正式发布还需要 Apple Developer Team、Electron 和嵌套 Swift helper 的签名、兼容的 Hardened Runtime 配置，以及 notarization 公证。

### 版本管理

Typephone 将用户可见的 **Version Name** 与单调递增的 **Build Number** 分开管理。源文件是 [`version.json`](./version.json)，运行时信息由 `electron/shared/version-stamp.js` 生成。

```bash
npm run version:print
npm run version:bump-build
npm run version:release -- patch
npm run version:stamp
```

CI 使用 `github.run_number` 作为 Build Number，不自动修改 Version Name；Release workflow 支持手动触发或 `v*.*.*` 标签触发。

### 常见问题

#### `xcodegen: command not found`

```bash
brew install xcodegen
```

#### Native BLE 服务离线

```bash
npm run build:native
npm run start
```

#### 手机找不到 Typephone Keyboard

- 确认 Mac 和手机蓝牙都已开启。
- 在 Typephone 中停止后重新开始等待配对。
- 忽略手机上的旧配对记录。
- 如果 CoreBluetooth 刚刚重置，重启 Mac 蓝牙。

#### 无法开启镜像或独占模式

- 检查 native **MacInput** helper 的输入监控权限。
- 独占模式还需要辅助功能权限。
- 修改权限后重启 Typephone。

#### 键盘似乎卡住

使用 `Control + Option + Command + Escape`。如果 Electron 界面已经崩溃，helper 的父进程监控会自动停止捕获；最后可以手动结束 `MacInput --electron-helper` 或重新启动 Typephone。

#### 中文输入

输入法组合由手机端负责。请在 iPhone/iPad 切换到拼音键盘，Mac 只发送 Latin HID usages；Typephone 不会把 Mac 端 IME 组合结果作为 Unicode 文本传输。

### 真机验收清单

1. 清理旧配对并重新配对。
2. 使用 **Send “a” to iPhone**。
3. 验证镜像和独占模式。
4. 验证左右修饰键，以及按住修饰键切换模式。
5. 验证长按 Delete 和重复键。
6. 验证 Caps Lock LED 反馈。
7. 断开并重新连接手机。
8. 让 Mac 睡眠并唤醒。
9. 重启 Mac 蓝牙并确认服务重建。
10. 独占模式下强制退出 Electron，确认 helper 会自动结束。
11. 执行持续输入和 5,000 报告压力测试。

### 当前限制

- 仅支持 Apple Silicon
- 需要 macOS 13 或更高版本
- 同时只支持一个活动 BLE central
- 暂无签名/公证的正式发行包
- 不注入 Unicode 文本，手机负责键盘布局和输入法
- XCTest 无法完全自动化真机 BLE 验收

## License / 许可证

See [LICENSE](./LICENSE) and [NOTICE](./NOTICE). 详见 [LICENSE](./LICENSE) 与 [NOTICE](./NOTICE)。
