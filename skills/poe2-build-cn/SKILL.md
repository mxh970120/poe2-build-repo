---
name: poe2-build-cn
description: 把一个 mobalytics.gg 的流亡黯道 2 构筑链接转成简体中文专属攻略网页，逐变体生成，写进 poe2-build-repo 并走 git 分支合并流程。
---

# PoE2 构筑中文化

输入是一个 mobalytics.gg 构筑链接，例如
`https://mobalytics.gg/poe-2/builds/martial-artist-league-starter-build`。

输出是 `E:\poe2 plugin\poe2-build-repo` 里的一批静态网页，每个变体一页，全部简体中文并附英文原名，最后走分支合并推到 GitHub。

## 硬性约束

- **中英对照只认 poe2db.tw 的 `/cn/` 与 `/us/` 页面。** 不用暗黑核（d2core），它的词缀翻译表是繁中台服口径（「增加 X% Y」「冰冷」），与简中客户端（「Y 提高 X%」「冰霜」）系统性对不上。poe2db 的 `/cn/` 已用实物物品名反向验证过与简中客户端一致。
- **不要用 WebFetch 或 curl 抓 pathofexile.com。** 它有人机验证，只能在浏览器里用同源 `fetch` 取。
- **不要逐件点击 Mobalytics 的装备。** 整页数据在 `window.__PRELOADED_STATE__` 里，一次全拿。
- 每一步都先跑 TaskCreate 建任务列表。

## 第 0 步：环境自检

1. `get_device_info` 确认 `E:\poe2 plugin\poe2-build-repo` 在 `connectedFolders` 里；不在就 `device_request_folder_access` 申请。
2. 检查工具列表里有没有 `mcp__remote-devices__device_bash`。
   - **有**：git 环节自己跑。
   - **没有**：git 环节只输出命令清单交给用户手动执行，并在最后明确说明「文件已写入，git 未执行」。
3. `device_list_dir` 看仓库现状：有没有 `.git`、有没有已存在的同名文件夹（同名就是更新而不是新建）。
4. 读 `.git/config`（`device_stage_files` 取回）拿到 remote 与默认分支。当前已知：remote `https://github.com/mxh970120/poe2-build-repo`，分支 `main`。

## 第 1 步：抓取 Mobalytics 结构化数据

用 Claude in Chrome 打开构筑页，等 3 秒，然后用 `javascript_tool` 取数据。**所有数据都在一个全局对象里，不需要点击任何装备。**

定位方法（路径会随版本变，用遍历而不是写死）：

```js
const S = window.__PRELOADED_STATE__;
let BV = null;
(function walk(o, d){ if (BV || !o || typeof o !== 'object' || d > 12) return;
  for (const k of Object.keys(o)) { if (k === 'buildVariants') { BV = o[k]; return } walk(o[k], d+1) } })(S, 0);
const variants = BV.values;   // 变体数组，顺序与页面选择器一致
```

变体名不在这个对象里，要从 DOM 的变体选择器取，**按顺序与 `variants` 下标一一对应**：

```js
const names = [...document.querySelectorAll('*')]
  .filter(e => e.children.length === variants.length &&
    [...e.children].every(c => { const t = c.textContent.trim(); return t.length > 2 && t.length < 60 }))
  .map(e => [...e.children].map(c => c.textContent.replace(/\s+/g,' ').trim()))[0];
```

**必须做一次对位校验**：镜像级变体（Mirror Tier）一定带 Mageblood、Kalandra's Touch、Voices 这类顶级传奇；开荒变体（Act 1）装备槽明显更少且没有 `chakras`。对不上就说明顺序错了，改用手动点击选择器逐个读。

每个变体的字段：

| 字段 | 内容 |
|---|---|
| `equipment.<槽位>.set1.commonItem` | `name` 底材英文名、`itemClassSlug`、`isUnique`、`explicitDescriptions[].description` 目标词缀英文文本、`.mustHave` 是否必须、`prefixes[]`／`suffixes[]` 词缀 slug、`poe2TradeRequest.query` 完整交易站查询 JSON |
| `equipment.<槽位>.set1.runes[]` | 该部位插的符文／灵魂核心 slug |
| `equipment.<槽位>.anointment` | 涂油（液化情感）配方 |
| `equipment.chakras[]` | 升华「符纹经络」给的额外符文槽内容，与部位无关 |
| `equipment.priorityList[]` | 装备购买优先级，带 `notes`（作者的部位注释，很多正文里没写） |
| `skillGems.gems[]` | `activeSkill{name, level}` 主动技能 + `subSkills[]` 辅助宝石 |
| `skillGems.priorityGems[]` | 辅助宝石名称清单，**顺序即优先级** |
| `skillGems.gemRequirements` | `{str, dex, int}` 属性需求，这是属性达标值的硬下限 |
| `passiveTree.mainTree.priorityList[]` | **核心大点名称**，这就是要标出来的节点 |
| `passiveTree.mainTree.selectedSlugs[]` | 完整点法，只用来数总点数，不要逐个翻译 |
| `passiveTree.ascendancyTree.priorityList[]` | 升华节点，按取点顺序 |
| `passiveTree.jewels[]` | 珠宝：`jewelSlug`、`nodeSlug` 插槽位置、`prefixSlugs`／`suffixSlugs`、交易站查询 |
| `atlasTree` | 寻路图天赋 |

