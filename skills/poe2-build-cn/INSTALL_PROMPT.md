# 交给 Claude Code 命令行执行的提示词

把下面代码块里的全部内容复制进一个新的 Claude Code 会话。它是自包含的，不依赖任何上下文。

```
把本地技能 poe2-build-cn 安装到这台 Windows 机器的 Claude Code，然后提交并推送仓库里的待提交改动。

仓库路径：E:\poe2 plugin\poe2-build-repo

## 任务 1：安装技能

源文件：E:\poe2 plugin\poe2-build-repo\skills\poe2-build-cn\SKILL.md
目标：  %USERPROFILE%\.claude\skills\poe2-build-cn\SKILL.md

规则：
- 只做文件复制。不要改写、重排、精简、翻译或「优化」SKILL.md 的任何一个字。它是权威版本。
- 目标目录不存在就创建；目标文件已存在就覆盖。
- 仓库里已有 install.ps1 与 install.sh 两个现成脚本做这件事。直接调用其一，或自己敲等价命令，都可以。
  PowerShell: powershell -ExecutionPolicy Bypass -File "E:\poe2 plugin\poe2-build-repo\skills\poe2-build-cn\install.ps1"
  Git Bash:   bash "/e/poe2 plugin/poe2-build-repo/skills/poe2-build-cn/install.sh"

复制完成后必须逐条校验，任何一条不通过就立即停止并报告，不要自行修复内容：
1. 目标文件存在。
2. 行数为 272 行。
3. 字节数为 19790（LF 换行）或 20062（CRLF 换行）。其他数值视为失败。
4. 第 2 行正好是：name: poe2-build-cn
5. 文件内出现「武圣」，且不出现「武学家」。
6. 文件内存在标题行：### 4.1 先找硬阻断
7. 文件内存在标题行：## 第 4 步：识别硬阻断，再设计四层搜索正则

## 任务 2：提交并推送

在同一个仓库里执行，按顺序：

git -C "E:\poe2 plugin\poe2-build-repo" config core.quotepath false
git -C "E:\poe2 plugin\poe2-build-repo" status
git -C "E:\poe2 plugin\poe2-build-repo" add -A
git -C "E:\poe2 plugin\poe2-build-repo" commit -m "skill: 修正升华译名为武圣，增加本机安装脚本与安装提示词"
git -C "E:\poe2 plugin\poe2-build-repo" push origin main

预期待提交的改动是这几项，数量对不上就先报告再等我确认：
- 修改 README.md
- 修改 skills/poe2-build-cn/SKILL.md
- 新增 skills/poe2-build-cn/install.ps1
- 新增 skills/poe2-build-cn/install.sh
- 新增 skills/poe2-build-cn/INSTALL_PROMPT.md

约束：
- 不要新建分支，直接提交到 main。
- 不要执行 git reset、git checkout --、git clean、git rebase 或任何会丢弃工作区改动的命令。
- push 需要 GitHub 凭据。凭据一律由我本人输入，不要代填，也不要把凭据写进任何文件或命令行参数。push 失败就把错误原样贴出来，停下。

## 输出要求

用简体中文回复，专业名词后附英文。去掉寒暄与结尾套话。禁止使用「也许／可能／建议／或许」这类弱语气词。最后按这三段分别汇报：

1. 校验结果：7 条逐条列出通过或失败，附实测的行数与字节数。
2. git 结果：commit 的 SHA 与改动文件清单，push 是否成功。
3. 下一步：我需要重启 Claude Code 才能加载新技能；告诉我用哪条命令确认它已生效。
```

## 一次性非交互执行

不想开交互会话，用这一条（PowerShell）：

```powershell
claude -p "把 E:\poe2 plugin\poe2-build-repo\skills\poe2-build-cn\SKILL.md 原样复制到 %USERPROFILE%\.claude\skills\poe2-build-cn\SKILL.md，不要改写任何内容。复制后校验：272 行、第二行为 name: poe2-build-cn、包含『武圣』且不含『武学家』、包含标题 '### 4.1 先找硬阻断'。然后在 E:\poe2 plugin\poe2-build-repo 执行 git config core.quotepath false、git add -A、git commit -m 'skill: 修正升华译名为武圣，增加本机安装脚本' 并 push 到 origin main。不要建分支，不要执行任何丢弃工作区改动的命令，凭据由我本人输入。用简体中文汇报校验结果与 commit SHA。"
```
