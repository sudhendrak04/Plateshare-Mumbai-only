"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";
import { istDate } from "@/lib/format";

interface Restaurant {
  id: string;
  name: string;
  fssai_license: string;
  fssai_expiry_date: string | null;
  status: string;
  payout_upi: string | null;
  rating_avg: number;
  created_at: string;
}

export default function VendorQueue() {
  const { profile, loading } = useProfile();
  const [rows, setRows] = useState<Restaurant[]>([]);
  const [reason, setReason] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    const { data } = await supabase
      .from("restaurants")
      .select("*")
      .order("created_at", { ascending: false });
    setRows((data as Restaurant[]) ?? []);
  }

  useEffect(() => {
    if (profile?.role === "admin") load();
  }, [profile]);

  async function decide(r: Restaurant, approve: boolean) {
    setBusyId(r.id);
    const { error } = await supabase.rpc("admin_verify_vendor", {
      p_restaurant_id: r.id,
      p_approve: approve,
      p_reason: approve ? null : reason || "Documents incomplete",
    });
    setBusyId(null);
    setMsg(error ? `Error: ${error.message}` : `${r.name} → ${approve ? "verified" : "rejected"}`);
    if (!error) load();
  }

  const pending = rows.filter((r) => r.status === "pending");
  const verified = rows.filter((r) => r.status === "verified");
  const other = rows.filter(
    (r) => r.status !== "pending" && r.status !== "verified"
  );

  return (
    <RequireRole role="admin" profile={profile} loading={loading}>
      <h1 className="text-xl font-bold">Vendor Verification Queue</h1>
      {msg && (
        <p className="mt-2 text-sm text-green-700 bg-green-50 rounded px-3 py-2">
          {msg}
        </p>
      )}
      {reason && (
        <p className="mt-2 text-xs text-neutral-500">
          Rejection reason: “{reason}”
        </p>
      )}

      <Section title={`Pending (${pending.length})`}>
        {pending.map((r) => (
          <Row key={r.id} r={r}>
            <input
              placeholder="Rejection reason (if rejecting)"
              className="border rounded px-2 py-1 text-xs w-64"
              onChange={(e) => setReason(e.target.value)}
            />
            <button
              disabled={busyId === r.id}
              onClick={() => decide(r, true)}
              className="bg-green-600 text-white rounded px-3 py-1 text-xs"
            >
              Approve
            </button>
            <button
              disabled={busyId === r.id}
              onClick={() => decide(r, false)}
              className="bg-red-600 text-white rounded px-3 py-1 text-xs"
            >
              Reject
            </button>
          </Row>
        ))}
        {pending.length === 0 && <Empty />}
      </Section>

      <Section title={`Verified (${verified.length})`}>
        {verified.map((r) => {
          const expSoon =
            r.fssai_expiry_date &&
            new Date(r.fssai_expiry_date) < new Date(Date.now() + 30 * 864e5);
          return (
            <Row key={r.id} r={r}>
              <span
                className={`text-xs ${
                  expSoon ? "text-red-600 font-semibold" : "text-neutral-400"
                }`}
              >
                FSSAI valid till {istDate(r.fssai_expiry_date)}
                {expSoon ? " — renew soon!" : ""}
              </span>
            </Row>
          );
        })}
        {verified.length === 0 && <Empty />}
      </Section>

      <Section title={`Rejected / Suspended (${other.length})`}>
        {other.map((r) => (
          <Row key={r.id} r={r} />
        ))}
        {other.length === 0 && <Empty />}
      </Section>
    </RequireRole>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="mt-6">
      <h2 className="text-sm font-semibold text-neutral-600">{title}</h2>
      <div className="mt-2 bg-white rounded-lg shadow divide-y">{children}</div>
    </div>
  );
}

function Row({
  r,
  children,
}: {
  r: Restaurant;
  children?: React.ReactNode;
}) {
  return (
    <div className="p-3 flex items-center justify-between gap-3">
      <div>
        <div className="font-medium">{r.name}</div>
        <div className="text-xs text-neutral-500">
          FSSAI {r.fssai_license} · UPI {r.payout_upi ?? "—"} · ★ {r.rating_avg}
        </div>
      </div>
      <div className="flex items-center gap-2">{children}</div>
    </div>
  );
}

function Empty() {
  return <div className="p-3 text-sm text-neutral-400">Empty.</div>;
}
