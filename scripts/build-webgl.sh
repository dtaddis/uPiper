#!/bin/bash
# WebGL ビルドスクリプト
# Usage: ./scripts/build-webgl.sh

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== uPiper WebGL Build Script ===${NC}"

# プロジェクトルートに移動
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

echo "Project root: $PROJECT_ROOT"

# Unity のパスを検出
UNITY_PATH=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    UNITY_PATH="/Applications/Unity/Hub/Editor/6000.0.55f1/Unity.app/Contents/MacOS/Unity"
    if [ ! -f "$UNITY_PATH" ]; then
        UNITY_PATH="/Applications/Unity/Unity.app/Contents/MacOS/Unity"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    UNITY_PATH="/opt/unity/Editor/Unity"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    UNITY_PATH="C:/Program Files/Unity/Hub/Editor/6000.0.55f1/Editor/Unity.exe"
fi

if [ ! -f "$UNITY_PATH" ]; then
    echo -e "${RED}Unity not found at: $UNITY_PATH${NC}"
    echo -e "${YELLOW}Please edit this script to set the correct Unity path${NC}"
    exit 1
fi

echo "Unity path: $UNITY_PATH"

# ビルド出力ディレクトリ
BUILD_DIR="$PROJECT_ROOT/Build/WebGL"
LOG_FILE="$PROJECT_ROOT/Build/webgl_build.log"

# 古いビルドディレクトリを削除（オプション）
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Removing old build directory...${NC}"
    rm -rf "$BUILD_DIR"
fi

# ビルドディレクトリ作成
mkdir -p "$BUILD_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

echo -e "${GREEN}Starting WebGL build...${NC}"
echo "Build output: $BUILD_DIR"
echo "Log file: $LOG_FILE"

# Unity WebGL ビルド実行
"$UNITY_PATH" \
    -quit \
    -batchmode \
    -nographics \
    -projectPath "$PROJECT_ROOT" \
    -buildTarget WebGL \
    -executeMethod UnityEditor.BuildPlayer.BuildPlayer \
    -logFile "$LOG_FILE" \
    || true  # エラーでもログを表示するため

# ビルド結果を確認
if [ -f "$BUILD_DIR/index.html" ]; then
    echo -e "${GREEN}✅ Build succeeded!${NC}"
    echo ""
    echo "Build location: $BUILD_DIR"
    echo ""

    # ビルドサイズを表示
    echo "Build size:"
    du -sh "$BUILD_DIR"
    echo ""

    # 主要ファイルのサイズ
    echo "Main files:"
    ls -lh "$BUILD_DIR/Build" 2>/dev/null | grep -E '\.(data|wasm|js)' || true
    echo ""

    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Start local server:"
    echo "   ./scripts/serve-webgl.sh"
    echo ""
    echo "2. Open browser:"
    echo "   http://localhost:8000"
    echo ""

    exit 0
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "Check the log file for details:"
    echo "  tail -100 $LOG_FILE"
    echo ""

    # ログの最後の50行を表示
    echo "Last 50 lines of log:"
    echo "---"
    tail -50 "$LOG_FILE"

    exit 1
fi
