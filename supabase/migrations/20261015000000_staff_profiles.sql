-- Gelye Sherane Cafe & Restaurant — staff profiles baseline (review candidate)
-- Apply only to an explicitly verified staging database after approval.
-- Staff provisioning is intentionally separate from public Auth signup.
BEGIN;

CREATE TABLE IF NOT EXISTS public.staff_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  role text NOT NULL DEFAULT 'staff' CHECK (role IN ('admin', 'staff')),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.staff_profiles (user_id, email, role)
SELECT au.id, au.email, au.raw_app_meta_data->>'role'
FROM auth.users au
WHERE au.raw_app_meta_data->>'role' IN ('admin', 'staff')
ON CONFLICT (user_id) DO UPDATE
SET email = EXCLUDED.email,
    role = EXCLUDED.role;

ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;

-- PostgreSQL privileges and RLS are separate protections.
REVOKE ALL ON TABLE public.staff_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.staff_profiles TO authenticated;

-- Called only by the SELECT policy; must be owned by a trusted database role.
-- SECURITY DEFINER avoids recursive RLS evaluation. Verify owner and permissions
-- during staging review; do not make the function owner an untrusted login.
CREATE OR REPLACE FUNCTION public.is_staff_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_profiles
    WHERE user_id = (SELECT auth.uid()) AND role = 'admin'
  );
$$;
REVOKE ALL ON FUNCTION public.is_staff_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff_admin() TO authenticated;

DROP POLICY IF EXISTS "Staff can read their own profile and admins can read all"
  ON public.staff_profiles;
CREATE POLICY "Staff can read their own profile and admins can read all"
ON public.staff_profiles FOR SELECT TO authenticated
USING (
  user_id = (SELECT auth.uid()) OR (SELECT public.is_staff_admin())
);

-- Remove the original unsafe signup trigger if it was installed.
-- This migration does NOT automatically grant a staff profile to new customers.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Remove the original helper function only when it is the expected signup
-- helper and is not needed by other components; review dependencies first.
-- We intentionally do NOT drop public.handle_new_auth_user() here because
-- it could have other dependencies or be used by other application code.
-- Disable direct invocation by API roles if it exists; the trigger is removed.
DO $$
BEGIN
  IF to_regprocedure('public.handle_new_auth_user()') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM PUBLIC, anon, authenticated';
  END IF;
END;
$$;

COMMIT;

-- No automatic admin bootstrap and no direct authenticated INSERT/UPDATE/DELETE.
-- A separate privileged staff provisioning workflow with audit, authorization,
-- and MFA requirements must be reviewed before enabling staff creation.
