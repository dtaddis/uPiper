#if UNITY_WEBGL && !UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;
using uPiper.Core.Phonemizers.Backend;

namespace uPiper.Core.Phonemizers.WebGL
{
    /// <summary>
    /// Test phonemizer for WebGL that returns fixed phoneme patterns.
    /// This is used to test Unity.InferenceEngine on WebGL platform without requiring OpenJTalk native library.
    /// </summary>
    public class WebGLTestPhonemizer : BasePhonemizer
    {
        private static readonly Dictionary<string, string[]> TestPatterns = new()
        {
            // こんにちは (konnichiwa)
            { "こんにちは", new[] { "k", "o", "N", "n", "i", "\ue00a", "i", "w", "a" } },
            { "konnichiwa", new[] { "k", "o", "N", "n", "i", "\ue00a", "i", "w", "a" } },

            // 小さい (chiisai) - contains "ち" (chi)
            { "小さい", new[] { "\ue00a", "i", "i", "s", "a", "i" } },
            { "chiisai", new[] { "\ue00a", "i", "i", "s", "a", "i" } },
            { "ちいさい", new[] { "\ue00a", "i", "i", "s", "a", "i" } },

            // 続ける (tsuzukeru) - contains "つ" (tsu)
            { "続ける", new[] { "\ue00f", "u", "z", "u", "k", "e", "r", "u" } },
            { "tsuzukeru", new[] { "\ue00f", "u", "z", "u", "k", "e", "r", "u" } },
            { "つづける", new[] { "\ue00f", "u", "z", "u", "k", "e", "r", "u" } },

            // おはよう (ohayou) - normal text
            { "おはよう", new[] { "o", "h", "a", "y", "o", "u" } },
            { "ohayou", new[] { "o", "h", "a", "y", "o", "u" } },

            // 遅刻 (chikoku) - contains "ち" (chi)
            { "遅刻", new[] { "\ue00a", "i", "k", "o", "k", "u" } },
            { "chikoku", new[] { "\ue00a", "i", "k", "o", "k", "u" } },
            { "ちこく", new[] { "\ue00a", "i", "k", "o", "k", "u" } },

            // 伝える (tsutaeru) - contains "つ" (tsu)
            { "伝える", new[] { "\ue00f", "u", "t", "a", "e", "r", "u" } },
            { "tsutaeru", new[] { "\ue00f", "u", "t", "a", "e", "r", "u" } },
            { "つたえる", new[] { "\ue00f", "u", "t", "a", "e", "r", "u" } },
        };

        public override string Name => "WebGL Test Phonemizer";
        public override string Version => "1.0.0-test";
        public override string[] SupportedLanguages => new[] { "ja", "en" };

        public WebGLTestPhonemizer() : base(100, null)
        {
            Debug.Log("[WebGLTestPhonemizer] Initialized for Unity.InferenceEngine testing on WebGL");
            Debug.Log("[WebGLTestPhonemizer] This is a TEST phonemizer with fixed patterns");
            Debug.Log($"[WebGLTestPhonemizer] Test patterns available: {TestPatterns.Count}");
        }

        protected override Task<PhonemeResult> PhonemizeInternalAsync(
            string normalizedText,
            string language,
            CancellationToken cancellationToken)
        {
            Debug.Log($"[WebGLTestPhonemizer] Processing text: '{normalizedText}'");

            // Look up the test pattern
            if (TestPatterns.TryGetValue(normalizedText, out var phonemes))
            {
                Debug.Log($"[WebGLTestPhonemizer] Found test pattern for '{normalizedText}': {string.Join(" ", phonemes)}");

                // Create durations (50ms per phoneme as in real OpenJTalk)
                var durations = new float[phonemes.Length];
                for (var i = 0; i < phonemes.Length; i++)
                {
                    durations[i] = 0.05f; // 50ms per phoneme
                }

                // Create pitches (default 1.0)
                var pitches = new float[phonemes.Length];
                for (var i = 0; i < phonemes.Length; i++)
                {
                    pitches[i] = 1.0f;
                }

                var result = new PhonemeResult
                {
                    Phonemes = phonemes,
                    PhonemeIds = new int[phonemes.Length], // Will be set by PhonemeEncoder
                    Durations = durations,
                    Pitches = pitches,
                    Language = language,
                    OriginalText = normalizedText,
                    ProcessingTime = TimeSpan.Zero,
                    FromCache = false,
                    Metadata = new Dictionary<string, object>
                    {
                        ["Source"] = "WebGLTestPhonemizer",
                        ["PatternMatch"] = true,
                        ["TotalDuration"] = phonemes.Length * 0.05f
                    }
                };

                return Task.FromResult(result);
            }
            else
            {
                Debug.LogWarning($"[WebGLTestPhonemizer] No test pattern found for '{normalizedText}'");
                Debug.LogWarning($"[WebGLTestPhonemizer] Available patterns: {string.Join(", ", TestPatterns.Keys)}");

                // Return empty result for unknown text
                return Task.FromResult(new PhonemeResult
                {
                    Phonemes = Array.Empty<string>(),
                    PhonemeIds = Array.Empty<int>(),
                    Durations = Array.Empty<float>(),
                    Pitches = Array.Empty<float>(),
                    Language = language,
                    OriginalText = normalizedText,
                    ProcessingTime = TimeSpan.Zero,
                    FromCache = false,
                    Metadata = new Dictionary<string, object>
                    {
                        ["Source"] = "WebGLTestPhonemizer",
                        ["PatternMatch"] = false,
                        ["Error"] = "No test pattern found"
                    }
                });
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                Debug.Log("[WebGLTestPhonemizer] Disposed");
            }
            base.Dispose(disposing);
        }
    }
}
#endif
