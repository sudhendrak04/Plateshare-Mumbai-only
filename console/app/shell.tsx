"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

function ClockIST() {
  const [now, setNow] = useState<string>("");
  useEffect(() => {
    const tick = () =>
      setNow(
        new Date().toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata",
          weekday: "short",
          day: "2-digit",
          month: "short",
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
          hour12: true,
        })
      );
    tick();
    const t = setInterval(tick, 1000);
    return () => clearInterval(t);
  }, []);
  return <span className="font-mono text-xs text-neutral-300">{now} IST</span>;
}

const ADMIN_NAV = [
  { href: "/ops", label: "Ops Dashboard" },
  { href: "/queues/vendors", label: "Vendor Queue" },
  { href: "/queues/ngos", label: "NGO Queue" },
  { href: "/audit", label: "Listing Audit" },
  { href: "/disputes", label: "Disputes" },
  { href: "/gst", label: "GST Ledger" },
];

const NGO_NAV = [{ href: "/ngo", label: "Donation Claims" }];

export default function Shell({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [role, setRole] = useState<string | null>(null);
  const [name, setName] = useState<string>("");

  useEffect(() => {
    (async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.user) return;
      const { data } = await supabase
        .from("profiles")
        .select("role, name")
        .eq("id", session.user.id)
        .single();
      setRole((data as { role: string; name: string } | null)?.role ?? null);
      setName((data as { name: string } | null)?.name ?? "");
    })();
  }, []);

  const nav = role === "admin" ? ADMIN_NAV : role === "ngo" ? NGO_NAV : [];

  return (
    <div className="flex min-h-screen">
      {role && (
        <aside className="w-56 shrink-0 bg-neutral-900 text-neutral-100 flex flex-col">
          <div className="px-4 py-5 border-b border-neutral-800">
            <div className="text-lg font-bold">Plate Share</div>
            <div className="text-xs text-neutral-400">
              Mumbai · {role === "admin" ? "Admin Console" : "NGO Portal"}
            </div>
          </div>
          <nav className="flex-1 px-2 py-4 space-y-1">
            {nav.map((n) => (
              <a
                key={n.href}
                href={n.href}
                className="block rounded px-3 py-2 text-sm hover:bg-neutral-800"
              >
                {n.label}
              </a>
            ))}
          </nav>
          <div className="px-4 py-4 border-t border-neutral-800 text-xs">
            <div className="text-neutral-400">{name}</div>
            <button
              className="mt-2 text-neutral-300 hover:text-white underline"
              onClick={async () => {
                await supabase.auth.signOut();
                router.push("/login");
              }}
            >
              Sign out
            </button>
          </div>
        </aside>
      )}
      <div className="flex-1 flex flex-col">
        <header className="h-12 bg-neutral-900 flex items-center justify-end px-6 gap-4">
          <ClockIST />
        </header>
        <main className="flex-1 bg-neutral-50 p-6">{children}</main>
      </div>
    </div>
  );
}
