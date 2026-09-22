"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RequireRole, useProfile } from "@/lib/guard";
import { istTime } from "@/lib/format";

interface DonationRow {
  donation_id: string;
  listing_id: string;
  restaurant_name: string;
  qty_left: number;
  broadcast_at: string;
}

interface MyClaim {
  id: string;
  listing_id: string;
  picked_up_at: string | null;
  beneficiary_count: number | null;
  claim_expires_at: string | null;
  restaurant_name: string;
}

export default function NgoPortal() {
  const { profile, loading } = useProfile();
  const [open, setOpen] = useState<DonationRow[]>([]);
  const [mine, setMine] = useState<MyClaim[]>([]);
  const [verified, setVerified] = useState<boolean | null>(null);
  const [ngoName, setNgoName] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [count, setCount] = useState<Record<string, string>>({});

  async function load() {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session?.user) return;

    const { data: ngo } = await supabase
      .from("ngos")
      .select("name, verified")
      .eq("contact_user_id", session.user.id)
      .single();
    setNgoName((ngo as { name: string } | null)?.name ?? "");
    setVerified((ngo as { verified: boolean } | null)?.verified ?? false);

    const { data: openRows } = await supabase.rpc("ngo_open_donations");
    setOpen((openRows as unknown as DonationRow[]) ?? []);

    const { data: myNgo } = await supabase
      .from("ngos")
      .select("id")
      .eq("contact_user_id", session.user.id)
      .single();
    if (!myNgo) return;
    const ngoId = (myNgo as { id: string }).id;
    const { data: mine } = await supabase
      .from("donations")
      .select(
        "id, listing_id, picked_up_at, beneficiary_count, claim_expires_at, listings(restaurant_id, restaurants(name))"
      )
      .eq("ngo_id", ngoId)
      .order("claimed_at", { ascending: false });
    setMine(
      ((mine as unknown as any[]) ?? []).map((d) => ({
        id: d.id,
        listing_id: d.listing_id,
        picked_up_at: d.picked_up_at,
        beneficiary_count: d.beneficiary_count,
        claim_expires_at: d.claim_expires_at,
        restaurant_name: d.listings?.restaurants?.name ?? "—",
      }))
    );
  }

  useEffect(() => {
    if (profile?.role === "ngo") load();
  }, [profile]);

  async function claim(d: DonationRow) {
    const { error } = await supabase.rpc("claim_donation", {
      p_donation_id: d.donation_id,
    });
    setMsg(
      error ? `Error: ${error.message}` : "Claimed! Pick up before the claim hold ends."
    );
    if (!error) load();
  }

  async function confirmPickup(id: string) {
    const { error } = await supabase.rpc("confirm_donation_pickup", {
      p_donation_id: id,
    });
    setMsg(error ? `Error: ${error.message}` : "Pickup confirmed.");
    if (!error) load();
  }

  async function report(id: string) {
    const n = parseInt(count[id] ?? "0", 10);
    const { error } = await supabase.rpc("report_beneficiaries", {
      p_donation_id: id,
      p_count: n,
    });
    setMsg(error ? `Error: ${error.message}` : "Beneficiary count saved.");
    if (!error) load();
  }

  return (
    <RequireRole role="ngo" profile={profile} loading={loading}>
      <h1 className="text-xl font-bold">NGO Portal{ngoName ? ` — ${ngoName}` : ""}</h1>
      {msg && (
        <p className="mt-2 text-sm text-green-700 bg-green-50 rounded px-3 py-2">{msg}</p>
      )}

      {verified === false && (
        <div className="mt-4 rounded-lg bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-900">
          Your NGO is awaiting document verification (48–72h SLA).
        </div>
      )}

      {verified && (
        <>
          <h2 className="mt-6 text-sm font-semibold text-neutral-600">
            Open donation broadcasts (within 5 km)
          </h2>
          <div className="mt-2 bg-white rounded-lg shadow divide-y">
            {open.map((d) => (
              <div key={d.donation_id} className="p-3 flex items-center justify-between">
                <div>
                  <div className="font-medium text-sm">{d.restaurant_name}</div>
                  <div className="text-xs text-neutral-500">
                    {d.qty_left} boxes · broadcast {istTime(d.broadcast_at)} IST
                  </div>
                </div>
                <button
                  onClick={() => claim(d)}
                  className="bg-green-600 text-white rounded px-3 py-1 text-xs"
                >
                  Claim (30-min hold)
                </button>
              </div>
            ))}
            {open.length === 0 && (
              <div className="p-3 text-sm text-neutral-400">
                No open donations nearby.
              </div>
            )}
          </div>

          <h2 className="mt-6 text-sm font-semibold text-neutral-600">My claims</h2>
          <div className="mt-2 bg-white rounded-lg shadow divide-y">
            {mine.map((d) => (
              <div key={d.id} className="p-3 flex items-center justify-between gap-3">
                <div>
                  <div className="font-medium text-sm">{d.restaurant_name}</div>
                  <div className="text-xs text-neutral-500">
                    {d.picked_up_at
                      ? `Picked up ${istTime(d.picked_up_at)} IST`
                      : d.claim_expires_at
                      ? `Claim holds till ${istTime(d.claim_expires_at)} IST`
                      : "—"}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {!d.picked_up_at && (
                    <button
                      onClick={() => confirmPickup(d.id)}
                      className="bg-neutral-900 text-white rounded px-3 py-1 text-xs"
                    >
                      Mark picked up
                    </button>
                  )}
                  {d.picked_up_at && d.beneficiary_count === null && (
                    <>
                      <input
                        className="border rounded px-2 py-1 text-xs w-24"
                        placeholder="People fed"
                        value={count[d.id] ?? ""}
                        onChange={(e) =>
                          setCount((c) => ({ ...c, [d.id]: e.target.value }))
                        }
                      />
                      <button
                        onClick={() => report(d.id)}
                        className="bg-green-600 text-white rounded px-3 py-1 text-xs"
                      >
                        Report
                      </button>
                    </>
                  )}
                  {d.beneficiary_count !== null && (
                    <span className="text-xs text-green-700">
                      {d.beneficiary_count} beneficiaries
                    </span>
                  )}
                </div>
              </div>
            ))}
            {mine.length === 0 && (
              <div className="p-3 text-sm text-neutral-400">No claims yet.</div>
            )}
          </div>
        </>
      )}
    </RequireRole>
  );
}
