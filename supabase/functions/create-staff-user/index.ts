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

  const payload = body as Record<string, unknown>;
  const email = payload.email;
  const password = payload.password;
  const permissions = parsePermissionGrants(payload.permissions);
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
  if (permissions === null) {
    return jsonResponse(400, {
      error: "Choose valid sections or cards for the staff account.",
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
