# WebGL 実装戦略（Issue #62）

## 背景

過去2回の試行（`feature/webgl-implementation`, `deploy/webgl-pages`）で以下の問題に直面：
- ファイルサイズ制限（GitHub Pages 100MB）
- 音声速度問題（ONNX Runtime Web の 4D テンソル出力）
- OpenJTalk ネイティブプラグインの非対応

## 制約条件

- ✅ 日本語対応は必須
- ✅ クライアントサイド処理（サーバーサイドTTS不可）
- ✅ Unity.InferenceEngine 使用（WebGL サポート確認済み）

## 新アプローチ：オンデマンドリソース読み込み

### Phase 1: 最小初期ロード（優先度：高）

**目標**: 初期ビルドを 30MB 以下に抑える

#### 初期パッケージ内容
- Unity WebGL フレームワーク（10-15MB）
- 基本UI とローダーシステム（< 1MB）
- プレースホルダー or 超軽量モデル（オプション）

#### オンデマンド読み込みリソース（GitHub Releases / CDN）
1. **日本語 ONNX モデル** - 60MB
   - `ja_JP-test-medium.onnx`
   - UnityWebRequest で非同期ダウンロード
   - IndexedDB にキャッシュ

2. **英語 ONNX モデル** - 61MB（オプション）
   - `en_US-ljspeech-medium.onnx`
   - 必要に応じてダウンロード

3. **OpenJTalk 辞書** - 23MB（zip圧縮済み）
   - `naist_jdic.zip`
   - ダウンロード後に展開（IndexedDB）

4. **CMU 辞書** - 3.5MB
   - `cmudict-0.7b.txt`
   - 英語使用時のみダウンロード

### Phase 2: リソース管理システムの実装

#### ResourceLoader クラス
```csharp
public class WebGLResourceLoader : MonoBehaviour
{
    // GitHub Releases URL (tag v0.2.0 など)
    private const string BASE_URL = "https://github.com/ayutaz/uPiper/releases/download/{version}";

    // IndexedDB キャッシュキー
    private const string CACHE_KEY_PREFIX = "uPiper_resource_";

    public async Task<ModelAsset> LoadModelAsync(string modelName, IProgress<float> progress)
    {
        // 1. IndexedDB キャッシュ確認
        // 2. キャッシュミス → ダウンロード
        // 3. ModelAsset に変換
        // 4. IndexedDB に保存
    }

    public async Task<byte[]> LoadDictionaryAsync(string dictName, IProgress<float> progress)
    {
        // 同様のフロー
    }
}
```

#### UI 改善
- ダウンロード進捗バー
- 「初回のみダウンロードが必要です（約84MB）」の表示
- キャッシュクリアボタン

### Phase 3: Unity.InferenceEngine 統合

#### WebGL 専用バックエンド選択
```csharp
#if UNITY_WEBGL
    // GPUPixel が推奨（InferenceAudioGenerator.cs で自動選択済み）
    var config = new PiperConfig
    {
        Backend = InferenceBackend.Auto, // WebGL では GPUPixel に自動選択
        AllowFallbackToCPU = true
    };
#endif
```

#### OpenJTalk の代替
WebGL ではネイティブプラグインが使えないため：
- **短期**: SimpleLTS または FliteLTS phonemizer を使用（精度低下）
- **中期**: WebAssembly 版 OpenJTalk の開発
- **長期**: JavaScript 実装の簡易音素化エンジン

### Phase 4: デプロイ戦略

#### GitHub Pages デプロイ
1. **本体ビルド**（< 30MB）を GitHub Pages にホスト
2. **大容量リソース**（ONNX, 辞書）を GitHub Releases にホスト
   ```
   gh release create v0.2.0-webgl-resources \
     ja_JP-test-medium.onnx \
     naist_jdic.zip \
     --title "WebGL Resources v0.2.0"
   ```

#### CI/CD ワークフロー
```yaml
name: Deploy WebGL
on:
  push:
    tags: ['v*']
jobs:
  build-webgl:
    - name: Build WebGL
      # Unity WebGL ビルド（リソース除外）

    - name: Upload large resources to Release
      # ONNX と辞書を GitHub Releases にアップロード

    - name: Deploy to GitHub Pages
      # 軽量ビルドのみ Pages にデプロイ
```

## 実装タスク

### Task 1: リソースローダーの実装
- [ ] `WebGLResourceLoader.cs` の作成
- [ ] IndexedDB ラッパー（jslib プラグイン）
- [ ] UnityWebRequest による非同期ダウンロード
- [ ] 進捗表示 UI

### Task 2: ビルド設定の変更
- [ ] WebGL ビルドから大容量リソースを除外
- [ ] StreamingAssets を空にする設定
- [ ] Editor スクリプトで自動化

### Task 3: 音素化の代替実装
- [ ] WebGL 用の SimpleLTS phonemizer テスト
- [ ] 精度評価（OpenJTalk と比較）
- [ ] フォールバック機構の実装

### Task 4: CI/CD の構築
- [ ] GitHub Actions ワークフロー作成
- [ ] GitHub Releases への自動アップロード
- [ ] デプロイ後の動作確認

## メリット

✅ **100MB 制限の回避**: 初期ロード 30MB 以下
✅ **音声速度問題の解決**: Unity.InferenceEngine 使用
✅ **キャッシュ活用**: 2回目以降は高速起動
✅ **スケーラブル**: 追加モデルも簡単に配信可能

## デメリット

⚠️ **初回ダウンロード時間**: 約84MB のダウンロードが必要
⚠️ **OpenJTalk 精度**: ネイティブ版より低下の可能性
⚠️ **実装コスト**: リソースローダーシステムの開発が必要

## 代替案との比較

| アプローチ | 初期ロード | 音声品質 | 実装難易度 |
|----------|-----------|---------|-----------|
| **オンデマンド読み込み**（推奨） | 30MB | 高 | 中 |
| サーバーサイドTTS | 5MB | 高 | 低（制約により不可） |
| 軽量モデルのみ | 80MB | 中 | 低（日本語対応困難） |
| ファイル分割（過去実装） | 100MB+ | 高 | 中（未解決問題あり） |

## 次のステップ

1. `WebGLResourceLoader.cs` のプロトタイプ実装
2. IndexedDB 連携のテスト
3. GitHub Releases を使った配信テスト
4. 簡易デモの作成

## 参考資料

- 過去の調査記録: `docs/ja/guides/webgl/unity-webgl-audio-issue-complete-investigation.md`
- Unity.InferenceEngine WebGL サポート: `InferenceAudioGenerator.cs:436-439`
- PlatformHelper: `Assets/uPiper/Runtime/Core/Platform/PlatformHelper.cs`
