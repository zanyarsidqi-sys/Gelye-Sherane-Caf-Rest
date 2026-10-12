# Upgrade 1154 — Refresh on rejected kitchen status RPC

A rejected kitchen status transition now reloads the queue and clears stale
order-item previews, provided the same employee and queue generation remain
active. This addresses concurrent updates by other kitchen employees.
