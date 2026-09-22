"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { useRouter } from "next/navigation";

export default function Login() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function signIn() {
    setBusy(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) {
      setError(error.message);
      setBusy(false);
      return;
    }
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session) {
      setError("Login failed — no session.");
      setBusy(false);
      return;
    }
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", session.user.id)
      .single();

    router.replace(profile?.role === "ngo" ? "/ngo" : "/ops");
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-neutral-100">
      <div className="w-full max-w-sm bg-white rounded-xl shadow p-8">
        <h1 className="text-xl font-bold">Plate Share Console</h1>
        <p className="mt-1 text-sm text-neutral-500">
          Admin &amp; NGO sign-in (Mumbai)
        </p>

        <div className="mt-6 space-y-3">
          <input
            className="w-full border rounded-lg px-3 py-2 text-sm"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <input
            className="w-full border rounded-lg px-3 py-2 text-sm"
            placeholder="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && !busy && signIn()}
          />
          <button
            className="w-full bg-neutral-900 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-50"
            disabled={busy}
            onClick={signIn}
          >
            {busy ? "Signing in…" : "Sign in"}
          </button>
          {error && (
            <p className="text-xs text-red-600">{error}</p>
          )}
          <p className="text-[11px] leading-relaxed text-neutral-400">
            Dev logins — admin@plateshare.local / plateshare-dev ·
            ngo@plateshare.local / plateshare-ngo. Phone-OTP login goes live
            once the SMS provider decision is made (doc/PENDING_DECISIONS.md).
          </p>
        </div>
      </div>
    </div>
  );
}