槽位名：`mainHand` `offHand` `helmet` `body` `gloves` `boots` `amulet` `leftRing` `rightRing` `belt` `flask1` `flask2` `charm1` `charm2` `charm3`。

正文与作者答疑：
- `...userGeneratedDocumentBySlug.data.content` 是正文。
- 评论区在另一个 query（`queryKey` 含 `ngf-comments`）。**作者在评论区的回复往往包含正文没写的关键坑**，必须抓。
- 页面 `innerText` 里的 `Act N Regex` 段落是作者给的升级期搜索串；`Filter's I use` 后面的链接是他用的物品过滤器，两者不是一回事，要分开记。

## 第 2 步：调研变体并让用户拍板

**不要自己决定做哪几个变体。** 先把每个变体的可决策信息整理出来，再用 `AskUserQuestion`（`multiSelect: true`）让用户选。

每个变体要给出的信息，全部从第 1 步的数据算，不要凭变体名猜：

- **阶段定位**：从装备里的传奇和关键宝石反推（例：带 Ailith's Chimes → 65 级前的过渡；带 Chaos Inoculation 关键石 → 转能量护盾之后；带 Mageblood／Kalandra's Touch → 镜像级）。
- **与上一档的差异**：逐槽位比对 `commonItem.name` 与 `explicitDescriptions`，列出「换了什么、加了什么、丢了什么」。
- **造价档次**：数传奇件数与镜像级传奇件数。
- **属性需求**：`gemRequirements` 的三围。
- **是否有天赋树重构**：比对 `selectedSlugs` 的交集比例，低于 70% 就标「需要洗点」。

问题里同时问清：只做选中的变体，还是把差异页也一起生成。

## 第 3 步：建立中英对照

### 3.1 装备词缀

Mobalytics 给的是英文词缀文本，要翻成简中客户端原文。两条路，**以交易站链接为主**：

**主路径（精确）**：`commonItem.poe2TradeRequest.query` 是一段 JSON，里面 `stats[0].filters[]` 每项有 `id`（形如 `explicit.stat_709508406`）和 `value.min`。在浏览器里同源取官方映射表：

```js
// 先把标签页导航到 https://www.pathofexile.com/trade2/search/poe2/<当前联盟>
const r = await fetch('/api/trade2/data/stats', {credentials:'same-origin', headers:{Accept:'application/json'}});
const j = await r.json(); const all = []; j.result.forEach(g => g.entries.forEach(e => all.push(e)));
// all: 约 8300 条 {id, text}，text 形如 "Adds # to # Fire Damage"
```

**辅路径**：`explicitDescriptions[].description` 的英文文本，用于交易链接没覆盖的部位（药剂、护符、传奇）。

**英文 → 简中**：在 poe2db 上做。把标签页放到任意 `poe2db.tw` 页面，然后同源取页面，`/us/` 与 `/cn/` 同一页面的词缀顺序完全一致，按下标对位：

```js
async function mods(path){
  const t = await (await fetch(path, {credentials:'same-origin'})).text();
  const out = []; const re = /\{"Name":"((?:[^"\\]|\\.)*)","Level":"(\d+)","ModGenerationTypeID":"(\d+)","ModFamilyList":\[([^\]]*)\]/g;
  let m; while ((m = re.exec(t))) {
    const seg = t.slice(m.index, m.index + 3000);
    const si = seg.indexOf('"str":"'), fi = seg.indexOf('","fossil_no"');
    let s = (si > -1 && fi > si) ? seg.slice(si + 7, fi) : '';
    s = s.replace(/\\"/g,'"').replace(/\\\//g,'/').replace(/<[^>]*>/g,'').replace(/\s+/g,' ').trim();
    out.push({ name: m[1], lv: +m[2], gen: +m[3], fam: m[4].replace(/"/g,''), text: s });
  } return out;
}
const [us, cn] = await Promise.all([mods('/us/Rings'), mods('/cn/Rings')]);
// us[i] 与 cn[i] 是同一条词缀；gen 1 = 前缀，2 = 后缀
```

**分页规则（踩过的坑）**：

