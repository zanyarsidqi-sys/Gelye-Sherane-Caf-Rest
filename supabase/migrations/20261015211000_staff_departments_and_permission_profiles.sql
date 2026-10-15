BEGIN;

CREATE TABLE public.staff_departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (length(trim(name)) BETWEEN 1 AND 80),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.staff_permission_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL
    REFERENCES public.staff_departments(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
  permissions jsonb NOT NULL CHECK (jsonb_typeof(permissions) = 'array'),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (department_id, name)
);

ALTER TABLE public.staff_profiles
  ADD COLUMN IF NOT EXISTS department_id uuid
    REFERENCES public.staff_departments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS permission_profile_id uuid
    REFERENCES public.staff_permission_profiles(id) ON DELETE SET NULL;

ALTER TABLE public.staff_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_departments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.staff_departments
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.staff_departments TO service_role;

ALTER TABLE public.staff_permission_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_permission_profiles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.staff_permission_profiles
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.staff_permission_profiles TO service_role;
GRANT UPDATE ON TABLE public.staff_profiles TO service_role;

CREATE OR REPLACE FUNCTION public.sync_staff_permission_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  UPDATE public.staff_profiles
  SET department_id = NEW.department_id
  WHERE permission_profile_id = NEW.id
    AND role = 'staff';

  DELETE FROM public.staff_permissions permission
  USING public.staff_profiles employee
  WHERE employee.permission_profile_id = NEW.id
    AND employee.role = 'staff'
    AND permission.user_id = employee.user_id;

  INSERT INTO public.staff_permissions (
    user_id,
    section_key,
    subcard_key,
    assigned_by
  )
  SELECT
    employee.user_id,
    grant_rows.section_key,
    grant_rows.subcard_key,
    NEW.updated_by
  FROM public.staff_profiles employee
  CROSS JOIN LATERAL jsonb_to_recordset(NEW.permissions)
    AS grant_rows(section_key text, subcard_key text)
  WHERE employee.permission_profile_id = NEW.id
    AND employee.role = 'staff';

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_staff_permission_profile()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER staff_permission_profile_sync
AFTER UPDATE OF department_id, permissions
ON public.staff_permission_profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_staff_permission_profile();

CREATE OR REPLACE FUNCTION public.admin_update_staff_access(
  target_user_id uuid,
  target_department_id uuid,
  target_permission_profile_id uuid,
  permission_grants jsonb,
  assigned_by_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF jsonb_typeof(permission_grants) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Permission grants must be a JSON array';
  END IF;
  IF jsonb_array_length(permission_grants) = 0 THEN
    RAISE EXCEPTION 'At least one valid permission is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.staff_profiles
    WHERE user_id = target_user_id
      AND role = 'staff'
  ) THEN
    RAISE EXCEPTION 'Staff account not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.staff_permission_profiles permission_profile
    WHERE permission_profile.id = target_permission_profile_id
      AND permission_profile.department_id = target_department_id
  ) THEN
    RAISE EXCEPTION 'Permission profile does not match department';
  END IF;

  UPDATE public.staff_profiles
  SET department_id = target_department_id,
      permission_profile_id = target_permission_profile_id
  WHERE user_id = target_user_id;

  DELETE FROM public.staff_permissions
  WHERE user_id = target_user_id;

  INSERT INTO public.staff_permissions (
    user_id,
    section_key,
    subcard_key,
    assigned_by
  )
  SELECT
    target_user_id,
    grant_rows.section_key,
    grant_rows.subcard_key,
    assigned_by_user_id
  FROM jsonb_to_recordset(permission_grants)
    AS grant_rows(section_key text, subcard_key text);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_staff_access(
  uuid, uuid, uuid, jsonb, uuid
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_access(
  uuid, uuid, uuid, jsonb, uuid
) TO service_role;

COMMIT;
