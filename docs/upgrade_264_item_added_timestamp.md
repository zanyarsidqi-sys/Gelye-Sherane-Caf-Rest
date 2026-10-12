# Upgrade 264: item-added timestamps

- New gs_order_items.added_at is server-generated on insert, including later additions.
- Backfill of existing records uses parent order time, which is only an approximation.
- Updates cannot rewrite added_at; staff timeline uses item timestamp.
- No revision printing, live notification, or client item-time display is added by this migration.
- Requires review and deployment to Supabase; not production-tested.