- 饰品、腰带、武器、珠宝、药剂、护符、遗物、图签：`/us/<类名>`，例 `Rings` `Amulets` `Belts` `Quarterstaves` `Bows` `Charms` `Life_Flasks`。
- **护甲没有整类词缀页**，按属性拆分：`Gloves_str` `Gloves_dex` `Gloves_int` `Gloves_str_dex` `Gloves_str_int` `Gloves_dex_int`，`Boots_*`、`Helmets_*`、`Body_Armours_*`（多一个 `str_dex_int`）、`Shields_str*`、`Bucklers`、`Foci`、`Quivers` 同理。`/us/Gloves` 这种页面**只有底材表，没有词缀**。
- 完整的 78 个词缀页清单从 `/us/Modifiers` 里抓：所有 `href` 含 `#ModifiersCalc` 的链接。
- 底材中文名在 `/cn/<类名>` 页（`/cn/Quarterstaves` 有「邪恶节杖」，`/cn/Helmets` 有「强盗面具」）。
- poe2db 的站内搜索**查不到词缀名和底材名**，只索引技能、怪物、传奇。别用搜索做否定判断。

### 3.2 符文、灵魂核心、涂油

`runes[]` 与 `chakras[]` 给的是 slug（例 `soulcore-runespecial13`），不是名字。到 `/cn/Runes` 与 `/us/Runes` 对位取名与数值。二手资料站的符文数值有错（曾见 Greater Iron Rune 被写成 18%，实为 25%；Stone Rune 被写成 +60，实为 +40），一律以 poe2db 原始数据为准。

### 3.3 术语

技能名、升华名、关键石名一律取 `/cn/Skill_Gems`、`/cn/Ascendancy_class`、`/cn/passive-skill-tree/`。查不到的（新版本内容）标注「暂译」，不要装作官方译名。

## 第 4 步：设计三层搜索正则

作者一般只给升级期的正则，异界和终局要自己设计。**全部基于第 3 步拿到的简中原文**，不是直译。

写正则前先弄清这三件事：

1. **游戏内搜索框匹配已鉴定物品的完整文本**，蓝装名称由「前缀名 + 底材 + 后缀名」拼成，所以**词缀名**（例「幽焰的」「仙子的」）和**词缀文本**（例「移动速度提高」）都能命中。地上未鉴定的蓝装只有名称可读，此时只有词缀名有效。
2. **英文的 `^` 与 `$` 锚点在简中全部失效**。英文「+2 to Level of all Melee Skills」加值在行首，简中「所有近战技能等级 +2」加值在行尾。一律去掉锚点。
3. **一个英文词元常对应多个不相干的简中词**。英文 `studded` 同时命中前缀 Studded、底材 Studded Vest、底材 Studded Sandals；简中分别是「镶嵌的」「嵌饰背心」「镶钉鞋履」，没有公共字串，必须展开写。

三层的划分与内容：

| 层次 | 覆盖阶段 | 取向 |
|---|---|---|
| 开荒 | 战役第 1–4 幕 | 底材前缀名（按物品等级门槛分幕递进）＋ 移动速度 ＋ 技能等级 ＋ 当幕首领的抗性 |
| 异界 | 三段间章至低层地图，约 55–75 级 | 三抗齐凑 ＋ 附加元素伤害 ＋ 构筑核心属性（暴击、攻速、精魂等）＋ 目标底材前缀名 |
| 终局 | 高层地图之后 | 只筛可能超过当前装备的高阶词缀档次名 ＋ 特定底材 ＋ 构筑独有词缀 |

**词缀名的物品等级门槛必须查出来**（poe2db 数据里的 `lv` 字段），按门槛分配到层次里。常见错误是把等级 46 才生成的档次写进第 3 幕的正则，那一条在该阶段是死词元。

开荒层按幕拆四条，抗性跟着该幕首领的伤害类型走（第 1 幕吉奥诺伯爵主冰霜，第 2 幕加曼拉主闪电）。

## 第 5 步：生成网页

每个变体一个 HTML 文件，单文件自包含（CSS 和 JS 内联，图片用 data URI 或直接省略）。

**同一个构筑的所有变体共用同一套设计**（同配色、同排版、同 CSS 变量），便于 git diff 和横向比对；不同构筑之间可以换配色。必须同时支持浅色与深色：`@media (prefers-color-scheme: dark)` 下的规则用 `:root:not([data-theme="light"])` 包裹，再加一份 `:root[data-theme="dark"]`。

每页固定这些章节，顺序固定：

