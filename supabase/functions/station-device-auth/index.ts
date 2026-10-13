import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Station identity is separate from employee identity, but it never replaces
// employee authorization. Every station operation requires the same verified
// employee session that opened the POS.
const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = createClient(url, serviceKey, { auth: { persistSession: false } });
const enc = new TextEncoder();
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type EmployeeSession = {
  userId: string;
  authSessionId: string;
};

async function digest(value: string) {
  const bytes = new Uint8Array(
    await crypto.subtle.digest("SHA-256", enc.encode(value)),
  );
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function response(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
      pragma: "no-cache",
    },
  });
}

function employeeDenied() {
  return response({
    code: "EMPLOYEE_AUTH_REQUIRED",
    error: "Verified employee authorization is required.",
  }, 428);
}

function decodeJwtClaims(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const encoded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "=");
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    const claims: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return claims && typeof claims === "object" && !Array.isArray(claims)
      ? claims as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

async function verifyEmployeeSession(req: Request): Promise<EmployeeSession | null> {
  const match = /^Bearer\s+(.+)$/i.exec(req.headers.get("authorization") ?? "");
  const accessToken = match?.[1]?.trim();
  if (!accessToken || accessToken.length > 8192) return null;

  const claims = decodeJwtClaims(accessToken);
  const userId = claims?.sub;
  const authSessionId = claims?.session_id;
  if (
    claims?.aal !== "aal2" ||
    typeof userId !== "string" ||
    !uuidPattern.test(userId) ||
    typeof authSessionId !== "string" ||
    !uuidPattern.test(authSessionId)
  ) {
    return null;
  }

  // Validate the token with Supabase Auth; decoded claims alone are not trusted.
  const verifier = createClient(url, anonKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
  const { data, error } = await verifier.auth.getUser(accessToken);
  if (error || !data.user || data.user.id !== userId) return null;
  return { userId, authSessionId };
}

async function employeeMayUseStation(employee: EmployeeSession) {
  const { data, error } = await db.rpc("gs_1256_employee_can_use_station", {
    p_employee_user_id: employee.userId,
  });
  return error ? null : data === true;
}

async function authorizeStationSession(
  tokenHash: string,
  employee: EmployeeSession,
): Promise<Response | null> {
  const { data, error } = await db.rpc(
    "gs_1256_station_employee_session_access",
    {
      p_token_hash: tokenHash,
      p_employee_user_id: employee.userId,
      p_employee_auth_session_id: employee.authSessionId,
    },
  );
  if (error) {
    return response({ error: "Station authorization is temporarily unavailable." }, 503);
  }
  if (data === "authorized") return null;
  if (data === "employee_invalid" || data === "employee_mismatch") {
    return employeeDenied();
  }
  return response({
    code: "STATION_SESSION_INVALID",
    error: "Station session expired or revoked.",
  }, 401);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    const raw = await req.text();
    if (enc.encode(raw).byteLength > 4096) {
      return response({ error: "Request too large" }, 413);
    }
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("Invalid request");
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return response({ error: "Invalid request" }, 400);
  }

  // Logout only revokes the submitted station token and is safe without an
  // employee session. All sign-in, heartbeat, and ticket actions require AAL2.
  let employee: EmployeeSession | null = null;
  if (body.action !== "logout") {
    try {
      employee = await verifyEmployeeSession(req);
    } catch {
      return response({
        code: "EMPLOYEE_AUTH_UNAVAILABLE",
        error: "Employee authorization could not be verified.",
      }, 503);
    }
    if (!employee) return employeeDenied();
  }

  if (body.action === "login") {
    if (
      typeof body.username !== "string" ||
      typeof body.password !== "string" ||
      body.username.length > 64 ||
      body.password.length > 128 ||
      body.username.length < 4
    ) {
      return response({ error: "Invalid request" }, 400);
    }
    const allowed = await employeeMayUseStation(employee!);
    if (allowed === null) {
      return response({ error: "Employee authorization is temporarily unavailable." }, 503);
    }
    if (!allowed) return employeeDenied();

    const token = crypto.randomUUID() + "." + crypto.randomUUID();
    const tokenHash = await digest(token);
    const { data, error } = await db.rpc("gs_1223_device_login", {
      p_username: body.username,
      p_password: body.password,
      p_token_hash: tokenHash,
    });
    if (error) return response({ error: "Login unavailable" }, 503);
    if (!data?.length) {
      return response({
        code: "STATION_CREDENTIALS_INVALID",
        error: "Invalid credentials or temporarily blocked.",
      }, 401);
    }

    const denied = await authorizeStationSession(tokenHash, employee!);
    if (denied) {
      // Do not leave a device token alive when employee binding fails.
      await db.rpc("gs_1226_device_logout", { p_token_hash: tokenHash });
      return denied;
    }
    return response({
      token,
      station: data[0].station_key,
      session_id: data[0].session_id,
      expires_at: data[0].expires_at,
      order_print: data[0].order_print,
      bill_print: data[0].bill_print,
    });
  }

  if (body.action === "heartbeat" || body.action === "logout") {
    if (
      typeof body.token !== "string" ||
      body.token.length > 256 ||
      body.token.length < 20
    ) {
      return response({ error: "Invalid session" }, 401);
    }
    const tokenHash = await digest(body.token);
    if (body.action === "logout") {
      const { data, error } = await db.rpc("gs_1226_device_logout", {
        p_token_hash: tokenHash,
      });
      if (error) return response({ error: "Logout unavailable" }, 503);
      return response({ revoked: data === true });
    }
    const denied = await authorizeStationSession(tokenHash, employee!);
    if (denied) return denied;
    const { data, error } = await db.rpc("gs_1223_device_heartbeat", {
      p_token_hash: tokenHash,
      p_printer_ready: body.printer_ready === true,
    });
    if (error || !data?.length) {
      return response({ error: "Expired or revoked session" }, 401);
    }
    return response({
      station: data[0].station_key,
      order_print: data[0].order_print,
      bill_print: data[0].bill_print,
      expires_at: data[0].expires_at,
    });
  }

  if (body.action === "claim_print" || body.action === "ack_print") {
    if (
      typeof body.token !== "string" ||
      body.token.length < 20 ||
      body.token.length > 256
    ) {
      return response({ error: "Invalid session" }, 401);
    }
    const tokenHash = await digest(body.token);
    const denied = await authorizeStationSession(tokenHash, employee!);
    if (denied) return denied;
    if (body.action === "claim_print") {
      const { data, error } = await db.rpc("gs_1227_device_claim_print", {
        p_token_hash: tokenHash,
      });
      if (error) return response({ error: "Unable to claim station ticket" }, 403);
      return response({ ticket: Array.isArray(data) && data.length ? data[0] : null });
    }
    if (
      typeof body.ticket_id !== "number" ||
      !Number.isSafeInteger(body.ticket_id) ||
      body.ticket_id <= 0 ||
      typeof body.attempt !== "number" ||
      !Number.isSafeInteger(body.attempt) ||
      body.attempt <= 0 ||
      !["received", "printed", "failed"].includes(String(body.result)) ||
      (body.error != null &&
        (typeof body.error !== "string" || body.error.length > 500))
    ) {
      return response({ error: "Invalid print acknowledgment" }, 400);
    }
    const { data, error } = await db.rpc("gs_1227_device_ack_print", {
      p_token_hash: tokenHash,
      p_ticket_id: body.ticket_id,
      p_attempt: body.attempt,
      p_result: body.result,
      p_error: body.error ?? null,
    });
    if (error || data !== true) {
      return response({ error: "Print acknowledgment rejected" }, 409);
    }
    return response({ acknowledged: true });
  }

  if (body.action === "resolve_print") {
    if (
      typeof body.token !== "string" ||
      body.token.length < 20 ||
      body.token.length > 256 ||
      !Number.isSafeInteger(body.ticket_id) ||
      Number(body.ticket_id) <= 0 ||
      !Number.isSafeInteger(body.attempt) ||
      Number(body.attempt) <= 0
    ) {
      return response({ error: "Invalid print request" }, 400);
    }
    const tokenHash = await digest(body.token);
    const denied = await authorizeStationSession(tokenHash, employee!);
    if (denied) return denied;
    const { data, error } = await db.rpc("gs_1230_resolve_station_ticket", {
      p_token_hash: tokenHash,
      p_ticket_id: body.ticket_id,
      p_attempt: body.attempt,
    });
    if (error || !data) {
      return response({ error: "Print ticket unavailable" }, 403);
    }
    return response({ ticket: data });
  }

  if (
    ["claim_revision_print", "resolve_revision_print", "ack_revision_print"]
      .includes(String(body.action))
  ) {
    if (
      typeof body.token !== "string" ||
      body.token.length < 20 ||
      body.token.length > 256
    ) {
      return response({ error: "Invalid station session" }, 401);
    }
    const tokenHash = await digest(body.token);
    const denied = await authorizeStationSession(tokenHash, employee!);
    if (denied) return denied;
    if (body.action === "claim_revision_print") {
      const { data, error } = await db.rpc("gs_1233_claim_revision_print", {
        p_token_hash: tokenHash,
      });
      if (error) return response({ error: "Revision claim unavailable" }, 403);
      return response({ ticket: Array.isArray(data) && data.length ? data[0] : null });
    }
    if (
      !Number.isSafeInteger(body.ticket_id) ||
      Number(body.ticket_id) <= 0 ||
      !Number.isSafeInteger(body.attempt) ||
      Number(body.attempt) <= 0
    ) {
      return response({ error: "Invalid revision ticket" }, 400);
    }
    if (body.action === "resolve_revision_print") {
      const { data, error } = await db.rpc("gs_1233_resolve_revision_print", {
        p_token_hash: tokenHash,
        p_ticket_id: body.ticket_id,
        p_attempt: body.attempt,
      });
      if (error || !data) {
        return response({ error: "Revision payload unavailable" }, 403);
      }
      return response({ ticket: data });
    }
    if (
      !["received", "printed", "failed"].includes(String(body.result)) ||
      (body.error != null &&
        (typeof body.error !== "string" || body.error.length > 500))
    ) {
      return response({ error: "Invalid revision acknowledgment" }, 400);
    }
    const { data, error } = await db.rpc("gs_1233_ack_revision_print", {
      p_token_hash: tokenHash,
      p_ticket_id: body.ticket_id,
      p_attempt: body.attempt,
      p_result: body.result,
      p_error: body.error ?? null,
    });
    if (error || data !== true) {
      return response({ error: "Revision acknowledgment rejected" }, 409);
    }
    return response({ acknowledged: true });
  }

  return response({ error: "Unknown action" }, 400);
});
