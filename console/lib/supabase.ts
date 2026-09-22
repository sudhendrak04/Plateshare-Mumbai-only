import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export type Role = "buyer" | "vendor_owner" | "ngo" | "admin";

export interface Profile {
  id: string;
  name: string;
  role: Role;
  diet_pref: string;
  trust_score: number;
  no_show_count: number;
  is_active: boolean;
}