1. **底层逻辑** — 用一条因果链说清这套构筑怎么转起来，例：「打冰裂掌 → 产连击 → 召唤物消耗连击 → 换成暴击球 → 霹雳闪消耗暴击球清屏」。这是全页最重要的一节，写在最前面。
2. **升华节点** — `ascendancyTree.priorityList` 的顺序即取点顺序，标出每个节点解决什么问题。
3. **技能宝石配置** — 主动技能 + 辅助宝石，按 `priorityGems` 的顺序标优先级；标出宝石等级。
4. **操作循环** — 从正文和作者答疑里提炼，标出「不做会崩」的步骤。
5. **属性达标值** — 生命／能量护盾／闪避／暴击率／四抗／力敏智。属性下限直接取 `gemRequirements`。凡是原站没给数值的，写「原站未给」，不要编。
6. **装备与词缀** — 逐部位表格：底材中文名＋英文名、目标词缀（中文原文＋英文＋交易站 min 值）、是否 `mustHave`、插的符文／灵魂核心、涂油、腐化与亵渎等后处理、`priorityList` 里的作者注释。额外符文槽（`chakras`）单列一节。
7. **天赋树核心节点** — 只列 `priorityList` 的大点与关键石，写清每个点为什么要。明确写出「完整点法对着原站点，本页只标核心」。附总点数。
8. **珠宝** — 每颗珠宝的类型、插在哪个节点、要什么词缀。
9. **搜索正则** — 第 4 步的三层，每层附词元对照表。
10. **作者答疑与坑** — 正文 + 评论区。作者亲口说的「不要用 X」这类必须用警告样式突出。
11. **与其他变体的差异** — 逐槽位差异表，标 增／删／改。
12. **术语对照表** — 中文、English、来源（数据库／暂译）。
13. **数据核验** — 哪些数值是查证过的、哪些是暂译、原文自相矛盾的地方、原站缺失的章节。**这一节不能省**，它是这套页面与随手翻译的区别。

写作口径：简体中文，专业名词后附英文。去掉寒暄与结尾套话。凡是原站没有的信息，明确标出来源和不确定性，不要用模糊措辞填补。

## 第 6 步：落盘

目录结构：

```
E:\poe2 plugin\poe2-build-repo\
  index.html                     ← 所有构筑的索引，按补丁号倒序
  0.5.5-武学家\                  ← <补丁号>-<职业中文名>
    index.html                   ← 本构筑的变体索引 + 变体间差异总表
    镜像投入.html
    高投入.html
    终局.html
    异界过渡.html
    开荒.html
    _source.json                 ← 第 1 步抓到的原始数据，便于下次增量更新
```

- 补丁号从页面标题的 `[0.5.5]` 或标签里的 `0.5.5 FR` 取。
- 职业中文名取升华名（Martial Artist → 武学家），不是基础职业。同补丁同职业有第二套构筑时，目录名后加构筑核心技能名：`0.5.5-武学家-霹雳闪`。
- 文件名用变体的中文名，与第 2 步给用户看的名称一致。
- 每次写文件前先 `device_list_dir` 看同名文件在不在；在就是更新，要在提交信息里写清改了什么。

写文件的方式：先写到 `/mnt/user-data/outputs/`，再用 `device_commit_files` 写到上面的路径。

## 第 7 步：git

仓库中文路径必须先关掉转义，否则 `git status` 全是八进制：

```
git -C "E:\poe2 plugin\poe2-build-repo" config core.quotepath false
```

仓库还没有任何提交时（`.git/refs/heads` 为空），先在 main 上建初始提交，再开分支。

完整序列（分支名用 ASCII，避免 Windows 下的分支名编码问题）：

```
git -C "E:\poe2 plugin\poe2-build-repo" checkout -b build/0-5-5-martial-artist
git -C "E:\poe2 plugin\poe2-build-repo" add .
git -C "E:\poe2 plugin\poe2-build-repo" commit -m "0.5.5 武学家：新增 N 个变体中文页"
git -C "E:\poe2 plugin\poe2-build-repo" checkout main
git -C "E:\poe2 plugin\poe2-build-repo" merge --no-ff build/0-5-5-martial-artist -m "合并 0.5.5 武学家"
git -C "E:\poe2 plugin\poe2-build-repo" push -u origin main
git -C "E:\poe2 plugin\poe2-build-repo" branch -d build/0-5-5-martial-artist
```

有 `device_bash` 就逐条执行；没有就把这段原样输出给用户，并明确说「文件已写入磁盘，git 未执行」。推送需要 GitHub 凭据，凭据相关的任何输入都由用户自己完成，不要代填。

## 收尾

给用户一句话说明：生成了哪几个变体、落在哪个目录、git 是否已执行。然后单列一节，写这一轮里发现的边界信息：原站自相矛盾的地方、查不到官方译名的条目、数据缺口、以及用户还需要补的数据（面板数值等）。
