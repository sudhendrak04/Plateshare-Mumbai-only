"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";
import { rupees } from "@/lib/format";

interface OpsRow {
  cluster_name: string;
  listed: number;
  sold: number;
  donated: number;
  wasted: number;
  sell_through: number;
  gmv_paise: number;
}

export default function Ops() {
  const { profile, loading } = useProfile();
  const [day, setDay] = useState("");
  const [rows, setRows] = useState<OpsRow[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setDay((d) => d || new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(new Date()));
  }, []);

  useEffect(() => {
    if (!day || profile?.role !== "admin") return;
    (async () => {
      setBusy(true);
      const { data, error } = await supabase.rpc("admin_ops_dashboard", {
        p_day: day,
      });
      if (!error) setRows((data as unknown as OpsRow[]) ?? []);
      setBusy(false);
    })();
  }, [day, profile]);

  const totals = rows.reduce(
    (a, r) => ({
      listed: a.listed + r.listed,
      sold: a.sold + r.sold,
      donated: a.donated + r.donated,
      wasted: a.wasted + r.wasted,
      gmv: a.gmv + r.gmv_paise,
    }),
    { listed: 0, sold: 0, donated: 0, wasted: 0, gmv: 0 }
  );

  return (
    <RequireRole role="admin" profile={profile} loading={loading}>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Ops Dashboard — Mumbai</h1>
        <div className="flex items-center gap-2 text-sm">
          <label>Date:</label>
          <input
            type="date"
            value={day}
            onChange={(e) => setDay(e.target.value)}
            className="border rounded px-2 py-1"
          />
          {busy && <span className="text-neutral-400">…</span>}
        </div>
      </div>

      <div className="mt-3 rounded-lg bg-amber-50 border border-amber-200 px-4 py-2 text-sm text-amber-900">
        North star: <b>sell-through %</b> — the only metric that keeps vendors
        listing. Target &gt; 70%.
      </div>

      <div className="mt-4 grid grid-cols-5 gap-3">
        <Metric label="Boxes listed" value={totals.listed} />
        <Metric label="Boxes sold" value={totals.sold} />
        <Metric label="Donated" value={totals.donated} />
        <Metric label="Wasted" value={totals.wasted} />
        <Metric label="GMV" value={rupees(totals.gmv)} />
      </div>

      <table className="mt-6 w-full bg-white rounded-lg shadow text-sm">
        <thead>
          <tr className="text-left text-neutral-500 border-b">
            <th className="p-3">Cluster</th>
            <th className="p-3">Listed</th>
            <th className="p-3">Sold</th>
            <th className="p-3">Donated</th>
            <th className="p-3">Wasted</th>
            <th className="p-3">Sell-through</th>
            <th className="p-3">GMV</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.cluster_name} className="border-b last:border-0">
              <td className="p-3 font-medium">{r.cluster_name}</td>
              <td className="p-3">{r.listed}</td>
              <td className="p-3">{r.sold}</td>
              <td className="p-3">{r.donated}</td>
              <td className="p-3">{r.wasted}</td>
              <td className="p-3">
                <Badge pct={r.sell_through} />
              </td>
              <td className="p-3">{rupees(r.gmv_paise)}</td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td className="p-3 text-neutral-400" colSpan={7}>
                No data for this date.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </RequireRole>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}

function Badge({ pct }: { pct: number }) {
  const cls =
    pct >= 0.7
      ? "bg-green-100 text-green-800"
      : pct >= 0.5
      ? "bg-amber-100 text-amber-800"
      : "bg-red-100 text-red-800";
  return (
    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>
      {(pct * 100).toFixed(0)}%
    </span>
  );
}
