# Dify on GKE 設定方法

## 必要なGoogle Cloud リソース

### Cloud SQL インスタンス (PostgreSQL)

- ユーザー`dify`の作成とパスワードの設定
- データベース `dify` `dify_plugin` `dify_vector` の作成
- [pgvector](https://cloud.google.com/blog/ja/products/databases/faster-similarity-search-performance-with-pgvector-indexes?hl=ja) extentionのインストール `CREATE EXTENSION IF NOT EXISTS vector;`
- pg_bigm拡張機能のインストール `CREATE EXTENSION IF NOT EXISTS pg_bigm`;

### Kubernetesクラスタ

- Workload Identityの有効化
- Gateway APIの有効化
- GcsFuseCsiDriver, HttpLoadBalancing addonの有効化
- [external secrets operator](https://external-secrets.io/latest/)のインストール

### IAN

`dify` KSAに対して以下の役割を付与
※ Storageの役割はバケットレベルへの付与を推奨

- Cloud SQL Client
- Kubernetes Engince Cluster Viewer
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
- DIFY_SANDBOX_API_KEY
- DIFY_SECRET_KEY

### Certificate Manager

任意のホスト名に対するcertificateとcertificate-mapの作成

### Google Cloud Storage

- dify-sandbox用バケット

## helmの適用準備

valkey Chartのダウンロード

```
helm dependency update
```

インストール先のnamespaceの作成

```
kubectl create ns <任意の名前>
```

helm templateの適用

```
helm template dify . -f values.yaml --namespace <namespace> | kubectl apply -f -
```