"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    (async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.user) return router.replace("/login");

      const { data } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", session.user.id)
        .single();

      if (data?.role === "admin") router.replace("/ops");
      else if (data?.role === "ngo") router.replace("/ngo");
      else router.replace("/login");
    })();
  }, [router]);

  return <p className="text-sm text-neutral-500">Loading console…</p>;
}
