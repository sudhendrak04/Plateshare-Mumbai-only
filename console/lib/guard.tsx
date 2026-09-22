"use client";

import { useEffect, useState } from "react";
import { supabase, type Profile } from "./supabase";
import { useRouter } from "next/navigation";

export function useProfile() {
  const router = useRouter();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session?.user) {
        if (!cancelled) {
          setProfile(null);
          setLoading(false);
          router.replace("/login");
        }
        return;
      }

      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", session.user.id)
        .single();

      if (!cancelled) {
        setProfile(error ? null : ((data as Profile) ?? null));
        setLoading(false);
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [router]);

  return { profile, loading };
}

export function RequireRole({
  role,
  profile,
  loading,
  children,
}: {
  role: string;
  profile: Profile | null;
  loading: boolean;
  children: React.ReactNode;
}) {
  if (loading) {
    return (
      <div className="p-8 text-sm text-neutral-500">Checking access…</div>
    );
  }
  if (!profile) {
    return (
      <div className="p-8 text-sm text-neutral-500">
        Not signed in. Redirecting…
      </div>
    );
  }
  if (profile.role !== role) {
    return (
      <div className="p-8">
        <h2 className="text-lg font-semibold text-red-600">Access denied</h2>
        <p className="mt-2 text-sm text-neutral-600">
          This area requires the <b>{role}</b> role. You are signed in as{" "}
          <b>{profile.role}</b>.
        </p>
      </div>
    );
  }
  return <>{children}</>;
}
