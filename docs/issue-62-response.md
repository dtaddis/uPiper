# Issue #62: Web対応の調査結果と対応方針

## 調査結果サマリー

### 過去の試行の分析
`feature/webgl-implementation` と `deploy/webgl-pages` ブランチで2回の実装を試みました：

#### 直面した問題
1. **ファイルサイズ制限**
   - OpenJTalk辞書（107MB）が GitHub Pages の 100MB 制限に抵触
   - split-file-loader.js による分割実装を試みるも、404エラーが頻発

2. **音声速度問題**
   - 期待される音声長の **5.35倍** で生成される異常
   - ONNX Runtime Web の WASM プロバイダーが 4D テンソル `[1,1,1,N]` を出力
   - `length_scale × 0.82` という対症療法で一時的に対処

3. **根本原因不明**
   - Unity WebGL の Float32Array マーシャリング問題が疑われる
   - 完全な解決には至らず

詳細な調査記録: `docs/ja/guides/webgl/unity-webgl-audio-issue-complete-investigation.md`

### 新発見：Unity.InferenceEngine の WebGL サポート

**重要**: 現在のコードベースでは **Unity.InferenceEngine（旧 Sentis）** を使用しており、これは **WebGL を完全サポート** しています。

```csharp
// Assets/uPiper/Runtime/Core/AudioGeneration/InferenceAudioGenerator.cs:436-439
#if UNITY_WEBGL
    // WebGL typically works better with GPUPixel
    PiperLogger.LogInfo("[InferenceAudioGenerator] Auto-selecting GPUPixel backend for WebGL");
    return BackendType.GPUPixel;
#endif
```

**これにより、過去の ONNX Runtime Web で発生した 4D テンソル問題は解決される見込みです。**

## 現状のファイルサイズ

```
Assets/uPiper/Resources/Models/
├── ja_JP-test-medium.onnx       60MB
└── en_US-ljspeech-medium.onnx   61MB

Assets/StreamingAssets/uPiper/
├── OpenJTalk/naist_jdic.zip     23MB
└── Phonemizers/cmudict-0.7b.txt  3.5MB

合計: 147.5MB
```

## 提案する解決策：オンデマンドリソース読み込み

### コンセプト

1. **初期ビルド**（< 30MB）を GitHub Pages にデプロイ
2. **大容量リソース**（ONNX モデル、辞書）は GitHub Releases にホスト
3. 実行時に必要なリソースを非同期ダウンロード
4. ブラウザ IndexedDB でキャッシュ（2回目以降は高速起動）

### アーキテクチャ

```
┌─────────────────────────────────────┐
│   GitHub Pages (< 30MB)             │
│  - Unity WebGL Framework            │
│  - UI & Resource Loader             │
│  - Basic Scripts                    │
└──────────────┬──────────────────────┘
               │
               │ 初回アクセス時に
               │ ダウンロード要求
               ↓
┌─────────────────────────────────────┐
│   GitHub Releases (84MB)            │
│  - ja_JP-test-medium.onnx  (60MB)   │
│  - naist_jdic.zip          (23MB)   │
│  - cmudict-0.7b.txt        (3.5MB)  │
└──────────────┬──────────────────────┘
               │
               │ UnityWebRequest
               ↓
┌─────────────────────────────────────┐
│   Browser IndexedDB Cache           │
│  - 永続的なキャッシュ                 │
│  - 2回目以降は即座にロード             │
└─────────────────────────────────────┘
```

### メリット

✅ **100MB 制限の回避**: GitHub Pages は 30MB 以下
✅ **音声品質の維持**: Unity.InferenceEngine 使用で過去の問題を回避
✅ **高速な2回目以降**: IndexedDB キャッシュ活用
✅ **スケーラブル**: 追加モデルも簡単に配信可能
✅ **日本語完全対応**: OpenJTalk 辞書を含む全リソースをサポート

### デメリット

⚠️ **初回ダウンロード時間**: 約84MB のダウンロードが必要（1-2分程度）
⚠️ **実装コスト**: リソースローダーシステムの開発が必要
⚠️ **オフライン使用不可**: 初回はインターネット接続必須

## 実装計画

### Phase 1: リソースローダーの実装（2-3日）

