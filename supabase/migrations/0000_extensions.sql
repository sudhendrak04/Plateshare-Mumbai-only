-- Stage 2 · 0000_extensions
create extension if not exists postgis with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists moddatetime with schema extensions;
