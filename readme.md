# 《大圣劫天记》

基于 Godot 4.6.3 开发的 2D 横版动作游戏。

## 开发约定

- 当前开发分支：`feat/1.0`
- 设计基准：`doc/00_故事大纲.md` 至 `doc/06_素材清单.md`
- 开发路线：`doc/07_开发路线图.md`
- 最终验收：`doc/15_第七阶段验收清单.md`
- 玩法增强验收：`doc/16_玩法增强验收清单.md`
- 数值通过 Godot Resource（`.tres`）维护，场景和脚本不重复定义平衡参数

## 本地运行

使用 Godot 4.6.3 打开仓库根目录的 `project.godot`。命令行入口：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## 操作

- `A` / `D`：移动
- `S`：蹲下
- `K` / `空格`：跳跃、二段跳
- `J` 短按松开：空手三连击
- `J` 长按松开：蓄力攻击
- `J` + `K`：定身术
- `C` 短按：切换当前法宝
- `C` 长按：使用当前法宝
- `Esc`：暂停

暂停菜单可调节总音量、音乐、音效，并可开启“减少界面动画”。

## 自动测试

```bash
for phase in 01 02 03 04 05 06 07; do
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . "res://tests/run_phase_${phase}.tscn"
done
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_gameplay_polish.tscn
```

## macOS 构建

需要安装与 Godot 版本匹配的 4.6.3 导出模板：

```bash
mkdir -p builds
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug macOS builds/Havoc.app
```
