# WebGL 検証計画：Unity.InferenceEngine での動作確認

## 目的

Unity.InferenceEngine が WebGL プラットフォームで正常に動作するか検証する。
過去の ONNX Runtime Web で発生した「音声速度問題（4Dテンソル、5.35倍の長さ）」が Unity.InferenceEngine では発生しないことを確認する。

## ブランチ

- **ブランチ名**: `feature/webgl-unity-inference-engine`
- **ベース**: `main` (v0.2.0)

## 前提条件

### 現在の実装状況

- ✅ Unity.InferenceEngine 2.2.1 使用
- ✅ WebGL 自動バックエンド選択実装済み（GPUPixel）
- ✅ `InferenceAudioGenerator.cs:436-439` で WebGL 対応確認済み
- ✅ OpenJTalk は WebGL 非対応（`PlatformDefines.cs:11-15`）

### WebGL での制約

```csharp
// Assets/uPiper/Runtime/Core/Platform/PlatformDefines.cs
#if UNITY_WEBGL || UNITY_ANDROID || UNITY_IOS
    public const bool OPENJTALK_NATIVE_SUPPORTED = false;
#else
    public const bool OPENJTALK_NATIVE_SUPPORTED = true;
#endif
```

**重要**: WebGL では OpenJTalk ネイティブプラグインが使用できません。

## 検証手順

### Phase 1: ビルド前準備

#### 1.1 Unity エディタ設定確認

```bash
# Unity のバージョン確認
Unity -version
# 期待: 6000.0.55f1
```

#### 1.2 WebGL Build Settings 確認

Unity Editor で以下を確認：

1. **File > Build Settings > WebGL**
2. **Player Settings > WebGL**
   - Compression Format: **Disabled** (デバッグ用、後で Gzip に変更可)
   - Data Caching: ✅ Enabled
   - WebGL Memory Size: **512MB 以上**（推奨: 1024MB）
3. **Player Settings > Other Settings**
   - Scripting Backend: **IL2CPP**
   - Api Compatibility Level: **.NET Standard 2.1**

#### 1.3 必要なリソース確認

```bash
# ONNX モデルの存在確認
ls -lh Assets/uPiper/Resources/Models/*.onnx

# StreamingAssets の確認（WebGLでは使えないが存在確認）
ls -lh Assets/StreamingAssets/uPiper/
```

### Phase 2: WebGL ビルド実行

#### 2.1 コマンドラインビルド（推奨）

```bash
# ビルドディレクトリ作成
mkdir -p Build/WebGL

# Unity WebGL ビルド実行
/Applications/Unity/Hub/Editor/6000.0.55f1/Unity.app/Contents/MacOS/Unity \
  -quit \
  -batchmode \
  -nographics \
  -projectPath "$(pwd)" \
  -buildTarget WebGL \
  -buildPath "Build/WebGL" \
  -executeMethod UnityEditor.BuildPlayer.BuildPlayer \
  -logFile Build/webgl_build.log

# ビルドログ確認
tail -100 Build/webgl_build.log
```

#### 2.2 Unity Editor からビルド

1. **File > Build Settings**
2. **Platform: WebGL** を選択
3. **Switch Platform** をクリック
4. **Scenes In Build** に以下を追加：
   - `Assets/uPiper/Samples~/BasicTTSDemo/BasicTTSDemo.unity`
5. **Build** をクリック
6. 出力先: `Build/WebGL`

**ビルド時間**: 約 10-20分（初回は Unity WebGL モジュールのダウンロードで長くなる可能性）

### Phase 3: ローカルサーバーでのテスト

#### 3.1 Python 簡易サーバー起動（推奨）

```bash
cd Build/WebGL

# Python 3 の場合
python3 -m http.server 8000

# Python 2 の場合
python -m SimpleHTTPServer 8000
```

#### 3.2 Node.js サーバー起動（代替）

```bash
# http-server のインストール（初回のみ）
npm install -g http-server

# サーバー起動
cd Build/WebGL
http-server -p 8000 -c-1
```

#### 3.3 ブラウザでアクセス

```
http://localhost:8000/
```

**推奨ブラウザ**:
- Chrome 最新版
- Firefox 最新版
- Safari 17+ (macOS)

**注意**: `file://` プロトコルでは動作しません（CORS制限）

### Phase 4: 動作検証

#### 4.1 初期化確認

ブラウザの開発者コンソール（F12）で以下を確認：

```javascript
// 期待されるログ
[InferenceAudioGenerator] Platform: WebGLPlayer
[InferenceAudioGenerator] Auto-selecting GPUPixel backend for WebGL
[InferenceAudioGenerator] Successfully initialized with backend: GPUPixel
```

#### 4.2 日本語 TTS テスト

**テストケース 1: 短い日本語**

入力テキスト: `こんにちは`

期待される動作:
- エラーなく音声生成が開始される
- 音声の長さが適切（約 1-2秒）
- 音声速度が自然（早口でない）

**確認ポイント**:
```javascript
// コンソールログで確認
[InferenceAudioGenerator] Phoneme IDs: [phoneme count]
[InferenceAudioGenerator] Output shape: [shape]
[InferenceAudioGenerator] Audio duration: X.XX seconds
```

