# archtools

Arch Linux 包管理 TUI 工具集，统一 Pacman / AUR / Flatpak 三个源。

## 安装

```bash
git clone https://github.com/tingfeng347/archtools.git
cd archtools
bash install.sh
```

或者一键：

```bash
curl -fsSL https://raw.githubusercontent.com/tingfeng347/archtools/main/install.sh | bash
```

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/tingfeng347/archtools/main/uninstall.sh | bash
```

或者在源码目录运行：

```bash
bash uninstall.sh
```

## 命令

| 命令 | 用途 | 源 |
|------|------|-----|
| `pack` | 搜索并安装软件包 | Pacman / AUR / Flatpak |
| `pacr` | 搜索并卸载软件包 | Pacman / AUR / Flatpak |
| `pacd` | 搜索并降级已安装软件包 | Pacman / AUR |

## 用法

### pack - 安装

```bash
pack                  # 打开 TUI，搜索所有源
pack firefox          # 搜索 firefox
pack -e firefox       # 关闭模糊匹配，精确匹配
pack -y               # 强制刷新 AUR 缓存
pack -c               # 仅审查 AUR 包，不安装
pack --ai-model opencode/xxx  # 指定 AI 审查模型
```
- 注意：第一次启动比较慢，请稍微等待一下

### pacr - 卸载

```bash
pacr                  # 打开 TUI，卸载已安装包
pacr firefox          # 搜索并卸载 firefox
pacr -e firefox       # 关闭模糊匹配
pacr -y               # 在后台强制重建列表缓存
```

### pacd - 降级

```bash
pacd                  # 打开 TUI，降级已安装包
pacd linux            # 搜索并降级 linux 内核
pacd -e linux         # 关闭模糊匹配
pacd -y               # 在后台强制重建列表缓存
```

## 热键

| 键 | 功能 |
|----|------|
| `Tab` | 多选 |
| `Enter` | 确认安装/卸载/降级 |
| `Ctrl+R` | 刷新列表 |
| `Ctrl+E` | 切换精确匹配/模糊匹配 |
| `Esc` | 退出 |

## 快速启动缓存

`pack`、`pacr` 与 `pacd` 会把最终的软件包列表缓存在 `~/.cache/pac_tui/`。再次启动时会立即显示上一次的列表，
并在 TUI 内后台更新数据；刷新完成后列表会自动替换，不会阻塞首屏。

- `Ctrl+R`：`pack` 强制刷新 AUR 与 Flatpak 远程数据；`pacr`、`pacd` 强制重建当前已安装软件包列表。
- `pack -y`：启动后在后台强制刷新 AUR 缓存。
- `pacr -y`、`pacd -y`：启动后在后台强制重建当前已安装软件包列表缓存。
- 网络不可用时继续使用已有缓存，不影响打开 TUI。

## AI 安全审查

安装 AUR 包前，`pack` 会询问是否调用 `opencode` 对 `PKGBUILD` 进行安全审查：

- 🟢 低风险：默认继续安装
- 🟡 中风险：默认取消安装
- 🔴 高风险：默认取消安装

审查提示词位于 `/usr/share/archtools/prompts/aur-review.md`。

环境变量 `PAC_OPENCODE_MODEL` 可指定默认审查模型，或在审查提示中按 `m` 交互式选择。

## 颜色标识

| 颜色 | 源 |
|------|-----|
| 蓝色 | 官方源 (Pacman core/extra/multilib 等) |
| 紫色 | AUR |
| 青色 | Flatpak |

## 依赖

- **必需**: `fzf`
- **AUR 助手**: `paru` (推荐) 或 `yay`
- **可选**: `flatpak` (对应源自动检测)、`downgrade` (pacd 降级功能)
- **可选**: `opencode` (pack 的 AUR AI 安全审查，未安装时自动降级跳过)

```bash
# 必需
sudo pacman -S fzf

# AUR 助手（推荐 paru，install.sh 会自动引导安装）
sudo pacman -S base-devel git
# 然后从 AUR 安装 paru

# 可选
sudo pacman -S flatpak          # pack/pacr 的 Flatpak 源
sudo pacman -S downgrade        # pacd 降级（位于 AUR）
# opencode                      # pack 的 AUR AI 审查功能
```
https://github.com/SHORiN-KiWATA
# 鸣谢
*排名不分先后*
- [Shorin](https://github.com/SHORiN-KiWATA) 

## 项目引用
- [shorin-arch-setup](https://github.com/SHORiN-KiWATA/shorin-arch-setup)
