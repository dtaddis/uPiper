#!/bin/bash
# WebGL ローカルサーバー起動スクリプト
# Usage: ./scripts/serve-webgl.sh [port]

set -e

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== uPiper WebGL Local Server ===${NC}"

# プロジェクトルートに移動
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# ビルドディレクトリ
BUILD_DIR="$PROJECT_ROOT/Build/WebGL"

# ポート番号（デフォルト: 8000）
PORT="${1:-8000}"

# ビルドディレクトリの存在確認
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Build directory not found: $BUILD_DIR${NC}"
    echo ""
    echo "Please build WebGL first:"
    echo "  ./scripts/build-webgl.sh"
    echo ""
    exit 1
fi

# index.html の確認
if [ ! -f "$BUILD_DIR/index.html" ]; then
    echo -e "${YELLOW}index.html not found in build directory${NC}"
    echo "Build may be incomplete or corrupted"
    exit 1
fi

echo "Build directory: $BUILD_DIR"
echo "Port: $PORT"
echo ""

# サーバーの選択と起動
if command -v python3 &> /dev/null; then
    # Python 3
    echo -e "${GREEN}Starting Python 3 HTTP server...${NC}"
    echo ""
    echo -e "${CYAN}🌐 Open in browser:${NC}"
    echo -e "${CYAN}   http://localhost:$PORT${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo ""

    cd "$BUILD_DIR"
    python3 -m http.server "$PORT"

elif command -v python &> /dev/null; then
    # Python 2
    echo -e "${GREEN}Starting Python 2 HTTP server...${NC}"
    echo ""
    echo -e "${CYAN}🌐 Open in browser:${NC}"
    echo -e "${CYAN}   http://localhost:$PORT${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo ""

    cd "$BUILD_DIR"
    python -m SimpleHTTPServer "$PORT"

elif command -v php &> /dev/null; then
    # PHP
    echo -e "${GREEN}Starting PHP built-in server...${NC}"
    echo ""
    echo -e "${CYAN}🌐 Open in browser:${NC}"
    echo -e "${CYAN}   http://localhost:$PORT${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo ""

    cd "$BUILD_DIR"
    php -S "localhost:$PORT"

else
    echo -e "${YELLOW}No suitable HTTP server found!${NC}"
    echo ""
    echo "Please install one of the following:"
    echo "  - Python 3: brew install python3"
    echo "  - Node.js http-server: npm install -g http-server"
    echo "  - PHP: brew install php"
    echo ""
    echo "Or use any other static file server of your choice"
    echo "Serve from: $BUILD_DIR"
    exit 1
fi
