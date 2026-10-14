-- Menu revisions are owner-approved; make the owner profile role representable.
-- This does not promote or create any employee account.
ALTER TABLE public.employee_profiles
  DROP CONSTRAINT IF EXISTS employee_profiles_role_check;

ALTER TABLE public.employee_profiles
  ADD CONSTRAINT employee_profiles_role_check
  CHECK (role IN ('owner', 'admin', 'manager', 'employee'));
