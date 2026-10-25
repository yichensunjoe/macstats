<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · [繁體中文](README_zh-TW.md) · **日本語** · [한국어](README_ko.md) · [Deutsch](README_de.md) · [Español](README_es.md) · [Français](README_fr.md) · [Русский](README_ru.md) · [Português (Brasil)](README_pt-BR.md)

# MacStats

### アクティビティモニタを、デスクトップに留めておく。

**CPU、メモリ、GPU、電力、ディスク、ネットワークをひと目で。数値はアクティビティモニタに合わせて調整済み。**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#クイックスタート)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#仕組み)
[![tests](https://img.shields.io/badge/tests-91%20passing-3fb950?style=flat-square)](#コマンド)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#仕組み)

[クイックスタート](#クイックスタート) · [表示できる指標](#表示できる指標) · [2つの表示形態](#2つの表示形態) · [精度](#アクティビティモニタとの一致度) · [FAQ](#faq) · [既知の制限](#既知の制限)

`bash scripts/bundle.sh`

</div>

---

<p align="center">
  <img src="../live-window.png" alt="MacStats のデスクトップパネル：CPU、メモリ、GPU、電力、ディスク、ネットワークとメモリ上位3プロセス" width="460" />
</p>

アクティビティモニタは十分な情報を出しますが、あれは「ウィンドウ」です。開いて、タブを選んで、前面に出さなければならない。MacStats は同じ6つの指標を、デスクトップに常駐するダークパネルにします。1秒ごとにサンプリングし、サイズに合わせてレイアウトを組み替え、さらに WidgetKit ウィジェットも用意しているので、デスクトップのグリッドに小さいものを置きたい人はそちらを使えます。

指標を増やすつもりはありません。中身はアクティビティモニタの5項目に GPU 使用率と統合メモリ使用量を加えたものに、90秒のトレンドライン、コアごとの使用率、メモリの内訳、メモリ上位3プロセスを足したものです。手間がかかったのは描画ではなく、**すべての数値をアクティビティモニタと同じ値にすること**でした。同一瞬間に並べて比べると、メモリは 0.2 GB 以内、ディスクとネットワークの累計値はバイト単位で一致します。

<p align="center">
  <img src="../compact-strip.png" alt="横長のストリップ：CPU・メモリ・GPU・電力・ディスク・ネットワークを一行に" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="細いストリップ：同じ 6 項目が 3 × 2 のグリッドに折り返される" width="330" />
</p>

**細長くドラッグすると最小レイアウトになります。** カードもトレンドラインもなく、6つの指標が一行に並び、メニューバーの下のインジケーターになります。一行に収まらない幅では 3 × 2 のグリッドに折り返し、6項目は常に表示されます。1秒更新で CPU は 1 コアの約1%、常駐メモリは 80 MB 程度（arm64 + macOS 26 で実測）。描画負荷はこの段階がいちばん軽いです。新規インストールではこの形が既定です。右クリック →「標準パネルに展開」でフルパネルになり、同じ項目でまた条状に戻せます。

> [!NOTE]
> デスクトップパネルはそのまま動きます。システムの「ウィジェットギャラリー」に出るほうは、有効な Apple Development 署名と `/Applications` へのインストールが必須です。これは `chronod` の要件で、好みの問題ではありません。詳しくは[システムウィジェット](#システムウィジェット)を参照してください。

## クイックスタート

macOS 15 以降と Xcode コマンドラインツール（Swift 6）が必要です。サードパーティ依存も Xcode プロジェクトファイルもありません。

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # ビルド + バンドル + /Applications へインストール + ウィジェット登録
open /Applications/MacStats.app
```

初回起動でメニューバーに `CPU · メモリ` の小さな表示が出て、デスクトップにパネルが現れます。

- メニューバーのアイコンを左クリック：パネルの表示 / 非表示
- パネルを右クリック：常に最前面、デスクトップに固定、クリック透過、更新間隔（1 / 2 / 5 秒）、新規インスタンス
- 余白をドラッグして移動、右下のグリップでサイズ変更。レイアウトは「最小 / コンパクト / 標準 / 詳細」に自動で切り替わります
- 設定はアプリの `com.macstats.app` プリファレンスドメインに保存され、再起動しても位置とサイズは維持されます

## 表示できる指標

| 指標 | パネルの表示 | 計測方法 |
|---|---|---|
| CPU | 大きな合計値 + ユーザ / システム + 90秒トレンド + コア別バー | `host_processor_info` の差分（アクティビティモニタと同じ情報源） |
| メモリ | 使用量 / 総量、プレッシャーバー、App / ワイヤード / 圧縮の内訳、キャッシュ | `vm_statistics64`、詳細は[精度](#アクティビティモニタとの一致度) |
| 電力 | CPU のエネルギーカウンタから換算したワット数、バッテリー残量と充電状態 | `ri_energy_nj` の差分。カウンタがない場合は負荷からの推定値を使い、その旨を表示 |
| ディスク | 読み書き速度、空き容量 | `IOBlockStorageDriver` の累計バイト差分 |
| ネットワーク | 上り / 下り速度、プライマリインターフェース | `NET_RT_IFLIST2` の 64 ビットカウンタ。速度は `lo0` を除外 |
| GPU | 使用率の大きな数字 + 90秒トレンドライン + 統合メモリ使用量 / コア数 | `IOAccelerator` の `PerformanceStatistics`（`Device Utilization %`、`In use system memory`）。アクティビティモニタの GPU タブと同じ情報源 |
| プロセス | メモリ上位3件（大サイズウィジェットでは5件） | `proc_pid_rusage` の `ri_phys_footprint` |

<p align="center">
  <img src="../widget-medium.png" alt="中サイズウィジェット：コア別バー付き CPU と、メモリ・ディスク・ネットワーク・電力・GPU（搭載時）のタイル" width="620" />
  <img src="../widget-small.png" alt="小サイズウィジェット：大きな CPU 数値とトレンドライン" width="280" />
</p>

## 2つの表示形態

サンプリング層は1つ、ホストは2つ：

| | デスクトップパネル | システムウィジェット（WidgetKit） |
|---|---|---|
| 更新 | 毎秒再描画 | システムの予算でスケジュール、およそ60秒に1回 |
| 位置 | どこへでも移動、複数インスタンス可 | デスクトップのレイアウトグリッド |
| 入口 | メニューバーのアイコン / `open MacStats.app` | デスクトップを右クリック →「ウィジェットを編集」→「MacStats」を検索 |
| サイズ | 自由にリサイズ、4段階のレイアウト | 小 / 中 / 大 / 特大の固定 |
| 前提 | なし | 有効な署名 + `/Applications` へのインストール + `_NSExtensionMain` エントリポイント |

動いている感じが欲しければパネル、他のウィジェットと並べたければシステムウィジェット。どちらも同じスナップショットを読むので、2つの数値が食い違うことはありません。

## アクティビティモニタとの一致度

方法：アクティビティモニタとパネルを同じ画面に置き、アクセシビリティ API でアクティビティモニタの数値を読み、同じ瞬間のサンプルと項目ごとに比較します。

| 項目 | 結果 |
|---|---|
| メモリ：使用済み / キャッシュ / App / ワイヤード / 圧縮 | 0.2 GB 以内（アクティビティモニタ自身が5秒間表示をキャッシュするため） |
| ディスク：累計読み / 累計書き | バイト単位で一致 |
| ネットワーク：累計受信 / 累計送信 | バイト単位で一致（10進 GB） |
| プロセスメモリ | 同じ PID で 0.0 MB |
| CPU | 安定負荷で 1〜3 ポイント差（サンプリング窓の位相差） |

<p align="center">
  <img src="../monitor-compare.png" alt="上：アクティビティモニタのメモリタブ。下：同じ瞬間の MacStats パネル" width="700" />
</p>

そこに到達するまでに、3つの「思い込み」を直しました：

- **累計ネットワーク通信量は IFMIB の 64 ビットカウンタで読む。** `NET_RT_IFLIST2` の `ifi_ibytes` は下位 32 ビットしか埋まらず、折り返し後は 122.9 GB の `lo0` 通信が 2.6 GB と読めていました。累計値は `lo0` を含め（アクティビティモニタも含む）、速度の列からは除外します。そうしないとループバックで速度が約60倍に膨らみます。
- **「使用済み」は「App + ワイヤード + 圧縮」ではない。** アクティビティモニタの使用済みメモリは 物理 − (free − speculative) − ファイルキャッシュ、キャッシュ済みファイルは ファイルキャッシュ + パージ可能ページ。直感ではなく定義どおりに実装します。
- **電力は「エネルギー影響」ではない。** あの列は無次元の相対スコアで再現できません。パネルは物理的なワット数を出し、タイルに「CPU エネルギーカウンタ」と明記して、スコアと混同しません。

## 仕組み

3層で、UI に依存する層はありません：

```
MacStatsCore  サンプリングと換算（純粋なロジック、単体テスト対象）
      ↓
WidgetData    スナップショット + 90点のリング履歴
      ↓
SwiftUI ビュー  パネルと WidgetKit 拡張が共有
```

- **サンプリング**：Mach（`host_processor_info`、`host_statistics64`）、IOKit（ディスク統計、電源）、`sysctl(NET_RT_IFLIST2)`、`sysctl(vm.swapusage)`、libproc（`proc_listpids` / `proc_pid_rusage`）。公開 API のみ。sudo 不要、SIP 無効化不要、私有フレームワーク不要。
- **速度系の指標は直近5サンプルの移動平均**で、アクティビティモニタ既定の5秒窓に合わせつつ、ちらつきも抑えます。
- **パネルはデスクトップ階層の `NSPanel`**：非アクティブ化、すべてのスペースに追従、フォーカスを奪わないので、クリックしても作業中のウィンドウが背面に落ちません。
- **データはマシン外に出ません**：ネットワーク要求なし、テレメトリなし、アカウントなし、ユーザーファイルも読みません。システムカウンタを公開 API で読み、ウィジェット拡張用にローカル JSON を1つ書くだけです。

## コマンド

| 目的 | コマンド |
|---|---|
| ビルド + バンドル + インストール | `bash scripts/bundle.sh` |
| 単体テスト | `cd src && swift test` |
| サンプラの自己診断 | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| 生のカウンタを表示 | `cd src && .build/debug/macstatsDiag --raw` |
| JSON スナップショット | `cd src && .build/debug/macstatsDiag --json` |
| パネルをオフスクリーン描画 | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| 4サイズのウィジェットを描画 | `bash scripts/preview-widget.sh` |

## プロジェクト構成

```
src/Sources/MacStatsCore/    サンプリング、メモリ換算、リング履歴、整形（UI 非依存）
src/Sources/MacStats/        SwiftUI パネル、メニューバーアプリ、コンテキストメニュー、オフスクリーン描画
src/Sources/MacStatsWidget/  WidgetKit 拡張：タイムラインプロバイダ + 4段階のビュー
src/Sources/MacStatsDiag/    診断 CLI（--json / --raw / --self-check）
src/Tests/                   XCTest、91件
scripts/bundle.sh            release ビルド、appex 組み立て、署名、インストール、登録
docs/                        精度の検証記録、アーキテクチャ、要件、スクリーンショット
```

## システムウィジェット

拡張は `MacStats.app/Contents/PlugIns/MacStatsWidget.appex` に同梱され、サイズごとに別レイアウトです。ギャラリーに出すには3つすべてが必要で、どれも実際に踏んだ落とし穴です：

1. **拡張には有効な署名とサンドボックスが必要。** `pkd` は ad-hoc 署名を受け付けず、本物の証明書でも `com.apple.security.app-sandbox` がない appex は `rejecting; … plug-ins must be sandboxed` で黙って捨てられます。無料の個人チーム証明書（Xcode → Settings → Accounts で Apple ID にサインイン）で十分です。
2. **アプリは `/Applications` に置き、登録も1つだけにする。** `chronod` はシステムのアプリケーションディレクトリからしかホストを探しません。プロジェクトディレクトリやユーザー単位の Applications ディレクトリに置くと `Ignoring restricted or unknown extension` になります。同じバンドル ID を2箇所で登録すると launchd が XPC インスタンスを2つ作り、`chronod` は実体のプロセスに届かなくなります。`bundle.sh` はこの前提でインストールし、古い登録を片付けます。
3. **appex のエントリポイントは `_NSExtensionMain` でなければならない。** これは Xcode の `LD_ENTRY_POINT` 既定値です。SwiftPM 既定のエントリポイントだとプロセスは起動し `main [WidgetBundle]` も出力しますが、ホストの XPC セッションを確立せず、約 15 ms で死亡判定され、クラッシュレポートも残りません。`src/Package.swift` で `linkerSettings` により固定しています。

サンドボックス化すると拡張はホストアプリの `UserDefaults` を読めないため、データは JSON スナップショットで受け渡します。アプリはアプリケーションサポートフォルダ内の `MacStats/widget-feed.json` を2秒ごとに書き換え、拡張のコンテナが存在すればそこにも複製します。拡張が新しいスナップショットを見つけられない場合は、自分で1回サンプリングします。

`security find-identity -v -p codesigning` が `0 valid identities` を返す場合、たいていはキーチェーンに Apple の WWDR G3 中間証明書がありません。Xcode 同梱の `AppleWWDRCA-2030.cer` を読み込んでください。

拡張を変更したら `CFBundleVersion` を上げてください。`chronod` はバージョン単位で descriptor をキャッシュするので、据え置くと古い表示が残ります。

## FAQ

<details>
<summary><strong>ウィジェットが1分に1回しか更新されないのはなぜ？</strong></summary>

WidgetKit は描画ループではなく「定時スナップショット」です。タイムラインが1件のエントリを返し、期限が来たら次を要求します。アプリは15秒ごとに `reloadAllTimelines()` を呼びますが、`chronod` は予算で絞ります（ログに `budgeted-1`）。サードパーティのウィジェットに秒単位の更新は許されず、システム時計のような特権は拡張にはありません。

リアルタイムの数字が必要なら、毎秒更新するデスクトップパネルを使ってください。

</details>

<details>
<summary><strong>メモリ上位に WindowServer が出ないのはなぜ？</strong></summary>

他のユーザーのプロセス（`_windowserver` など）は読めません。`proc_pid_rusage` は EPERM を返し、`proc_pidinfo` は 0 バイトを返します。アクティビティモニタは Apple のエンタイトルメントを持つため全て見えます。これは権限の境界で、計算ミスではありません。

</details>

<details>
<summary><strong>まだアクティビティモニタと少し違う。</strong></summary>

アクティビティモニタは5秒ごとに更新し、表示は前回更新時のスナップショットです。パネルは毎秒更新します。同一瞬間に比べるとメモリは最大 0.2 GB、速度と CPU はサンプリング窓の位相差だけずれます。1周期待って比べ直せば一致します。

</details>

<details>
<summary><strong>データはどこかへ送られますか？</strong></summary>

いいえ。ネットワーク要求、テレメトリ、アカウントはなく、ユーザーファイルも読みません。公開 API でシステムカウンタを読み、ウィジェット拡張用のローカル JSON を1つ書くだけです。

</details>

<details>
<summary><strong>Intel Mac でも動きますか？</strong></summary>

公開 API しか使っていないので原理的には動くはずですが、実測は arm64（macOS 26）のみです。Intel では CPU と電力の換算にキャリブレーションデータがありません。比較結果を添えて issue を立ててもらえれば助かります。

</details>

## 既知の制限

- **システムウィジェットは約60秒に1回。** WidgetKit のスケジューリング上限で、アプリ側では回避できません。
- **電力は物理的なワット数**で、アクティビティモニタの「エネルギー影響」スコアではありません。両者に単位の対応はありません。
- **プロセス一覧は現在のユーザーのみ**、メモリ順。パネルは3件、サンプリング層は最大24件を保持します。
- **ローカルのライブ値のみ**：履歴データベース、アラート、リモート監視はありません。

## ドキュメント

詳細な記録は中国語です。

- [精度の検証](../monitor-alignment.md)：各数値をどうアクティビティモニタに合わせたか、実測値つき。
- [アーキテクチャ](../architecture.md)：層、データフロー、設計上の取捨選択。
- [要件](../requirements.md)：範囲、非目標、受け入れ基準。

## ライセンス

オープンソースライセンスは未指定で、すべての権利を留保します。実装の一部を再利用したい場合は、用途を書いて issue を立ててください。
