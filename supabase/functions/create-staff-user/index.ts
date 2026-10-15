declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};
// @ts-ignore Deno resolves npm: specifiers at runtime.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, string | boolean>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const allowedSectionKeys = new Set([
  "dashboard",
  "tables_orders",
  "payment_management",
  "kitchen_management",
  "customer_management",
  "statistics_management",
  "employee_management",
  "maintenance_management",
  "notifications_management",
  "settings_management",
  "operations_management",
]);

type PermissionGrant = {
  section_key: string;
  subcard_key: string;
};

type StaffFunctionBody = Record<string, unknown>;

function getJwtClaims(token: string): Record<string, unknown> | null {
  const payload = token.split(".")[1];
  if (!payload) return null;

  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const bytes = Uint8Array.from(atob(padded), (character) =>
      character.charCodeAt(0),
    );
    const claims: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return typeof claims === "object" &&
      claims !== null &&
      !Array.isArray(claims)
      ? (claims as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

function parsePermissionGrants(input: unknown): PermissionGrant[] | null {
  if (!Array.isArray(input) || input.length > 200) return null;
  const grants = new Map<string, Set<string>>();
  for (const item of input) {
    if (typeof item !== "object" || item === null || Array.isArray(item)) {
      return null;
    }
    const grant = item as Record<string, unknown>;
    const sectionKey = grant.section_key;
    const subcardKey = grant.subcard_key;
    if (
      typeof sectionKey !== "string" ||
      !allowedSectionKeys.has(sectionKey) ||
      typeof subcardKey !== "string" ||
      (subcardKey !== "*" && !/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(subcardKey))
    ) {
      return null;
    }
    const sectionGrants = grants.get(sectionKey) ?? new Set<string>();
    sectionGrants.add(subcardKey);
    grants.set(sectionKey, sectionGrants);
  }

  return Array.from(grants.entries()).flatMap(([section_key, subcards]) =>
    subcards.has("*")
      ? [{ section_key, subcard_key: "*" }]
      : Array.from(subcards, (subcard_key) => ({ section_key, subcard_key })),
  );
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Use POST to create a staff account." });
  }

  const authorization = request.headers.get("Authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return jsonResponse(401, { error: "Sign in as an administrator first." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, {
      error: "The staff service is missing its server configuration.",
    });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: authData, error: authError } =
    await adminClient.auth.getUser(token);
  if (authError || !authData.user) {
    return jsonResponse(401, { error: "Your sign-in has expired." });
  }
  const claims = getJwtClaims(token);
  if (claims?.sub !== authData.user.id || claims?.aal !== "aal2") {
    return jsonResponse(403, {
      error:
        "Complete authenticator verification before creating staff accounts.",
    });
  }

  const { data: profile, error: profileError } = await adminClient
    .from("staff_profiles")
    .select("role")
    .eq("user_id", authData.user.id)
    .maybeSingle();
  if (profileError) {
    return jsonResponse(500, {
      error: "Could not verify administrator permissions.",
    });
  }
  if (profile?.role !== "admin") {
    return jsonResponse(403, {
      error: "Only an administrator can create staff accounts.",
    });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: "Provide a valid JSON request body." });
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return jsonResponse(400, { error: "Provide a valid JSON request body." });
  }

  const payload = body as StaffFunctionBody;
  const action = typeof payload.action === "string"
    ? payload.action
    : "create-staff-user";

  if (action === "list-management") {
    const [departmentsResult, profilesResult, staffResult, permissionsResult] =
      await Promise.all([
        adminClient.from("staff_departments").select("id, name").order("name"),
        adminClient
          .from("staff_permission_profiles")
          .select("id, name, department_id, permissions")
          .order("name"),
        adminClient
          .from("staff_profiles")
          .select("user_id, email, department_id, permission_profile_id")
          .eq("role", "staff")
          .order("email"),
        adminClient
          .from("staff_permissions")
          .select("user_id, section_key, subcard_key"),
      ]);
    const failure = departmentsResult.error ??
      profilesResult.error ??
      staffResult.error ??
      permissionsResult.error;
    if (failure) {
      console.error("Could not load employee management data", failure.message);
      return jsonResponse(500, {
        error: `Could not load employee management data: ${failure.message}`,
      });
    }

    const permissionsByUser = new Map<string, PermissionGrant[]>();
    for (const row of permissionsResult.data ?? []) {
      const grants = permissionsByUser.get(row.user_id) ?? [];
      grants.push({
        section_key: row.section_key,
        subcard_key: row.subcard_key,
      });
      permissionsByUser.set(row.user_id, grants);
    }

    return new Response(JSON.stringify({
      departments: departmentsResult.data ?? [],
      permission_profiles: profilesResult.data ?? [],
      staff: (staffResult.data ?? []).map((member) => ({
        ...member,
        permissions: permissionsByUser.get(member.user_id) ?? [],
      })),
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (action === "save-department") {
    const id = payload.id;
    const name = typeof payload.name === "string" ? payload.name.trim() : "";
    if (name.length < 1 || name.length > 80) {
      return jsonResponse(400, { error: "Department names must be 1–80 characters." });
    }
    const departmentQuery = adminClient.from("staff_departments");
    const result = typeof id === "string" && id.length > 0
      ? await departmentQuery
        .update({ name })
        .eq("id", id)
        .select("id, name")
        .single()
      : await departmentQuery
        .insert({ name, created_by: authData.user.id })
        .select("id, name")
        .single();
    if (result.error) {
      return jsonResponse(400, {
        error: `Could not save department: ${result.error.message}`,
      });
    }
    return new Response(JSON.stringify({ department: result.data }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (action === "save-permission-profile") {
    const id = payload.id;
    const departmentId = payload.department_id;
    const name = typeof payload.name === "string" ? payload.name.trim() : "";
    const permissions = parsePermissionGrants(payload.permissions);
    if (
      typeof departmentId !== "string" ||
      name.length < 1 ||
      name.length > 80 ||
      permissions === null ||
      permissions.length === 0
    ) {
      return jsonResponse(400, {
        error: "Choose a department, a 1–80 character name, and at least one permission.",
      });
    }
    const profileQuery = adminClient.from("staff_permission_profiles");
    const result = typeof id === "string" && id.length > 0
      ? await profileQuery
        .update({
          department_id: departmentId,
          name,
          permissions,
          updated_by: authData.user.id,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id)
        .select("id, name, department_id, permissions")
        .single()
      : await profileQuery
        .insert({
          department_id: departmentId,
          name,
          permissions,
          created_by: authData.user.id,
          updated_by: authData.user.id,
        })
        .select("id, name, department_id, permissions")
        .single();
    if (result.error) {
      return jsonResponse(400, {
        error: `Could not save permission profile: ${result.error.message}`,
      });
    }
    return new Response(JSON.stringify({ permission_profile: result.data }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (action === "update-staff-access") {
    const userId = payload.user_id;
    const departmentId = payload.department_id;
    const permissionProfileId = payload.permission_profile_id;
    if (
      typeof userId !== "string" ||
      typeof departmentId !== "string" ||
      typeof permissionProfileId !== "string"
    ) {
      return jsonResponse(400, {
        error: "Choose a department and permission profile for this staff member.",
      });
    }
    const { data: permissionProfile, error: permissionProfileError } =
      await adminClient
        .from("staff_permission_profiles")
        .select("department_id, permissions")
        .eq("id", permissionProfileId)
        .single();
    if (
      permissionProfileError ||
      permissionProfile?.department_id !== departmentId
    ) {
      return jsonResponse(400, {
        error: "The permission profile does not belong to the selected department.",
      });
    }
    const grants = parsePermissionGrants(permissionProfile.permissions);
    if (grants === null || grants.length === 0) {
      return jsonResponse(400, { error: "The permission profile has no valid access grants." });
    }
    const { error: updateError } = await adminClient.rpc(
      "admin_update_staff_access",
      {
        target_user_id: userId,
        target_department_id: departmentId,
        target_permission_profile_id: permissionProfileId,
        permission_grants: grants,
        assigned_by_user_id: authData.user.id,
      },
    );
    if (updateError) {
      return jsonResponse(500, {
        error: `Could not update staff access: ${updateError.message}`,
      });
    }
    return jsonResponse(200, { message: "Staff access updated.", permissions_saved: true });
  }

  if (action !== "create-staff-user") {
    return jsonResponse(400, { error: "Unknown staff management action." });
  }

  const email = payload.email;
  const password = payload.password;
  const departmentId = payload.department_id;
  const permissionProfileId = payload.permission_profile_id;
  if (
    typeof email !== "string" ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  ) {
    return jsonResponse(400, { error: "Enter a valid staff email address." });
  }
  if (typeof password !== "string" || password.length < 12) {
    return jsonResponse(400, {
      error: "The initial password must be at least 12 characters.",
    });
  }
  if (typeof departmentId !== "string" || typeof permissionProfileId !== "string") {
    return jsonResponse(400, {
      error: "Choose a department and permission profile before creating the account.",
    });
  }
  const { data: selectedProfile, error: selectedProfileError } = await adminClient
    .from("staff_permission_profiles")
    .select("department_id, permissions")
    .eq("id", permissionProfileId)
    .single();
  if (
    selectedProfileError ||
    selectedProfile?.department_id !== departmentId
  ) {
    return jsonResponse(400, {
      error: "The permission profile does not belong to the selected department.",
    });
  }
  const permissions = parsePermissionGrants(selectedProfile.permissions);
  if (permissions === null || permissions.length === 0) {
    return jsonResponse(400, {
      error: "The selected permission profile has no valid access grants.",
    });
  }

  const { data: createdUser, error: createError } =
    await adminClient.auth.admin.createUser({
      email: email.trim(),
      password,
      email_confirm: true,
      app_metadata: { role: "staff" },
    });
  if (createError || !createdUser?.user) {
    return jsonResponse(400, {
      error: createError?.message ?? "Could not create the staff account.",
    });
  }

  const { error: profileUpsertError } = await adminClient
    .from("staff_profiles")
    .upsert(
      {
        user_id: createdUser.user.id,
        email: createdUser.user.email,
        role: "staff",
        department_id: departmentId,
        permission_profile_id: permissionProfileId,
      },
      { onConflict: "user_id" },
    );
  if (profileUpsertError) {
    const { error: cleanupError } = await adminClient.auth.admin.deleteUser(
      createdUser.user.id,
    );
    if (cleanupError) {
      console.error(
        "Staff account rollback failed after profile creation error",
        createdUser.user.id,
        cleanupError.message,
      );
      return jsonResponse(500, {
        error:
          "The staff profile could not be created and the new account could " +
          "not be removed. Contact the system administrator.",
      });
    }
    return jsonResponse(500, {
      error: "The staff profile record could not be created.",
    });
  }

  if (permissions.length > 0) {
    const { error: permissionError } = await adminClient
      .from("staff_permissions")
      .insert(
        permissions.map((permission) => ({
          ...permission,
          user_id: createdUser.user.id,
          assigned_by: authData.user.id,
        })),
      );
    if (permissionError) {
      const { error: cleanupError } = await adminClient.auth.admin.deleteUser(
        createdUser.user.id,
      );
      if (cleanupError) {
        console.error(
          "Staff account rollback failed after permission insert error",
          createdUser.user.id,
          cleanupError.message,
        );
        return jsonResponse(500, {
          error:
            "Staff permissions could not be saved and the new account could " +
            "not be removed. Contact the system administrator.",
        });
      }
      return jsonResponse(500, {
        error:
          "Staff permissions could not be saved; the new account was removed.",
      });
    }
  }

  return jsonResponse(201, {
    message: "Staff account created.",
    permissions_saved: true,
  });
});
