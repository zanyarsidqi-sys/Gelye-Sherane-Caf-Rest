-- REVIEW ONLY. Apply to a verified, isolated staging database after approval.
-- Based on uploaded 20261015000000_staff_profiles(2).sql.
-- Does NOT touch auth.users, existing auth triggers, or production data.
-- Does NOT backfill from app_metadata or auto-assign roles.
-- IMPORTANT: existing auth.users INSERT trigger still references this table;
-- audit its ownership and trusted metadata writers before any staging test.
BEGIN;

-- Fail rather than silently adopting an unknown/incompatible table.
CREATE TABLE public.staff_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  role text NOT NULL CHECK (role IN ('admin', 'staff')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.staff_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.staff_profiles TO authenticated;

-- No SECURITY DEFINER helper needed: policy checks only the current row.
-- Requiring AAL2 at the database boundary prevents AAL1 staff profile reads.
-- NOTE: AAL2 also must be enforced on EVERY other staff-only table/RPC/Edge Function.
CREATE POLICY staff_profile_self_read_aal2
ON public.staff_profiles FOR SELECT TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND (SELECT auth.jwt()->>'aal') = 'aal2'
);

-- Admin listing is intentionally NOT granted by this baseline.
-- Add a separately audited, MFA-protected admin listing RPC after staging tests.
-- No INSERT, UPDATE or DELETE privileges granted to authenticated/anon.
COMMIT;
