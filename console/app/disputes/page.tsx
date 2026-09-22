"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";
import { istTime, rupees } from "@/lib/format";

interface Incident {
  id: string;
  order_id: string;
  type: string;
  status: string;
  evidence_url: string | null;
  created_at: string;
  resolution_note: string | null;
}

interface OrderInfo {
  id: string;
  buyer_name: string;
  vendor_name: string;
  amount_paise: number;
  status: string;
  pay_method: string;
}

const ACTIONS = [
  ["refund", "Refund buyer (full)"],
  ["warning", "Warn vendor"],
  ["delist7", "Delist vendor 7 days"],
  ["delist30", "Delist vendor 30 days"],
  ["ban", "Ban vendor"],
  ["dismiss", "Dismiss"],
] as const;

export default function Disputes() {
  const { profile, loading } = useProfile();
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [orderMap, setOrderMap] = useState<Record<string, OrderInfo>>({});
  const [note, setNote] = useState("");
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    const { data: incs } = await supabase
      .from("incidents")
      .select("*")
      .order("created_at", { ascending: false });
    const rows = (incs as Incident[]) ?? [];
    setIncidents(rows);

    if (rows.length > 0) {
      const ids = rows.map((r) => r.order_id);
      const { data: orders } = await supabase
        .from("orders")
        .select("id, buyer_id, listing_id, amount_paise, status, pay_method")
        .in("id", ids);
      const buyerIds = [...new Set((orders ?? []).map((o) => o.buyer_id))];
      const { data: buyers } = await supabase
        .from("profiles")
        .select("id, name")
        .in("id", buyerIds);
      const listingIds = [...new Set((orders ?? []).map((o: any) => o.listing_id))];
      const { data: listings } = await supabase
        .from("listings")
        .select("id, restaurant_id")
        .in("id", listingIds);
      const restIds = [...new Set((listings ?? []).map((l: any) => l.restaurant_id))];
      const { data: rests } = await supabase
        .from("restaurants")
        .select("id, name")
        .in("id", restIds);

      const buyerName = new Map((buyers ?? []).map((b: any) => [b.id, b.name]));
      const restName = new Map((rests ?? []).map((r: any) => [r.id, r.name]));
      const listingRest = new Map((listings ?? []).map((l: any) => [l.id, l.restaurant_id]));

      const map: Record<string, OrderInfo> = {};
      for (const o of orders ?? []) {
        map[o.id] = {
          id: o.id,
          buyer_name: buyerName.get(o.buyer_id) ?? "—",
          vendor_name:
            restName.get(listingRest.get(o.listing_id) ?? "") ?? "—",
          amount_paise: o.amount_paise,
          status: o.status,
          pay_method: o.pay_method,
        };
      }
      setOrderMap(map);
    }
  }

  useEffect(() => {
    if (profile?.role === "admin") load();
  }, [profile]);

  async function resolve(incidentId: string, action: string) {
    const { error } = await supabase.rpc("admin_resolve_incident", {
      p_incident_id: incidentId,
      p_action: action,
      p_note: note || null,
    });
    setMsg(error ? `Error: ${error.message}` : `Incident → ${action}`);
    if (!error) load();
  }

  return (
    <RequireRole role="admin" profile={profile} loading={loading}>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Disputes / Incidents</h1>
        <input
          className="border rounded px-2 py-1 text-sm w-72"
          placeholder="Resolution note (optional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
      <p className="mt-1 text-xs text-neutral-500">
        Ladder per doc/02 §4.1: 1st issue → warning+refund · 2nd → delist 7d ·
        3rd → delist 30d / ban. Refund-first policy.
      </p>
      {msg && (
        <p className="mt-2 text-sm text-green-700 bg-green-50 rounded px-3 py-2">{msg}</p>
      )}

      <div className="mt-4 space-y-3">
        {incidents.map((i) => {
          const o = orderMap[i.order_id];
          return (
            <div key={i.id} className="bg-white rounded-lg shadow p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-medium text-sm">
                    {i.type.toUpperCase()} · order {o?.id?.slice(0, 8) ?? i.order_id.slice(0, 8)}
                  </div>
                  <div className="text-xs text-neutral-500">
                    Buyer {o?.buyer_name ?? "—"} · Vendor {o?.vendor_name ?? "—"} ·{" "}
                    {rupees(o?.amount_paise ?? 0)} · {o?.pay_method} · opened{" "}
                    {istTime(i.created_at)} IST
                    {i.evidence_url && (
                      <>
                        {" "}
                        · <span className="underline">evidence attached</span>
                      </>
                    )}
                  </div>
                </div>
                <span
                  className={`text-xs rounded-full px-2 py-0.5 ${
                    i.status === "open"
                      ? "bg-amber-100 text-amber-800"
                      : "bg-neutral-100 text-neutral-600"
                  }`}
                >
                  {i.status}
                </span>
              </div>
              {i.status === "open" && (
                <div className="mt-3 flex flex-wrap gap-2">
                  {ACTIONS.map(([a, label]) => (
                    <button
                      key={a}
                      onClick={() => resolve(i.id, a)}
                      className="bg-neutral-900 text-white rounded px-3 py-1 text-xs"
                    >
                      {label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          );
        })}
        {incidents.length === 0 && (
          <div className="text-sm text-neutral-400">No incidents.</div>
        )}
      </div>
    </RequireRole>
  );
}
