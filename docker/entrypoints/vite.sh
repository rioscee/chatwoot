#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

if [ ! -d "node_modules" ]; then
  pnpm install
else
  pnpm install --prefer-offline
fi

echo "Ready to run Vite development server."

exec "$@"
