# 《大圣劫天记》

基于 Godot 4.6.3 开发的 2D 横版动作游戏。

## 开发约定

- 当前开发分支：`feat/1.0`
- 设计基准：`doc/00_故事大纲.md` 至 `doc/06_素材清单.md`
- 开发路线：`doc/07_开发路线图.md`
- 当前阶段验收：`doc/08_第一阶段验收清单.md`
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
- `J`：空手三连击
- `J` + `K`：定身术
- `Esc`：暂停

## 第一阶段自测

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/run_phase_01.tscn
```
