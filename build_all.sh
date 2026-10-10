#!/usr/bin/env bash
# 一键构建：管理后台 + 用户端 App → server/public，然后 `cd server && npm start`
set -e
cd "$(dirname "$0")"
FLUTTER="${FLUTTER:-flutter}"

(cd server && npm install --omit=dev)
(cd admin && npm install && npm run build)
"$FLUTTER" pub get
"$FLUTTER" build web --release --no-wasm-dry-run -o server/public/app
echo "构建完成：cd server && npm start  →  http://localhost:8080"
