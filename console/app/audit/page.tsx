"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";
import { istDate, istTime } from "@/lib/format";

interface AuditRow {
  listing_id: string;
  restaurant_name: string;
  status: string;
  photo_taken_at: string | null;
  created_at: string;
  photo_age_flag: boolean;
  reuse_flag: boolean;
  geotag_mismatch_m: number | null;
}

export default function Audit() {
  const { profile, loading } = useProfile();
  const [rows, setRows] = useState<AuditRow[]>([]);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    const { data, error } = await supabase.rpc("admin_listing_audit");
    if (!error) setRows((data as unknown as AuditRow[]) ?? []);
  }

  useEffect(() => {
    if (profile?.role === "admin") load();
  }, [profile]);

  async function delist(l: AuditRow) {
    const reason = window.prompt("Delist reason:", "Audit violation");
    if (!reason) return;
    const { error } = await supabase.rpc("admin_delist_listing", {
      p_listing_id: l.listing_id,
      p_reason: reason,
    });
    setMsg(error ? `Error: ${error.message}` : "Listing delisted.");
    if (!error) load();
  }

  return (
    <RequireRole role="admin" profile={profile} loading={loading}>
      <h1 className="text-xl font-bold">Listing Audit</h1>
      <p className="mt-1 text-xs text-neutral-500">
        Flags: photo taken &gt; 15 min before listing · same photo reused across
        listings · geotag &gt; 500 m from the outlet (doc/09 QA layer 3).
      </p>
      {msg && (
        <p className="mt-2 text-sm text-green-700 bg-green-50 rounded px-3 py-2">{msg}</p>
      )}

      <table className="mt-4 w-full bg-white rounded-lg shadow text-sm">
        <thead>
          <tr className="text-left text-neutral-500 border-b">
            <th className="p-3">Listing</th>
            <th className="p-3">Vendor</th>
            <th className="p-3">Status</th>
            <th className="p-3">Photo taken</th>
            <th className="p-3">Flags</th>
            <th className="p-3">Action</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((l) => {
            const flags = [
              l.photo_age_flag && "old photo",
              l.reuse_flag && "reused photo",
              l.geotag_mismatch_m !== null && l.geotag_mismatch_m > 500
                ? `geotag off by ${Math.round(l.geotag_mismatch_m)} m`
                : null,
            ].filter(Boolean);
            return (
              <tr key={l.listing_id} className="border-b last:border-0">
                <td className="p-3 font-mono text-xs">{l.listing_id.slice(0, 8)}</td>
                <td className="p-3">{l.restaurant_name}</td>
                <td className="p-3">{l.status}</td>
                <td className="p-3 text-xs">
                  {istTime(l.photo_taken_at)} · {istDate(l.photo_taken_at)}
                </td>
                <td className="p-3">
                  {flags.length === 0 ? (
                    <span className="text-green-700 text-xs">clean</span>
                  ) : (
                    flags.map((f) => (
                      <span
                        key={String(f)}
                        className="mr-1 rounded-full bg-red-100 text-red-800 px-2 py-0.5 text-xs"
                      >
                        {f}
                      </span>
                    ))
                  )}
                </td>
                <td className="p-3">
                  {l.status === "live" && (
                    <button
                      onClick={() => delist(l)}
                      className="bg-red-600 text-white rounded px-2 py-1 text-xs"
                    >
                      Delist
                    </button>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </RequireRole>
  );
}
