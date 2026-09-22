"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";

interface Ngo {
  id: string;
  name: string;
  reg_12a: string | null;
  reg_80g: string | null;
  darpan_id: string | null;
  verified: boolean;
  contact_user_id: string;
}

export default function NgoQueue() {
  const { profile, loading } = useProfile();
  const [rows, setRows] = useState<Ngo[]>([]);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    const { data } = await supabase
      .from("ngos")
      .select("*")
      .order("verified", { ascending: true });
    setRows((data as Ngo[]) ?? []);
  }

  useEffect(() => {
    if (profile?.role === "admin") load();
  }, [profile]);

  async function decide(n: Ngo, approve: boolean) {
    const { error } = await supabase.rpc("admin_verify_ngo", {
      p_ngo_id: n.id,
      p_approve: approve,
      p_reason: approve ? null : "Documents incomplete",
    });
    setMsg(error ? `Error: ${error.message}` : `${n.name} → ${approve ? "verified" : "rejected"}`);
    if (!error) load();
  }

  const pending = rows.filter((n) => !n.verified);

  return (
    <RequireRole role="admin" profile={profile} loading={loading}>
      <h1 className="text-xl font-bold">NGO Verification Queue</h1>
      {msg && (
        <p className="mt-2 text-sm text-green-700 bg-green-50 rounded px-3 py-2">{msg}</p>
      )}
      <div className="mt-4 bg-white rounded-lg shadow divide-y">
        {pending.map((n) => (
          <div key={n.id} className="p-3 flex items-center justify-between gap-3">
            <div>
              <div className="font-medium">{n.name}</div>
              <div className="text-xs text-neutral-500">
                12A: {n.reg_12a ?? "—"} · 80G: {n.reg_80g ?? "—"} · Darpan:{" "}
                {n.darpan_id ?? "—"}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => decide(n, true)}
                className="bg-green-600 text-white rounded px-3 py-1 text-xs"
              >
                Verify
              </button>
              <button
                onClick={() => decide(n, false)}
                className="bg-red-600 text-white rounded px-3 py-1 text-xs"
              >
                Reject
              </button>
            </div>
          </div>
        ))}
        {pending.length === 0 && (
          <div className="p-3 text-sm text-neutral-400">No pending NGOs.</div>
        )}
      </div>

      <h2 className="mt-6 text-sm font-semibold text-neutral-600">
        Verified NGOs ({rows.length - pending.length})
      </h2>
      <div className="mt-2 bg-white rounded-lg shadow divide-y">
        {rows
          .filter((n) => n.verified)
          .map((n) => (
            <div key={n.id} className="p-3 text-sm">
              {n.name}
            </div>
          ))}
      </div>
    </RequireRole>
  );
}
