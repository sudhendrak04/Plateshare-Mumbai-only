"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";
import { rupees, todayIST } from "@/lib/format";

interface LedgerRow {
  order_id: string;
  amount_paise: number;
  gst_collected_paise: number;
  captured_at: string;
}

export default function Gst() {
  const { profile, loading } = useProfile();
  const [month, setMonth] = useState("");
  const [rows, setRows] = useState<LedgerRow[]>([]);

  useEffect(() => {
    const now = todayIST().slice(0, 7);
    setMonth((m) => m || `${now}-01`);
  }, []);

  useEffect(() => {
    if (!month || profile?.role !== "admin") return;
    (async () => {
      const { data } = await supabase.rpc("admin_gst_ledger", {
        p_month: `${month}-01`,
      });
      // note: client-side month filter (RPC filters on capture month server-side)
      setRows(
        ((data as unknown as LedgerRow[]) ?? []).filter((r) =>
          r.captured_at?.startsWith(month)
        )
      );
    })();
  }, [month, profile]);

  const totalGst = rows.reduce((a, r) => a + r.gst_collected_paise, 0);
  const totalAmt = rows.reduce((a, r) => a + r.amount_paise, 0);

  function exportCsv() {
    const lines = [
      "order_id,amount_paise,gst_collected_paise,captured_at",
      ...rows.map(
        (r) =>
          `${r.order_id},${r.amount_paise},${r.gst_collected_paise},${r.captured_at}`
      ),
    ];
    const blob = new Blob([lines.join("\n")], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `plateshare-gst-${month}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <RequireRole role="admin" profile={profile} loading={loading}>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">GST Ledger</h1>
        <div className="flex items-center gap-2 text-sm">
          <input
            type="month"
            value={month}
            onChange={(e) => setMonth(e.target.value)}
            className="border rounded px-2 py-1"
          />
          <button
            onClick={exportCsv}
            disabled={rows.length === 0}
            className="bg-neutral-900 text-white rounded px-3 py-1 text-xs disabled:opacity-50"
          >
            Export CSV
          </button>
        </div>
      </div>
      <p className="mt-1 text-xs text-neutral-500">
        Model-agnostic export (doc/07 §4): per-payment GST collected. Works
        under either the ECO (Sec 9(5)) or vendor-as-seller model — the CA
        decision decides how this is filed, not what is stored.
      </p>

      <div className="mt-4 grid grid-cols-3 gap-3">
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-neutral-500">Transactions</div>
          <div className="text-2xl font-bold mt-1">{rows.length}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-neutral-500">GMV</div>
          <div className="text-2xl font-bold mt-1">{rupees(totalAmt)}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-neutral-500">GST collected</div>
          <div className="text-2xl font-bold mt-1">{rupees(totalGst)}</div>
        </div>
      </div>

      <table className="mt-4 w-full bg-white rounded-lg shadow text-sm">
        <thead>
          <tr className="text-left text-neutral-500 border-b">
            <th className="p-3">Order</th>
            <th className="p-3">Amount</th>
            <th className="p-3">GST</th>
            <th className="p-3">Captured</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.order_id} className="border-b last:border-0">
              <td className="p-3 font-mono text-xs">{r.order_id.slice(0, 8)}</td>
              <td className="p-3">{rupees(r.amount_paise)}</td>
              <td className="p-3">{rupees(r.gst_collected_paise)}</td>
              <td className="p-3 text-xs">{r.captured_at}</td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td className="p-3 text-neutral-400" colSpan={4}>
                No captured payments this month.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </RequireRole>
  );
}