```csharp
public class WebGLResourceLoader : MonoBehaviour
{
    private const string RELEASE_BASE_URL =
        "https://github.com/ayutaz/uPiper/releases/download/v{version}";

    public async Task<ModelAsset> LoadModelAsync(
        string modelName,
        IProgress<float> progress,
        CancellationToken cancellationToken)
    {
        // 1. IndexedDB キャッシュ確認
        var cached = await CheckCacheAsync(modelName);
        if (cached != null) return cached;

        // 2. GitHub Releases からダウンロード
        var url = $"{RELEASE_BASE_URL}/{modelName}";
        var data = await DownloadAsync(url, progress, cancellationToken);

        // 3. ModelAsset に変換
        var modelAsset = await ConvertToModelAssetAsync(data);

        // 4. IndexedDB に保存
        await CacheAsync(modelName, data);

        return modelAsset;
    }
}
```

### Phase 2: IndexedDB 連携（1-2日）

```javascript
// Plugins/WebGL/IndexedDBCache.jslib
mergeInto(LibraryManager.library, {
    CacheResource: function(key, data, length) {
        // IndexedDB に保存
    },
    GetCachedResource: function(key) {
        // IndexedDB から取得
    },
    ClearCache: function() {
        // すべてのキャッシュをクリア
    }
});
```

### Phase 3: UI 改善（1日）

- ダウンロード進捗バー
- 「初回のみ84MBのダウンロードが必要です」の通知
- キャッシュ管理UI（クリアボタン）

### Phase 4: CI/CD 構築（1-2日）

```yaml
# .github/workflows/deploy-webgl.yml
- name: Build WebGL (exclude large resources)
  run: |
    # Resources を除外した軽量ビルド

- name: Upload resources to GitHub Releases
  run: |
    gh release create ${{ github.ref_name }}-resources \
      ja_JP-test-medium.onnx \
      naist_jdic.zip \
      cmudict-0.7b.txt

- name: Deploy to GitHub Pages
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./Build/WebGL
```

## 代替案の検討結果

| アプローチ | 初期ロード | 音声品質 | 実装難易度 | 備考 |
|----------|-----------|---------|-----------|------|
| **オンデマンド読み込み**（推奨） | 30MB | ⭐⭐⭐⭐⭐ | 中 | 最もバランスが良い |
| サーバーサイドTTS | 5MB | ⭐⭐⭐⭐⭐ | 低 | **制約により不可** |
| 英語専用軽量版 | 80MB | ⭐⭐⭐ | 低 | **日本語対応不可で却下** |
| ファイル分割（過去実装） | 100MB+ | ⭐⭐⭐⭐ | 中 | 音声速度問題未解決 |

## 次のアクション

### すぐに始められること

1. **プロトタイプの作成**
   ```bash
   # 新しいブランチを作成
   git checkout -b feature/webgl-ondemand-loader
   ```

2. **リソースローダーの基本実装**
   - `Assets/uPiper/Runtime/Core/WebGL/WebGLResourceLoader.cs`
   - UnityWebRequest による非同期ダウンロード
   - 進捗表示のテスト

3. **IndexedDB プラグインの作成**
   - `Assets/uPiper/Plugins/WebGL/IndexedDBCache.jslib`
   - 基本的な保存・取得機能

### マイルストーン

- **Week 1**: リソースローダーと IndexedDB 連携の実装
- **Week 2**: UI 改善とエラーハンドリング
- **Week 3**: CI/CD 構築とデプロイテスト
- **Week 4**: パフォーマンス最適化とドキュメント整備

## まとめ

過去2回の試行で得られた知見を活かし、**Unity.InferenceEngine の WebGL サポート** と **オンデマンドリソース読み込み** を組み合わせることで、Issue #62 の「Web対応」を実現できます。

この方針で進めてよろしければ、すぐに実装を開始できます。

---

**関連ドキュメント**:
- 詳細戦略: `docs/webgl-implementation-strategy.md`
- 過去の調査記録: `docs/ja/guides/webgl/unity-webgl-audio-issue-complete-investigation.md`
- トラブルシューティング: `docs/WEBGL_TROUBLESHOOTING_GUIDE.md`