**重要**: 出力テンソルが **3D** であることを確認（過去の ONNX Runtime Web では 4D だった）

#### 4.3 英語 TTS テスト

**テストケース 2: 英語**

入力テキスト: `Hello World`

期待される動作:
- 音声生成が成功
- 音声の長さが適切（約 1-2秒）

#### 4.4 長文テスト

**テストケース 3: 長めの日本語**

入力テキスト: `これはWebGL環境でのUnity.InferenceEngineの動作テストです。`

期待される動作:
- メモリエラーが発生しない
- 音声生成時間が許容範囲内（10秒以内）
- 音声が途切れない

### Phase 5: 過去の問題との比較

#### 5.1 音声速度問題のチェック

過去の ONNX Runtime Web の問題:
- 出力テンソル: `[1, 1, 1, N]` (4D)
- 音声の長さ: 期待値の 5.35倍
- 対処: `length_scale × 0.82`

Unity.InferenceEngine での期待:
- 出力テンソル: `[1, 1, N]` (3D) または `[N]` (1D)
- 音声の長さ: 期待値通り
- 対処不要

#### 5.2 検証スクリプト

ブラウザコンソールで以下を実行：

```javascript
// 音声生成テスト
async function testAudioGeneration() {
    const text = "こんにちは";

    console.log("=== Test Start ===");
    console.log("Input text:", text);

    const startTime = performance.now();

    // TTS実行（Unity側のボタンクリックと同等）
    // 実際の実行は Unity WebGL の UI から行う

    const endTime = performance.now();
    console.log("Generation time:", (endTime - startTime) / 1000, "seconds");
    console.log("=== Test End ===");
}
```

## 検証結果の記録

### 記録すべき情報

1. **ビルド情報**
   - Unity バージョン
   - Inference Engine バージョン
   - ビルド時間
   - ビルドサイズ

2. **動作確認**
   - 初期化の成功/失敗
   - バックエンドタイプ（GPUPixel/CPU）
   - 各テストケースの結果

3. **パフォーマンス**
   - 音声生成時間
   - メモリ使用量
   - ブラウザコンソールのエラー/警告

4. **音声品質**
   - 音声の長さ（秒）
   - 音声速度（自然/早口/遅い）
   - 音質（明瞭/歪み/ノイズ）

### 結果の保存先

- `docs/webgl-verification-results.md` - 検証結果の詳細
- スクリーンショット: `docs/images/webgl-test/`
- ブラウザコンソールログ: テキストファイルとして保存

## トラブルシューティング

### ビルドエラー

**エラー**: `Building Library/Bee/artifacts/WebGLBuild failed`
- **原因**: WebGL モジュール未インストール
- **解決**: Unity Hub > Installs > Unity 6000.0.55f1 > Add Modules > WebGL Build Support

**エラー**: メモリ不足
- **解決**: Player Settings > WebGL Memory Size を増やす（2048MB）

### 実行時エラー

**エラー**: `Exception: Could not load signature of ...`
- **原因**: IL2CPP ビルドの問題
- **解決**: Player Settings > Stripping Level を "Minimal" に変更

**エラー**: `OutOfMemoryException`
- **原因**: WebGL メモリ不足
- **解決**:
  1. ブラウザでページをリロード
  2. 不要なブラウザタブを閉じる
  3. WebGL Memory Size を増やして再ビルド

### 音声問題

**問題**: 音声が生成されない
- **確認**: ブラウザコンソールでエラーログを確認
- **確認**: ONNX モデルが正しく読み込まれているか
- **確認**: Phonemizer が初期化されているか

**問題**: 音声が早口
- **これは過去の問題**: Unity.InferenceEngine では発生しないはず
- **もし発生したら**: 詳細なログを記録して調査

## 成功の定義

以下がすべて満たされた場合、検証成功とする：

1. ✅ WebGL ビルドがエラーなく完了
2. ✅ ローカルサーバーで正常に起動
3. ✅ Unity.InferenceEngine が GPUPixel で初期化
4. ✅ 日本語・英語の音声生成が成功
5. ✅ 音声の長さが適切（過去の5.35倍問題が発生しない）
6. ✅ 音声速度が自然（早口でない）
7. ✅ 重大なエラーが発生しない

## 次のステップ

### 検証成功の場合

1. 結果を `docs/webgl-verification-results.md` にまとめる
2. README の WebGL ステータスを更新
3. Issue #62 に報告
4. GitHub Pages へのデプロイを検討

### 検証失敗の場合

1. エラーログと詳細を記録
2. 失敗原因を分析
3. 代替案を検討：
   - ONNX Runtime Web への切り替え
   - オンデマンドリソース読み込みの実装
   - サーバーサイド TTS（制約により困難）

## 関連ドキュメント

- `docs/webgl-implementation-strategy.md` - 長期的な WebGL 戦略
- `docs/issue-62-response.md` - Issue #62 の調査結果
- `docs/ja/guides/webgl/unity-webgl-audio-issue-complete-investigation.md` - 過去の問題記録
