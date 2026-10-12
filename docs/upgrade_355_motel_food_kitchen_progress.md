# Upgrade 355 — Motel Food Kitchen Preparation

- Kitchen can transition accepted → preparing → ready, with kitchen edit permission and audit trail.
- Kitchen queue includes accepted, preparing, and ready food requests.
- Does not create a financial kitchen ticket, charge room accounts, or dispatch delivery.
- Requires applying Supabase migration 20261010_355_motel_food_kitchen_progress.sql.
- Flutter build and live Supabase integration have not been tested in this environment.
