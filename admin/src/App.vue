<template>
  <router-view />
</template>

<style>
html, body, #app { margin: 0; height: 100%; font-family: -apple-system, 'PingFang SC', 'Microsoft YaHei', sans-serif; background: #f4f6fa; }
.page-card { margin-bottom: 16px; }
.toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; margin-bottom: 14px; }
.toolbar .spacer { flex: 1; }
.muted { color: #6b7280; font-size: 12px; }
.num { font-variant-numeric: tabular-nums; }
.dp { color: #ff7a59; font-weight: 600; }
.ok { color: #1f8a70; font-weight: 600; }
</style>
