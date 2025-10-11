# WebGL クイックスタートガイド

Unity.InferenceEngine を使った WebGL ビルドの検証手順

## 前提条件

- Unity 6000.0.55f1 インストール済み
- WebGL Build Support モジュールインストール済み
- Python 3 または他の HTTP サーバー

## 手順

### 1. ブランチの確認

```bash
git branch
# feature/webgl-unity-inference-engine にいることを確認
```

### 2. WebGL ビルドの実行

#### 方法A: スクリプト使用（推奨）

```bash
./scripts/build-webgl.sh
```

**所要時間**: 初回 15-20分、2回目以降 5-10分

#### 方法B: Unity Editor から

1. Unity Editor でプロジェクトを開く
2. **File > Build Settings**
3. **Platform: WebGL** を選択
4. **Switch Platform** をクリック（初回のみ、数分かかる）
5. **Player Settings** で以下を確認：
   - Compression Format: Disabled（デバッグ用）
   - WebGL Memory Size: 1024MB 以上
6. **Build** をクリック
7. 出力先: `Build/WebGL`

### 3. ローカルサーバーの起動

```bash
./scripts/serve-webgl.sh
```

または手動で：

```bash
cd Build/WebGL
python3 -m http.server 8000
```

### 4. ブラウザで確認

```
http://localhost:8000
```

**推奨ブラウザ**: Chrome 最新版

### 5. 動作テスト

#### 開発者コンソール（F12）を開く

以下のログを確認：

```
[InferenceAudioGenerator] Platform: WebGLPlayer
[InferenceAudioGenerator] Auto-selecting GPUPixel backend for WebGL
[InferenceAudioGenerator] Successfully initialized
```

#### 音声生成テスト

1. **日本語テスト**: `こんにちは` と入力して生成
2. **英語テスト**: `Hello World` と入力して生成

#### 確認ポイント

- [ ] エラーなく音声が生成される
- [ ] 音声の長さが適切（1-2秒程度）
- [ ] 音声速度が自然（早口でない）
- [ ] コンソールに重大なエラーがない

### 6. 結果の記録

`docs/webgl-verification-results.md` に結果を記入してください。

## トラブルシューティング

### ビルドエラー

**Q**: `WebGL module not installed`
**A**: Unity Hub > Installs > Add Modules > WebGL Build Support

**Q**: `Building failed with errors`
**A**: ビルドログを確認
```bash
tail -100 Build/webgl_build.log
```

### 実行時エラー

**Q**: ブラウザで真っ白な画面
**A**:
1. ブラウザコンソール（F12）でエラー確認
2. ファイルサーバーが正しく動作しているか確認
3. `file://` ではなく `http://localhost` でアクセスしているか確認

**Q**: `OutOfMemoryException`
**A**:
1. Player Settings > WebGL Memory Size を 2048MB に増やす
2. ブラウザを再起動
3. 不要なタブを閉じる

**Q**: 音声が生成されない
**A**:
1. コンソールでエラーログを確認
2. ONNX モデルが正しく読み込まれているか確認
3. バックエンドタイプを確認（GPUPixel が推奨）

## 期待される結果

### 成功の場合

- ✅ WebGL ビルドが完了
- ✅ Unity が WebGL 環境で起動
- ✅ 音声生成が正常に動作
- ✅ 音声速度が自然（**過去の5.35倍問題が解決**）

### 失敗の場合

詳細なエラーログとブラウザコンソールのスクリーンショットを保存して、
`docs/webgl-verification-results.md` に記録してください。

## 次のステップ

### 成功した場合

1. 結果を `docs/webgl-verification-results.md` にまとめる
2. スクリーンショットを保存
3. Issue #62 に報告
4. GitHub Pages デプロイを検討

### 失敗した場合

1. エラーの詳細を記録
2. 代替案を検討（ONNX Runtime Web など）
3. Issue #62 に状況を報告

## 参考資料

- 詳細な検証計画: `docs/webgl-verification-plan.md`
- 結果記録テンプレート: `docs/webgl-verification-results.md`
- 過去の問題記録: `docs/ja/guides/webgl/unity-webgl-audio-issue-complete-investigation.md`
- Issue #62: https://github.com/ayutaz/uPiper/issues/62

## よくある質問

**Q**: Unity のパスが見つからない
**A**: `scripts/build-webgl.sh` の `UNITY_PATH` を編集してください

**Q**: ビルドに時間がかかりすぎる
**A**: 初回は WebGL ライブラリのビルドで時間がかかります。2回目以降は高速です。

**Q**: メモリ不足エラー
**A**: Player Settings > WebGL Memory Size を増やしてください

**Q**: 音声が早口になる（過去の問題）
**A**: これは Unity.InferenceEngine では発生しないはずです。もし発生したら詳細を記録してください。

---

**問題が発生した場合は、Issue #62 で報告してください。**
