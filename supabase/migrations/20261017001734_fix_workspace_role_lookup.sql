-- Applied to production with this version on 17 October 2026.
-- Renamed from the CLI-generated draft to match the server migration history.
CREATE OR REPLACE FUNCTION public.has_workspace_access(requested_section text, requested_subcard text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $fn$
DECLARE caller uuid:=auth.uid(); staff_role text;
BEGIN
IF caller IS NULL OR auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN RETURN false; END IF;
SELECT p.role INTO staff_role FROM public.staff_profiles p WHERE p.user_id=caller;
IF staff_role='admin' THEN RETURN true; END IF;
IF staff_role IS DISTINCT FROM 'staff' THEN RETURN false; END IF;
RETURN EXISTS(SELECT 1 FROM public.staff_permissions p WHERE p.user_id=caller AND p.section_key=requested_section AND p.subcard_key IN ('*',requested_subcard));
END;$fn$;
