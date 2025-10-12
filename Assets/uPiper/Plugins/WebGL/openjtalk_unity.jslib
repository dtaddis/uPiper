mergeInto(LibraryManager.library, {
  /**
   * OpenJTalk_Initialize
   * WebGLOpenJTalkPhonemizer.cs から呼ばれる初期化関数
   * コールバック方式で非同期処理に対応
   */
  OpenJTalk_Initialize: function(callbackPtr) {
    console.log('[OpenJTalk_Initialize] Called with callback:', callbackPtr);

    // UnityのC#側でデリゲートとして渡されたコールバック関数をラップ
    var callback = function(success) {
      console.log('[OpenJTalk_Initialize] Invoking Unity callback with success:', success);
      // UnityのRuntime.dynCallでC#デリゲートを呼び出し
      {{{ makeDynCall('vi', 'callbackPtr') }}}(success);
    };

    // OpenJTalkUnityAPI の非同期初期化を実行
    (async function() {
      try {
        console.log('[OpenJTalk_Initialize] Starting async initialization...');

        // スクリプトがまだロードされていない場合はロード
        if (typeof window.OpenJTalkUnityAPI === 'undefined') {
          console.log('[OpenJTalk_Initialize] Loading OpenJTalk scripts...');

          const baseUrl = window.location.href.substring(0, window.location.href.lastIndexOf('/') + 1);

          // openjtalk-unity.js (Emscripten module) のロード
          await new Promise((resolve, reject) => {
            var script = document.createElement('script');
            script.src = baseUrl + 'StreamingAssets/openjtalk-unity.js';
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
          });
          console.log('[OpenJTalk_Initialize] openjtalk-unity.js loaded');

          // openjtalk-unity-wrapper.js のロード
          await new Promise((resolve, reject) => {
            var script = document.createElement('script');
            script.src = baseUrl + 'StreamingAssets/openjtalk-unity-wrapper.js';
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
          });
          console.log('[OpenJTalk_Initialize] openjtalk-unity-wrapper.js loaded');
        }

        // OpenJTalkUnityAPI の初期化
        if (window.OpenJTalkUnityAPI && window.OpenJTalkUnityAPI.initializeAsync) {
          console.log('[OpenJTalk_Initialize] Calling OpenJTalkUnityAPI.initializeAsync()...');
          var result = await window.OpenJTalkUnityAPI.initializeAsync();
          console.log('[OpenJTalk_Initialize] Initialization result:', result);

          // Unityのコールバックを呼び出し（1 = success, 0 = failure）
          callback(result ? 1 : 0);
        } else {
          console.error('[OpenJTalk_Initialize] OpenJTalkUnityAPI not available');
          callback(0);
        }
      } catch (error) {
        console.error('[OpenJTalk_Initialize] Error:', error);
        callback(0);
      }
    })();
  },

  /**
   * OpenJTalk_Phonemize
   * WebGLOpenJTalkPhonemizer.cs から呼ばれる音素化関数
   * コールバック方式で非同期処理に対応
   */
  OpenJTalk_Phonemize: function(textPtr, callbackPtr) {
    var text = UTF8ToString(textPtr);
    console.log('[OpenJTalk_Phonemize] Called with text:', text);

    // UnityのC#側でデリゲートとして渡されたコールバック関数をラップ
    var callback = function(success, phonemes) {
      console.log('[OpenJTalk_Phonemize] Invoking Unity callback with success:', success, 'phonemes:', phonemes);

      // 音素文字列をC#に渡すためにメモリ確保
      var phonemesPtr = 0;
      if (phonemes && phonemes.length > 0) {
        var phonemesStr = phonemes.join(' ');
        var len = lengthBytesUTF8(phonemesStr) + 1;
        phonemesPtr = _malloc(len);
        stringToUTF8(phonemesStr, phonemesPtr, len);
      }

      // UnityのRuntime.dynCallでC#デリゲートを呼び出し
      // 'vii' = void return, int param, int param (ptr)
      // C#側でMarshal.PtrToStringUTF8()後にOpenJTalk_FreeMemory()で解放
      {{{ makeDynCall('vii', 'callbackPtr') }}}(success, phonemesPtr);
    };

    // OpenJTalkUnityAPI の音素化を実行
    (async function() {
      try {
        if (!window.OpenJTalkUnityAPI || !window.OpenJTalkUnityAPI.isReady()) {
          console.error('[OpenJTalk_Phonemize] OpenJTalkUnityAPI not initialized');
          callback(0, []);
          return;
        }

        console.log('[OpenJTalk_Phonemize] Calling OpenJTalkUnityAPI.phonemize()...');
        var phonemes = window.OpenJTalkUnityAPI.phonemize(text);
        console.log('[OpenJTalk_Phonemize] Phonemes:', phonemes);

        if (phonemes && phonemes.length > 0) {
          callback(1, phonemes);
        } else {
          console.error('[OpenJTalk_Phonemize] No phonemes returned');
          callback(0, []);
        }
      } catch (error) {
        console.error('[OpenJTalk_Phonemize] Error:', error);
        callback(0, []);
      }
    })();
  },

  /**
   * OpenJTalk_FreeMemory
   * C#からJavaScriptで確保したメモリを解放する
   */
  OpenJTalk_FreeMemory: function(ptr) {
    if (ptr !== 0) {
      _free(ptr);
    }
  },

  /**
   * OpenJTalk_Dispose
   * WebGLOpenJTalkPhonemizer.cs から呼ばれるクリーンアップ関数
   */
  OpenJTalk_Dispose: function() {
    console.log('[OpenJTalk_Dispose] Called');

    try {
      if (window.OpenJTalkUnityAPI && window.OpenJTalkUnityAPI.dispose) {
        window.OpenJTalkUnityAPI.dispose();
        console.log('[OpenJTalk_Dispose] Disposed successfully');
      }
    } catch (error) {
      console.error('[OpenJTalk_Dispose] Error:', error);
    }
  }
});
