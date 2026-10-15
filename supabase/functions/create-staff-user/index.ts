import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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

  const { data: authData, error: authError } = await adminClient.auth.getUser(
    token,
  );
  if (authError || !authData.user) {
    return jsonResponse(401, { error: "Your sign-in has expired." });
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

  const { error: profileError } = await adminClient.from("staff_profiles").insert({
    user_id: createdUser.user.id,
    email: createdUser.user.email,
    role: "staff",
  });
  if (profileError) {
    await adminClient.auth.admin.deleteUser(createdUser.user.id).catch(() => {
      // No-op: the database profile is the source of truth for staff access.
    });
    return jsonResponse(500, {
      error: "The staff profile record could not be created.",
    });
  }

  return jsonResponse(201, { message: "Staff account created." });
});
