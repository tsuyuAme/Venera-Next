# VeneraNext 画师收藏功能 — 开发交接文档 (Handoff)

> 本文档面向后续继续开发/调试本仓库(个人 fork)的开发者。
> 最后更新: 2026-08-22(对应本地工作区状态)

---

## 1. 仓库与远端状态

| 项 | 值 |
|---|---|
| 上游 | https://github.com/CyrilPeng/Venera-Next (GPL-3.0) |
| 个人 fork | https://github.com/Hansnmor/Venera-Next |
| 本地路径 | `E:\_Code\_hansnmor\_WORKSPACE\deepseek harness\_workspace\Venera-Next` |
| 版本 | 1.14.3+300 (release.json / pubspec.yaml) |
| 已推送 commit | `bc5e21b`(分析管线全面增强, 最新) |
| **本地未提交** | `artist_favorites_page.dart` / `artist_profile.dart` / `artist_favorites_test.dart`(全体搜刮按钮、并发加速、emoji 剥离、Top 8 —— 见 §5) |

**未提交改动尚未 push**, 本地 `flutter build windows --release` 会包含它们; 云端 fork 停在 `bc5e21b`。

---

## 2. 功能总览(画师收藏)

| 能力 | 入口 | 说明 |
|---|---|---|
| 收藏画师 | 漫画详情页 → 长按作者/画师标签 → 「Favorite author」 | 原版已有机制(SearchShortcut), 存于 `appdata.settings['searchShortcuts']`, 自动随 WebDAV 同步 |
| 画师收藏管理页 | 首页「画师收藏」摘要卡片 → 列表页 | `ArtistFavoritesPage` |
| 收藏即自动分析 | 收藏成功时后台触发 | `autoAnalyzeArtist`(静默, 失败/空不打扰) |
| 手动/重新分析 | 条目 ✨ 按钮 或 长按菜单「重新分析」 | `analyzeArtistProfile` |
| 一键全体搜刮 | 收藏页标题栏 🔄 按钮(带确认框) | `analyzeAllArtists`(2 并发, 无视缓存强制重刷) |
| 跨源聚合搜索 | 点击画师名 | 复用官方 `AggregatedSearchPage(keyword:)` |
| 复制/删除 | 行内复制按钮 / 长按删除(清缓存) | 删除同时清理 profile |
| 每日分析日志 | exe 目录 `logs/artist_analysis_YYYY-MM-DD.log` | 每次分析追加记录, 调优依据 |

---

## 3. 代码结构(新增/修改文件)

```
lib/features/search/
├── artist_profile.dart            ← 核心分析管线(474 行, 全部逻辑在此)
├── artist_favorites_page.dart     ← 收藏页 UI(列表/分析按钮/全体搜刮/删除)
├── artist_favorites_summary.dart  ← 首页摘要卡片(对齐项目 16px/arrow_right 基准)
├── search.dart                    ← 入口 export(新增 3 个 export)
└── search_shortcuts.dart          ← 改动: 收藏成功时触发 autoAnalyzeArtist(+5 行)

test/features/search/artist_favorites_test.dart   ← 12 个单测
```

**未改动**:漫画源 JS API、WebDAV 同步、appdata 模型(全部复用现有 settings 机制)。

---

## 4. 分析管线详解(artist_profile.dart)

### 4.1 流程

```
analyzeArtistProfile(name)
  ├─ 源并行: ComicSource.all() 中 searchPageData != null 的源 → Future.wait
  │    └─ _collectWithRetry(源)         ← 每源: 默认搜索选项 + 第1页起
  │         ├─ _collectFromSource       ← loadPage 翻页(或 loadNext), 每源≤50部+截断
  │         └─ 失败/空 → 退避重试 2 次(0.6s / 1.2s)
  ├─ dedupeComicsByTitle(跨源标题归一化去重)
  ├─ 标签统计(原始频次 rawCounts)
  ├─ sanitizeArtistTag(单标签清洗, 输出 "过滤后频次")
  │    ├─ trim / 空 / 超长(>30) / URL → 丢弃
  │    ├─ 元数据 namespace 过滤(artist/group/language/parody/series/character/...)
  │    ├─ 忽略表 _kIgnoredContentTags(去前缀后二次检查)
  │    └─ _normalizeTagSynonym(自定义词典 → EhTag 翻译表(ns) → 全局翻译表)
  ├─ topArtistTagsFromCounts
  │    └─ mergeSimplifiedVariants(剥离 emoji 装饰 → OpenCC 简繁归并, 保留大者不相加)
  │         → 排序(频次 desc, 平局字典序) → Top 8
  ├─ _writeAnalysisLog(按天写日志)
  └─ 返回 Top 8
```

### 4.2 调优常量(全部在 artist_profile.dart 顶部区域)

| 常量 | 默认 | 说明 |
|---|---|---|
| `_kMaxProfilePages` | 5 | 每源最多翻页数 |
| `_kMaxProfileComics` | 50 | 每源最多作品数(整页截断) |
| `_kMaxAnalysisRetries` | 2 | 源失败/空时的额外重试次数 |
| `_kAllAnalysisConcurrency` | 2 | 全体搜刮的并发画师数(可调 3) |
| `_kMetadataNamespaces` | 12 组 | 元数据 namespace 过滤表 |
| `_kIgnoredContentTags` | 同人/同人誌/doujinshi/doujin/sole male/sole female | 格式类标签排除表 |
| `_kTagSynonyms` | korean→韓漫、oneshot→单本 等 7 条 | 自定义同义词(优先于翻译表) |
| Top 上限 | `limit: 8` | `topArtistTagsFromCounts` / `topArtistTags` |

