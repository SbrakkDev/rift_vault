alter table public.user_decks
  add column if not exists is_match_history_public boolean not null default false;

alter table public.user_matches
  add column if not exists deck_name text not null default 'Deck sconosciuto';

alter table public.user_matches
  add column if not exists opponent_deck_name text not null default 'Deck sconosciuto';

alter table public.user_matches
  add column if not exists opponent_legend_card_id text;

alter table public.user_matches
  add column if not exists opponent_deck_owner_label text not null default '';

alter table public.user_matches
  add column if not exists duration_seconds integer not null default 0;

alter table public.user_matches
  drop constraint if exists user_matches_duration_seconds_check;

alter table public.user_matches
  add constraint user_matches_duration_seconds_check check (duration_seconds >= 0);

drop policy if exists "matches_select_public_history" on public.user_matches;
create policy "matches_select_public_history"
on public.user_matches
for select
using (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.is_public = true
      and d.is_match_history_public = true
  )
);
