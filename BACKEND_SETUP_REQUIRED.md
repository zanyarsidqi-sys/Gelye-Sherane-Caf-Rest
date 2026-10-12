# Separate backend required before launch

Create a dedicated Supabase project for THIS app, review and apply its migrations, configure RLS and auth independently, and use separate credentials. Example:

flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY

Never embed a service-role key in Flutter. Validate backend permissions, backups and production builds before use.
