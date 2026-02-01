# SilentCamera - シャッター音なしカメラ

iPhoneで使える、シャッター音が鳴らないカメラアプリです。

## 仕組み

通常の`AVCapturePhotoOutput`を使うとシステムのシャッター音が再生されますが、
このアプリでは`AVCaptureVideoDataOutput`からビデオフレームをキャプチャすることで、
シャッター音を回避しています。

## 機能

- **サイレント撮影** - シャッター音なしで写真を撮影
- **フロント/バックカメラ切替** - ワンタップでカメラを切り替え
- **ピンチズーム** - ピンチジェスチャーでズーム操作
- **タップフォーカス** - 画面タップでフォーカスポイントを指定
- **フラッシュ(トーチ)** - バックカメラでフラッシュ撮影
- **写真プレビュー** - 撮影した写真をその場で確認
- **写真保存** - カメラロールへ保存
- **共有・コピー** - 他のアプリへの共有、クリップボードへのコピー

## 動作要件

- iOS 16.0+
- Xcode 15.0+
- Swift 5.0+

## ビルド方法

1. `SilentCamera.xcodeproj` を Xcode で開く
2. Signing & Capabilities で自分の開発チームを設定
3. 実機を接続してビルド&実行

> **注意**: カメラ機能はシミュレータでは動作しません。実機が必要です。

## プロジェクト構成

```
SilentCamera/
├── SilentCameraApp.swift       # アプリエントリポイント
├── Info.plist                   # カメラ・写真ライブラリ権限設定
├── Assets.xcassets/             # アプリアイコン等
├── Views/
│   ├── CameraView.swift         # メインカメラUI
│   └── CameraPreview.swift      # AVCapturePreviewLayer ラッパー
└── Services/
    └── CameraService.swift      # カメラ制御・サイレントキャプチャ
```
