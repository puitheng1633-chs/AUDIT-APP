// Admin-only user management for the SSA Audit Tracker.
// Deployed with verify_jwt = false; the caller's session token is verified here and only active admins may act.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const DOMAIN = "audit-app.local";
const ROLES = ["admin", "auditor", "reviewer"];
const USER_RX = /^[a-z0-9._-]{2,32}$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sign in first." }, 401);
  const { data: who, error: whoErr } = await admin.auth.getUser(token);
  if (whoErr || !who?.user) return json({ error: "Your session has expired. Sign in again." }, 401);
  const { data: me } = await admin.from("profiles").select("id, role, active").eq("id", who.user.id).maybeSingle();
  if (!me || !me.active || me.role !== "admin") return json({ error: "Only an admin can manage users." }, 403);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { return json({ error: "Invalid request." }, 400); }
  const action = String(body.action || "");

  try {
    if (action === "list") {
      const { data: profiles, error } = await admin.from("profiles").select("*").order("created_at");
      if (error) throw error;
      const { data: au } = await admin.auth.admin.listUsers({ perPage: 1000 });
      const last = new Map((au?.users || []).map((u) => [u.id, u.last_sign_in_at]));
      return json({ users: profiles.map((p) => ({ ...p, last_sign_in_at: last.get(p.id) || null })) });
    }

    if (action === "create") {
      const username = String(body.username || "").trim().toLowerCase();
      const full_name = String(body.full_name || "").trim();
      const role = String(body.role || "auditor");
      const password = String(body.password || "");
      if (!USER_RX.test(username)) return json({ error: "Username must be 2–32 characters: lowercase letters, numbers, dot, dash or underscore." }, 400);
      if (!ROLES.includes(role)) return json({ error: "Unknown role." }, 400);
      if (password.length < 6) return json({ error: "Initial password must be at least 6 characters." }, 400);
      const { data: exists } = await admin.from("profiles").select("id").eq("username", username).maybeSingle();
      if (exists) return json({ error: `Username "${username}" is already taken.` }, 409);
      const { data: created, error } = await admin.auth.admin.createUser({
        email: `${username}@${DOMAIN}`, password, email_confirm: true,
        user_metadata: { username, full_name },
      });
      if (error) throw error;
      const { error: pErr } = await admin.from("profiles").insert({ id: created.user.id, username, full_name, role });
      if (pErr) { await admin.auth.admin.deleteUser(created.user.id); throw pErr; }
      return json({ ok: true, id: created.user.id });
    }

    const id = String(body.id || "");
    if (!id) return json({ error: "Missing user id." }, 400);

    if (action === "reset_password") {
      const password = String(body.password || "");
      if (password.length < 6) return json({ error: "Password must be at least 6 characters." }, 400);
      const { error } = await admin.auth.admin.updateUserById(id, { password });
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "update") {
      const patch: Record<string, unknown> = {};
      if (body.full_name !== undefined) patch.full_name = String(body.full_name).trim();
      if (body.role !== undefined) { if (!ROLES.includes(String(body.role))) return json({ error: "Unknown role." }, 400); patch.role = body.role; }
      if (body.active !== undefined) patch.active = !!body.active;
      if (id === me.id && (patch.active === false || (patch.role && patch.role !== "admin")))
        return json({ error: "You cannot remove your own admin access." }, 400);
      const { error } = await admin.from("profiles").update(patch).eq("id", id);
      if (error) throw error;
      if (patch.active !== undefined) await admin.auth.admin.updateUserById(id, { ban_duration: patch.active ? "none" : "876000h" });
      return json({ ok: true });
    }

    if (action === "delete") {
      if (id === me.id) return json({ error: "You cannot delete your own account." }, 400);
      const { error } = await admin.auth.admin.deleteUser(id);
      if (error) throw error;
      return json({ ok: true });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    return json({ error: (e as Error).message || "Something went wrong." }, 500);
  }
});
