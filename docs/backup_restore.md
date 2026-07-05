# DBバックアップ・リストア運用設計

## 目的

Pulseeeの本番データを、誤操作・障害・デプロイ不具合・データ破損から復旧できる状態にする。

このドキュメントでは、Neon Postgresを前提に、バックアップ設計、リストア手順、避難訓練の進め方を定義する。

## 前提

- 本番Railsアプリは `DATABASE_URL` でPostgreSQLへ接続する。
- 本番DBはNeon Postgresを利用する想定とする。
- 定期実行が必要な場合、実行時刻はRender Cron側で管理する。
- Render CronのスケジュールはUTCで設定する。
- DBにはユーザー、権限、サーベイ、回答依頼、匿名化されたスコア回答が含まれる。

## 守るべきデータ

最優先で保護するデータは、サーベイ回答結果そのものである `score_answers` とする。

- `score_answers`

ただし、`score_answers` 単体では、どのサーベイのどの設問に対する回答か、グループ別集計、回答率を復元できない。
そのため、実際のバックアップ対象はDB全体とする。

復旧時に合わせて必要になる主な周辺データは以下。

- `surveys`
- `questions`
- `survey_questions`
- `survey_assignments`
- `users`
- `groups`
- `answer_group_snapshots`
- `roles`
- `user_roles`

キャッシュや再生成可能な一時データは、復旧優先度を下げる。

## 目標値

初期運用では以下を目安とする。

| 項目     | 目標                                                                                                                                 |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| RPO      | S3日次バックアップにより最大24時間以内のデータ損失に抑える。直近6時間以内の事故はNeonのPoint-in-Time Restoreで短縮できる可能性がある |
| RTO      | 2時間以内に復旧方針を判断し、半日以内に復旧する                                                                                      |
| 保存期間 | S3の日次バックアップを30日保持する。Neonのrestore windowは短期復旧の補助として扱う                                                   |
| 復旧担当 | Neon/Renderにアクセスできる管理者                                                                                                    |

RPO/RTOは運用開始後、実際の重要度に合わせて見直す。

## バックアップ方針

### 基本方針

S3日次バックアップを主系統のバックアップとする。
Neon Freeプランのrestore windowは6時間に限られるため、NeonのPoint-in-Time Restoreは短期復旧の補助手段として扱う。

- S3日次バックアップを復旧設計の主系統とする。
- 6時間以内の誤操作や障害では、NeonのPoint-in-Time Restoreも復旧候補にする。
- 6時間を超えてから発見した事故、Neon側の障害、アカウント操作ミス、ブランチ操作ミスでは、S3バックアップから復元する。
- 重要作業前は、必要に応じてRender Cronを手動実行し、S3へ追加バックアップを取得する。
- 本番DBを直接上書きする前に、復元先のブランチまたは一時DBで内容を確認する。

### 外部バックアップ

Neon Freeプランのrestore windowは6時間のため、日次バックアップをS3へ保存する。
S3バックアップは、Neon側の短い復元可能期間を補う主系統のバックアップとする。
復旧判断では、まずS3バックアップの有無と最新時刻を確認し、直近6時間以内の事故であればNeonのPoint-in-Time Restoreも候補に入れる。

### S3日次バックアップ

Render Cronから `bin/backup_database_to_s3` を毎日01:00 JSTに実行する。

Render Cronの設定:

```text
Schedule: 0 16 * * *
Command: bin/backup_database_to_s3
```

`0 16 * * *` はUTC 16:00を表し、日本時間の翌日01:00に相当する。

バックアップ処理:

1. Render Cronが `bin/backup_database_to_s3` を実行する。
2. スクリプトが `DATABASE_URL` を使って本番DBに接続する。
3. `pg_dump` でDBバックアップファイルを作成する。
4. `gzip` でバックアップファイルを圧縮する。
5. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` でAWS認証を行う。
6. `aws s3 cp` でS3バケットへアップロードする。
7. S3にバックアップファイルが保存される。
8. 成功/失敗を標準出力/標準エラーへ出す。
9. 失敗時は非0終了し、Render Cronの失敗検知に任せる。

保存先:

```text
s3://<S3_BACKUP_BUCKET>/<S3_BACKUP_PREFIX>/pulseee-production-YYYYMMDD-HHMMSS.sql.gz
```

`S3_BACKUP_PREFIX` を未設定にした場合の既定値:

```text
pulseee/production/db/daily
```

必要な環境変数:

| 変数名                  | 用途                                                 |
| ----------------------- | ---------------------------------------------------- |
| `DATABASE_URL`          | Neon DBへの接続URL                                   |
| `S3_BACKUP_BUCKET`      | バックアップ保存先S3バケット                         |
| `S3_BACKUP_PREFIX`      | 保存prefix。未設定時は `pulseee/production/db/daily` |
| `AWS_ACCESS_KEY_ID`     | S3アップロード用IAMユーザーのアクセスキー            |
| `AWS_SECRET_ACCESS_KEY` | S3アップロード用IAMユーザーのシークレット            |
| `AWS_REGION`            | S3バケットのリージョン                               |

S3の保持期間は、S3 Lifecycle Ruleで管理する。
初期設定では日次バックアップを30日保持する。

Render Cronの実行ログは、Render側のログ保持・ローテーション設定に従う。
初期運用ではログローテーション期間を1週間とし、直近1週間分のバックアップ実行結果を確認できる状態にする。

IAM権限は、対象バケットのバックアップprefixへの書き込みに限定する。

```text
s3://<S3_BACKUP_BUCKET>/pulseee/production/db/daily/*
```

`S3_BACKUP_PREFIX` を変更する場合は、IAM権限の対象prefixも合わせて変更する。

### S3バックアップを見直す条件

以下のいずれかに当てはまる場合は、S3バックアップの頻度・保持期間・保存先を見直す。

- 24時間RPOでは足りない。
- 30日より長くバックアップを保持したい。
- Neonアカウント自体の誤操作・権限喪失にも備えたい。
- 監査・社内ルール上、Neon外への保管が必要。
- 本番DBを別クラウドやローカル環境へ復元する訓練が必要。

見直し時は、バックアップ頻度、S3 Lifecycle Rule、暗号化、アクセス制御、別リージョン保管の要否を再定義する。

## Render Cronで実行する場合の時刻

Render CronはUTCでスケジュールを設定する。

| 用途                 | 日本時間   | Render Cron |
| -------------------- | ---------- | ----------- |
| チーム別週次集計     | 月曜 8:00  | `0 23 * * 0` |
| 月曜朝の集計         | 月曜 9:00  | `0 0 * * 1` |
| 木曜夕方のリマインド | 木曜 18:00 | `0 9 * * 4` |

チーム別週次集計はRender Cronから以下を実行する。

```text
Command: bin/rails survey:aggregate_weekly_scores
Schedule: 0 23 * * 0
```

## リストア方針

リストアは、本番DBを直接上書きしないことを原則とする。

1. 事故内容を確認する。
2. 復旧したい時刻を決める。
3. Neonで復元候補をプレビューする。
4. 復元先ブランチまたは一時DBを作成する。
5. アプリから接続できるか確認する。
6. データ件数・主要画面・CSV出力を確認する。
7. 問題がなければ本番切り替え、または本番ブランチのrestoreを実行する。

## リストア手順

### 1. 事故内容を整理する

以下を記録する。

- 発生日時
- 発見者
- 影響範囲
- 失われた、または壊れた可能性があるデータ
- 最後に正常だったと考えられる時刻
- デプロイ、マイグレーション、手動操作の有無

### 2. 復旧ポイントを決める

Neon Consoleで、復旧候補時刻を選ぶ。

目安:

- 誤削除: 削除直前
- マイグレーション不具合: マイグレーション実行直前
- データ修正ミス: 修正実行直前

復旧候補はJSTとUTCの両方で記録する。

### 3. 復元前にデータを確認する

NeonのBackup & restore画面で、選択した時点のデータをプレビューする。

確認例:

```sql
select count(*) from public.users;
select count(*) from public.surveys;
select count(*) from public.survey_assignments;
select count(*) from public.score_answers;
```

必要に応じて、壊れたと疑われるテーブルを個別に確認する。

### 4. 一時環境で検証する

可能であれば、本番ブランチを直接restoreせず、復元用ブランチを作成して検証する。

検証項目:

- RailsがDBへ接続できる
- ログインできる
- 管理画面を開ける
- 直近サーベイを確認できる
- CSVダウンロードが動く
- 件数が期待値に近い

### 4-1. S3バックアップから検証用DBへ復元する

S3の日次バックアップから復元する場合は、必ず検証用DBへ復元する。
本番DBへ直接流し込まない。

S3からバックアップファイルを取得する。

```bash
aws s3 cp s3://<S3_BACKUP_BUCKET>/<S3_BACKUP_PREFIX>/pulseee-production-YYYYMMDD-HHMMSS.sql.gz /tmp/pulseee-restore.sql.gz
```

検証用DBへ復元する。

```bash
gunzip -c /tmp/pulseee-restore.sql.gz | psql "$RESTORE_DATABASE_URL"
```

復元後、最低限以下を確認する。

```sql
select count(*) from public.users;
select count(*) from public.surveys;
select count(*) from public.survey_assignments;
select count(*) from public.score_answers;
```

`search_path` が空の場合、`\dt` ではテーブルが表示されないことがある。
その場合は `public.テーブル名` を指定して確認するか、以下を実行してから確認する。

```sql
set search_path to public;
\dt
```

### 5. 本番復旧を実行する

一時環境で問題がないことを確認してから、本番復旧を行う。

本番ブランチをrestoreする場合、Neon側で現在の状態がバックアップブランチとして残ることを確認する。

注意:

- restoreはマージではなく上書きである。
- 対象ブランチ上の全DBに影響する。
- 接続中のアプリは一時的に切断される可能性がある。

### 6. 復旧後確認

復旧後、以下を確認する。

- アプリが起動している
- ログインできる
- 管理画面を開ける
- 直近サーベイの回答状況が期待どおり
- CSVダウンロードができる
- Render Cronやジョブが異常終了していない
- Neon/Renderの接続情報が変わっていない、または必要な更新が完了している

## 避難訓練

四半期に1回、または大きな運用変更前に実施する。

### 訓練内容

1. 復元元のS3バックアップファイルを1つ決める。
2. Neonで検証用ブランチ、または一時DBを作る。
3. S3バックアップを検証用DBへ復元する。
4. 一時的な接続先でRailsからDB接続できるか確認する。
5. 管理画面・CSV・件数チェックを実施する。
6. 所要時間、詰まった箇所、改善点を記録する。

### 訓練ログ

以下を記録する。

| 項目                        | 内容 |
| --------------------------- | ---- |
| 実施日                      |      |
| 実施者                      |      |
| 対象DB/ブランチ             |      |
| 復元元時刻/スナップショット |      |
| 復元先                      |      |
| RTO実績                     |      |
| 確認した画面・データ        |      |
| 問題点                      |      |
| 次回改善                    |      |

### 訓練ログ: 2026-06-27

| 項目                 | 内容                                                                                                       |
| -------------------- | ---------------------------------------------------------------------------------------------------------- |
| 実施日               | 2026-06-27                                                                                                 |
| 実施者               | 金                                                                                                         |
| 対象DB/ブランチ      | Neon検証用ブランチ `restore-drill-20260627`                                                                |
| 復元元S3ファイル     | `s3://pulseee-production/pulseee/production/db/daily/pulseee-production-20260627-151635.sql.gz`            |
| 復元先               | Neon検証用ブランチ `restore-drill-20260627`                                                                |
| RTO実績              | 未計測                                                                                                     |
| 確認した画面・データ | `users`: 15件、`surveys`: 8件、`survey_assignments`: 76件、`score_answers`: 190件                          |
| 開発環境での動作確認 | 復元DBを `DATABASE_URL` に指定してRailsをdevelopment環境で起動。トップページ、開発用ログイン、ログイン後トップ、Rails Admin、サーベイ運用画面がHTTP 200で応答することを確認した。 |
| 未確認項目           | 復元時点に有効なサーベイがなかったため、回答画面は未確認。CSVダウンロードも今回の訓練では未確認。         |
| 問題点               | `search_path` が空だったため `\dt` ではテーブルが見えなかった。`public.テーブル名` で確認した。            |
| 結果                 | S3バックアップから検証用DBへの復元に成功                                                                   |
| 次回改善             | 復元後確認手順では `public.テーブル名` を指定するか、`set search_path to public;` を実行してから確認する。復旧訓練では、DB件数確認に加えて復元DBを使ったRails起動・ログイン・管理画面・CSVダウンロード・回答画面確認まで実施する。 |

## 未決事項

- Neonの本番プロジェクト名、ブランチ名、DB名

## 参考

- [運用失敗時の通知ルール](operation_failure_notification.md)
- Neon Backup & restore: https://neon.com/docs/guides/backup-restore
- Neon Instant restore: https://neon.com/docs/introduction/branch-restore
- Neon Restore window: https://neon.com/docs/introduction/restore-window
- Render Cron Jobs: https://render.com/docs/cronjobs