### 4.3 三层归一化(单标签)

1. `_kTagSynonyms`(自定义覆盖)
2. `TagsTranslation.translationTagWithNamespace(value, ns)`(EhTagTranslation 数据库,
   `assets/tags.json` ~33,901 条, App 启动时 `TagsTranslation.readData()` 加载)
3. `translateTagsToCN`(全局合并表 enTagsTranslations, 不含 artist/group)

### 4.4 展示与存储

- profile 缓存: `appdata.settings['artistProfiles'][name] = {'tags': [...], 'updatedAt': ts}`
- 列表 subtitle: `Frequent tags: @tags`(maxLines 3)
- 删除画师时同步 `removeArtistProfile`

---

## 5. 本地未提交改动清单(相对 bc5e21b)

1. **Top 5 → Top 8**(`limit` 默认值 + subtitle maxLines 3)
2. **emoji 剥离**: `_stripDecoration`(翻译表条目如「眼镜👓」导致简繁归并失效)
   - 范围: 0x1F000-0x1FAFF / 0x2600-0x27BF / FE00-FE0F / 200D / 200B
3. **全体搜刮**: 页面 🔄 按钮 + 确认框 + 状态转圈; `analyzeAllArtists`(分批并发)
4. **源并行**: `analyzeArtistProfile` 内 Future.wait 并行 3 源(原来串行)
5. 重构: `_collectWithRetry` / `analyzeAndSaveArtist` 拆分
6. 测试: 新增 emoji 归并用例(12 个全过)

---

## 6. 本地开发环境(用户机器, 已配好)

| 组件 | 位置 | 备注 |
|---|---|---|
| Flutter 3.41.4 | `E:\_Code\ProgramFiles\flutter` | **必须无空格路径**(原 "Program Files" 导致 native-assets 构建崩, 已迁) |
| VS 2026 (18.9.1) | `E:\Program Files\Microsoft Visual Studio\18\Community` | C++ 桌面负载: MSVC 14.51 / CMake / Ninja; Windows SDK 10.0.26100 在 `E:\Windows Kits` |
| Rust | rustup 管理(`C:\Users\qq192\.cargo`) | 项目要求 1.85.1(rust-toolchain.toml); **stable 已升 1.98**(cargokit 固定用 stable 工具链, 1.74 曾导致 Cargo.lock v4 解析失败) |
| nuget.exe | `E:\_Code\ProgramFiles\nuget\nuget.exe`(已加用户 PATH) | `flutter_inappwebview_windows` 插件编译需要 |
| PATH | 系统级已加 flutter\bin; 用户级已加 nuget | **新终端生效** |

常用命令(在项目目录):

```powershell
flutter pub get --enforce-lockfile   # 必须带锁文件参数
flutter analyze --no-pub
flutter test --no-pub test/features/search/artist_favorites_test.dart
flutter run -d windows                # 调试窗口, r=热重载 R=热重启 q=退出
flutter build windows --release       # 正式 exe → build\windows\x64\runner\Release\
python windows/build.py               # 完整安装包(需 Inno Setup)
```

---

## 7. 已知坑与注意事项

1. **单测环境无翻译表/OpenCC**: `TagsTranslation`(App 启动加载)和 `OpenCC.init()`(init.dart:76)在单测里未初始化。`_toSimplified`/`_normalizeTagSynonym` 已做容错降级(返回原文), 翻译/简繁效果只能运行时(flutter run)验证——测试里断言用"透传原文"语义。
2. **flutter test 在本地会报第三方包 hook 编译错误**(irondash/pdfrx 与 Dart 3.11 的兼容问题, 发生在 native-assets 编译链路)——**这是已知环境噪声**, 与项目代码无关; CI(flutter build windows)不受影响。单测请只跑具体文件: `flutter test test/features/search/artist_favorites_test.dart`。
3. **analyze.yml 在 fork 上从未触发**(push main 未触发, 原因未明); 代码质量靠本地 `flutter analyze` + 手动触发 build.yml(workflow_dispatch)。
4. **构建触发**: GitHub API `POST /actions/workflows/build.yml/dispatches`, body 里 `build_android:false`(fork 无签名 secrets), 只留 `build_windows:true`。
5. **源脚本在应用数据目录**(不属于本仓库): `C:\Users\qq192\AppData\Roaming\com.github.cyrilpeng\VeneraNext\comic_source\{ehentai,jm,picacg}.js`。已改默认排序: jm→`mv`(總排行)、picacg→`ld`(Most likes), 备份为 `.js.bak`; e-hentai 搜索无排序参数(站点限制)。
6. **数据共享**: 调试版与正式版共用 `%APPDATA%` 数据(收藏/画师/源都在), 画师分析日志写在 **exe 所在目录**的 `logs\`。
7. **画师收藏的"收藏入口"是原版机制**: 详情页长按画师标签 → 「Favorite author」(仅当源支持 handleClickTagEvent 时出现)。

---

## 8. 后续开发建议

- [ ] 本地未提交改动验证后(全体搜刮/并发/emoji/Top8), commit + push + 触发 build.yml 出正式包
- [ ] 依据每日日志增补 `_kIgnoredContentTags` / `_kTagSynonyms`(例如「单本/短篇/全彩」是否排除)
- [ ] 可选: e-Hentai 热门排序调研(`/popular/` 端点是否支持搜索词)
- [ ] 可选: 分析结果增加"更新时间"展示(profile 已有 updatedAt)
- [ ] 可选: 全体搜刮增加进度条 UI(当前只有旋转指示)
