# SilentCamera - サイレントカメラ (Web版)

ブラウザで動作する、シャッター音が鳴らないカメラアプリです。
**GitHub Pages で公開するだけで、どこからでもアクセスできます。**

iPhone / Android / PC — ブラウザさえあればOK。

## 公開方法 (GitHub Pages・無料)

### 初回セットアップ

1. このリポジトリを GitHub にプッシュ (mainブランチ)
2. GitHub のリポジトリページで **Settings → Pages** を開く
3. **Source** を **GitHub Actions** に設定
4. 自動デプロイが実行され、以下のURLで公開される:

```
https://<あなたのユーザー名>.github.io/<リポジトリ名>/
```

以降は `main` ブランチにプッシュするたびに自動デプロイされます。

### iPhoneからアクセスする

公開されたURLをiPhoneのSafari/Chromeで開くだけです。
GitHub Pages は HTTPS なので、カメラAPIも問題なく動作します。

> **ホーム画面に追加**: Safari で「共有 → ホーム画面に追加」すると
> アプリのように使えます (PWA対応)。

## 仕組み

ブラウザの `MediaStream API` でカメラ映像を取得し、
`Canvas API` でビデオフレームを静止画としてキャプチャします。
ブラウザのカメラAPIにはシャッター音の仕組みがないため、完全に無音で撮影できます。

## 機能

- **サイレント撮影** - シャッター音なしで写真を撮影
- **フロント/バックカメラ切替** - ワンタップで切り替え
- **ピンチズーム** - ピンチ (モバイル) / マウスホイール (PC)
- **タップフォーカス** - 画面タップでフォーカス調整 (対応デバイスのみ)
- **フラッシュ(トーチ)** - バックカメラでトーチライト (対応デバイスのみ)
- **写真プレビュー** - 撮影した写真をその場で確認
- **ダウンロード保存** - JPEGファイルとして保存
- **クリップボードコピー** - 画像をコピー
- **共有** - Web Share API で他アプリへ送信
- **キーボードショートカット** - スペースキーで撮影 (PC)
- **PWA対応** - ホーム画面に追加でアプリ風に使用可能

## ローカル開発

```bash
# Python 3
python -m http.server 8000

# Node.js
npx serve .
```

`http://localhost:8000` で動作確認できます。

## 動作要件

- モダンブラウザ (Chrome, Safari, Edge, Firefox)
- HTTPS 接続 (GitHub Pages / localhost)
- Windows のみで開発可能、ビルドツール不要

## プロジェクト構成

```
index.html                  # アプリ本体 (HTML + CSS + JS)
manifest.json               # PWAマニフェスト
sw.js                       # Service Worker (オフライン対応)
.github/workflows/deploy.yml  # GitHub Pages 自動デプロイ
```

外部ライブラリ依存なし。単一HTMLファイル + PWA設定のみ。
