# Dify on GKE 設定方法

GKE上にDifyを構築するためのHelm Chart。対象バージョンは Dify 1.19.0。

## 構成

| コンポーネント | 内容 |
| --- | --- |
| api | Dify本体のAPI。起動時にDBマイグレーションを実行する |
| worker | Celeryワーカー |
| worker-beat | Celery beat。スケジュールトリガーなどの定期タスクを起動する(常に1レプリカ) |
| web | フロントエンド |
| plugin-daemon | プラグインの実行基盤 |
| sandbox | コード実行ノード用のサンドボックス |
| ssrf-proxy | Difyから外部へ出るHTTPリクエストを中継するプロキシ(squid) |
| valkey | Redis互換のキャッシュ / Celeryブローカー。sentinel構成の3ノード |
| valkey-haproxy | 常に現在のValkeyのmasterへ転送するプロキシ |

DBはCloud SQL(各PodのCloud SQL Auth Proxyサイドカー経由)、ファイルストレージはGoogle Cloud Storage、公開はGateway APIを使う。

Dify Agent(Agent v2)とコラボレーション機能(ワークフローの共同編集)は含めていない。

## 必要なGoogle Cloud リソース

### Cloud SQL インスタンス (PostgreSQL)

- ユーザー`dify`の作成とパスワードの設定
- データベース `dify` `dify_plugin` `dify_vector` の作成
- [pgvector](https://cloud.google.com/blog/ja/products/databases/faster-similarity-search-performance-with-pgvector-indexes?hl=ja) extentionのインストール `CREATE EXTENSION IF NOT EXISTS vector;`
- pg_bigm拡張機能のインストール `CREATE EXTENSION IF NOT EXISTS pg_bigm`;

### Kubernetesクラスタ

- Workload Identityの有効化
- Gateway APIの有効化
- HttpLoadBalancing addonの有効化
- [external secrets operator](https://external-secrets.io/latest/)のインストール(`external-secrets.io/v1` を使うので v0.16 以上)

### IAM

`dify` KSAに対して以下の役割を付与
※ Storageの役割はバケットレベルへの付与を推奨

- Cloud SQL Client
- Kubernetes Engine Cluster Viewer
- Storage Bucket Viewer
- Storage Object Admin
- Vertex AI User

`external-secrets` KSAに対して以下の役割を付与

- Kubernetes Engine Cluster Viewer
- Secret Manager Secret Accessor

### Secret Manager

以下の値を用意

- DIFY_CODE_EXECUTION_API_KEY
- DIFY_DB_PASSWORD (Cloud SQLユーザー作成時に決めたもの)
- DIFY_INIT_PASSWORD (なんでもいい)
- DIFY_PLUGIN_DAEMON_KEY
- DIFY_PLUGIN_INNER_API_KEY
- DIFY_RESEND_API_KEY (招待メールを送るために本来必要なんだけど、招待メールはなくてもURLでjoinできるので、適当な値でも良い)
- DIFY_SECRET_KEY

### Certificate Manager

任意のホスト名に対するcertificateとcertificate-mapの作成

### Google Cloud Storage

- Difyのファイルストレージ用バケット

## values.yamlの設定

`# Fixme` と書かれた箇所を環境に合わせて書き換える。

| 項目 | 内容 |
| --- | --- |
| `global.project` | GCPプロジェクトID |
| `cloudSqlProxy.instance` | Cloud SQLのインスタンス名 |
| `config.GOOGLE_STORAGE_BUCKET_NAME` | ファイルストレージ用バケット名 |
| `config.ENDPOINT_URL_TEMPLATE` | `<YOUR_HOST_NAME>` を公開ホスト名に置き換える |
| `gateway.hostName` など | 公開ホスト名、グローバルIPアドレス名、SSLポリシー名、certificate-map名 |
| `affinity` / `valkey.affinity` / `valkey.haproxy.affinity` | Podを配置するノードプール名 |
| Valkeyのパスワード | 下記の4箇所に同じ値を入れる |

Valkeyのパスワードは次の4箇所に書く。

- `config.REDIS_PASSWORD`
- `config.REDIS_SENTINEL_PASSWORD`
- `config.CELERY_SENTINEL_PASSWORD`
- `config.CELERY_BROKER_URL` の中(3箇所)

### Valkey(sentinel構成)

- 各PodにValkey本体とsentinelが同居する。masterが停止すると、sentinelが別のノードをmasterに昇格させる。
- api / worker / plugin-daemonとCeleryは、sentinelに現在のmasterを問い合わせて接続する。
- API / worker間のevent bus(ストリーミング応答の中継)だけはsentinelに対応していないため、`REDIS_HOST`(`dify-valkey-primary`)に接続する。これはHAProxyのServiceで、常に現在のmasterへ転送する。
- `config.REDIS_SENTINELS` と `config.CELERY_BROKER_URL` にはPodのホスト名を直接書いている。`valkey.replicas` を変えたら、この2つも合わせて書き換える。
- データはPodごとのディスク(`valkey.persistence`)に保存する。StorageClassは `standard-rwo-retain` なので、StatefulSetを削除してもPVCとディスクは残る。

### ssrf-proxyの許可リスト

DifyのHTTPリクエストノードやMCPツールなどが出すリクエストはssrf-proxyを通る。プライベートIP宛ては既定で拒否され、`ssrf_proxy.config` で許可した宛先だけが通る。

```yaml
ssrf_proxy:
  config:
    allowPrivateIps: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    allowPrivateDomains: ""
```

- 既定値はプライベートIP(RFC1918)をすべて許可している。Difyでワークフローを作れるユーザーは、クラスタ内やVPC内のHTTPエンドポイントにアクセスできる。
- 不特定のユーザーに使わせる場合は、必要な宛先だけに絞る(例: `allowPrivateIps: "10.20.30.40/32"`)。
- メタデータサーバー(169.254.169.254)は許可に含めていない。含めるとPodのサービスアカウントのトークンを取得できてしまう。

## helmの適用準備

リリース名は `dify` にする。values.yamlがService名(`dify-api`、`dify-valkey-primary` など)を直接参照しているため。

インストール先のnamespaceの作成

```
kubectl create ns <任意の名前>
```

helm templateの適用

```
helm template dify . -f values.yaml --namespace <namespace> | kubectl apply -f -
```

## 注意点

- apiは2レプリカで起動し、DBマイグレーションは先にロックを取った1つだけが実行する。初回構築時は、マイグレーションが終わるまでもう一方のapiがエラーを返すことがある。
- Valkeyの全Podが同時に停止したあとは、常にPod 0がmasterになる。
- Playwrightのブラウザサーバーは既定で無効(`playwright.enabled`)。
