# Pulseee(従業員パルスサーベイシステム)

## 画面モック
①ログイン画面
<img width="1879" height="930" alt="image" src="https://github.com/user-attachments/assets/d3f017f9-336e-4219-9028-e81a380e5b98" />

②-1 アンケート回答画面（アンケート回答前）
<img width="1894" height="931" alt="image" src="https://github.com/user-attachments/assets/2dde5b4e-1cb4-4447-b29f-93b99641b55d" />

②-2 アンケート回答画面（アンケート回答済み）
<img width="1687" height="1005" alt="LINE_P202667_222155_new" src="https://github.com/user-attachments/assets/dbeb9e22-8ab4-406c-a825-64fafcb5c827" />

③アンケート画面（一部のみ表示）
<img width="1580" height="317" alt="image" src="https://github.com/user-attachments/assets/86f56f08-5f66-4613-b235-7135c9996e32" />

## Google認証の設定

Googleログインを使うには、アプリ起動前に OAuth Client ID / Secret を設定してください。

```bash
export GOOGLE_CLIENT_ID="your-google-oauth-client-id"
export GOOGLE_CLIENT_SECRET="your-google-oauth-client-secret"
bin/rails server
```

Rails credentials を使う場合は以下のキーでも読み込めます。

```yaml
google_oauth:
  client_id: your-google-oauth-client-id
  client_secret: your-google-oauth-client-secret
```

Google Cloud Console 側の承認済みリダイレクトURIには、ローカル開発では以下を登録してください。

```text
http://localhost:3000/auth/google_oauth2/callback
http://127.0.0.1:3000/auth/google_oauth2/callback
```

### ローカル開発でGoogle認証をモックする

ローカル開発で実際のGoogle OAuthを使わずに通常のOmniAuthコールバック経路を確認したい場合は、`MOCK_GOOGLE_AUTH=1` を指定してください。

```bash
MOCK_GOOGLE_AUTH=1 bin/rails server
```

モックユーザーのメールアドレスは、既定では seed に含まれる `kim@localworks.jp` です。別の事前登録ユーザーで確認したい場合は `DEV_LOGIN_EMAIL` を指定してください。

```bash
MOCK_GOOGLE_AUTH=1 DEV_LOGIN_EMAIL="member@example.com" bin/rails server
```

## 開発用ログイン

Google認証を設定していない開発環境では、ログイン画面に「開発用ログイン」ボタンが表示されます。

既定では seed に含まれる `kim@localworks.jp` でログインします。

```bash
bin/rails db:seed
bin/rails server
```

サーベイが表示されない場合も、もう一度 `bin/rails db:seed` を実行してください。開発用ログインユーザーに未回答サーベイがない場合、確認用サーベイが作成されます。

別の事前登録ユーザーでログインしたい場合は、`DEV_LOGIN_EMAIL` を指定してください。

```bash
DEV_LOGIN_EMAIL="member@example.com" bin/rails server
```
