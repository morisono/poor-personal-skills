# Disk Usage tools

## Introduction

ディスク使用状況ツールは、du, ncdu をはじめとして互換性能をもつものがいくつか開発されています。
機能比較を見ていきましょう。

### Dysk
Dyskは、マウント済みファイルシステムの使用状況をテーブル表示する Rust ベースのツールです。`df` の代替として、フィルタやソートで空き容量・使用率を素早く確認できます。

- **機能**: マウント済みディスク・パーティションの合計/使用/空き容量を一覧表示します。ディレクトリ単位の分析は対象外です。
- **フィルタ**: `use > 65%` や `disk = HDD` のような条件式で表示対象を絞り込めます。
- **用途**: システム全体のディスク残量監視。ファイル単位の調査には dua / dust を使います。
- **特徴**:
  - `df` 互換の高速な一覧表示
  - 条件式によるフィルタとソート
  - JSON出力対応

公式サイト: [dysk](https://dystroy.org/dysk)

注意: 同名の [khenidak/dysk](https://github.com/khenidak/dysk)(Azure Managed Disks をカーネルブロックデバイスとしてマウントするドライバ)は別プロジェクトです。


```bash
# dysk

> Display filesystem information in a table.
> More information: <https://dystroy.org/dysk>.

- Get a standard overview of your usual disks:

dysk

- Sort by free size:

dysk --sort free

- Include only HDD disks:

dysk --filter 'disk = HDD'

- Exclude SSD disks:

dysk --filter 'disk <> SSD'

- Display disks with high utilization or low free space:

dysk --filter 'use > 65% | free < 50G'
```

### dua (Disk Usage Analyzer)
`dua`は、コマンドラインベースのディスク使用量分析ツールです。シンプルでありながらも、強力な機能を備え、ファイルやディレクトリのディスク使用量をインタラクティブに可視化します。

- **機能**: 
  - 指定したディレクトリやファイルシステムのディスク使用量を瞬時に解析します。
  - `dua interactive` コマンドを使用して、ディスク上のファイルやフォルダの使用量をインタラクティブに探索でき、削除やクリーンアップが容易です。
- **高速性**: `dua`は、マルチスレッド化されており、非常に高速にディスクの使用量を集計できます。
- **用途**: システムやサーバーのディスク容量が不足し始めた際に、不要なファイルや巨大なディレクトリを迅速に特定し、整理するのに役立ちます。
- **特徴**:
  - インタラクティブモード
  - シンプルなコマンド体系
  - 並列処理による高速な解析
  - JSON出力対応（自動化に適している）

公式リポジトリ: [dua](https://github.com/Byron/dua-cli)

```bash
# dua

> Dua (Disk Usage Analyzer): get the disk space usage of a directory.
> More information: <https://github.com/Byron/dua-cli>.

- Analyze specific directory:

dua {{path/to/directory}}

- Display apparent size instead of disk usage:

dua --apparent-size

- Count hard-linked files each time they are seen:

dua --count-hard-links

- Aggregate the consumed space of one or more directories or files:

dua aggregate

- Launch the terminal user interface:

dua interactive

- Format printing byte counts:

dua --format {{metric|binary|bytes|GB|GiB|MB|MiB}}

- Use a specific number of threads (defaults to the process number of threads):

dua --threads {{count}}
```


### dust
`dust`は、`dua`と同様にディスク使用量を視覚化するツールですが、より詳細で直感的な情報を提供します。Rustで書かれており、非常に高速で使いやすい設計がされています。

- **機能**:
  - ディレクトリツリーの構造を可視化し、どのディレクトリがどれくらいの容量を使用しているかを表示します。
  - 使いやすいターミナルUIにより、大量のファイルやフォルダの中で容量を占める部分を直感的に把握できます。
- **パフォーマンス**: Rust言語の特徴である高速性を活かし、特に大規模なディレクトリやディスク全体の使用量を迅速に解析できます。
- **用途**: `dust`は、システムのディスク容量不足の際に、不要なファイルやフォルダを簡単に特定するのに優れています。また、ツリー構造で視覚的に表示するため、全体の状況を一目で把握できます。
- **特徴**:
  - ターミナルでの直感的な表示
  - シンプルでわかりやすい出力
  - 大規模ディレクトリに対する高速なスキャン能力
  - ファイル削除の支援機能

公式リポジトリ: [dust](https://github.com/bootandy/dust)

```bash
# dust

> Dust gives an instant overview of which directories are using disk space.
> More information: <https://github.com/bootandy/dust>.

- Display information for the current directory:

dust

- Display information about one or more directories:

dust {{path/to/directory1 path/to/directory2 ...}}

- Display 30 directories (defaults to 21):

dust --number-of-lines {{30}}

- Display information for the current directory, up to 3 levels deep:

dust --depth {{3}}

- Display the biggest directories at the top in descending order:

dust --reverse

- Ignore all files and directories with a specific name:

dust --ignore-directory {{file_or_directory_name}}

- Do not display percent bars and percentages:

dust --no-percent-bars
```

### その他

- https://github.com/muesli/duf
- https://github.com/solidiquis/erdtree
- https://github.com/Canop/broot


これらのツールは、それぞれ異なるシナリオにおいてディスク管理やクリーンアップを行うのに適しています。

### 参考

- https://github.com/topics/disk-usage