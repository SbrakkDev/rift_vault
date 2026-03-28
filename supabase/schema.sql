create extension if not exists pgcrypto;

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create table if not exists public.user_collection_entries (
  user_id uuid not null references auth.users (id) on delete cascade,
  card_id text not null,
  owned integer not null default 0 check (owned >= 0),
  wanted boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, card_id)
);

create table if not exists public.user_decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default '',
  legend_card_id text,
  chosen_champion_card_id text,
  notes text not null default '',
  is_public boolean not null default false,
  is_match_history_public boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_deck_entries (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references public.user_decks (id) on delete cascade,
  card_id text not null,
  slot text not null check (slot in ('main', 'rune', 'battlefield', 'sideboard')),
  count integer not null check (
    (slot = 'battlefield' and count = 1)
    or (slot = 'rune' and count > 0 and count <= 12)
    or (slot in ('main', 'sideboard') and count > 0 and count <= 3)
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (deck_id, card_id, slot)
);

create table if not exists public.community_deck_likes (
  deck_id uuid not null references public.user_decks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (deck_id, user_id)
);

create table if not exists public.community_deck_views (
  deck_id uuid not null references public.user_decks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (deck_id, user_id)
);

create table if not exists public.user_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  deck_id uuid references public.user_decks (id) on delete set null,
  deck_name text not null default 'Deck sconosciuto',
  opponent_deck_name text not null default 'Deck sconosciuto',
  opponent_legend_card_id text,
  opponent_deck_owner_label text not null default '',
  opponent_name text not null default '',
  your_score integer not null default 0 check (your_score >= 0 and your_score <= 10),
  opponent_score integer not null default 0 check (opponent_score >= 0 and opponent_score <= 10),
  your_rounds integer not null default 0 check (your_rounds >= 0 and your_rounds <= 2),
  opponent_rounds integer not null default 0 check (opponent_rounds >= 0 and opponent_rounds <= 2),
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  outcome text not null check (outcome in ('win', 'loss', 'draw')),
  played_at timestamptz not null default timezone('utc', now()),
  notes text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_user_collection_entries_user_id
  on public.user_collection_entries (user_id);

create unique index if not exists idx_friendships_unique_pair
  on public.friendships ((least(requester_id::text, addressee_id::text)), (greatest(requester_id::text, addressee_id::text)));

create index if not exists idx_friendships_requester_id
  on public.friendships (requester_id, created_at desc);

create index if not exists idx_friendships_addressee_id
  on public.friendships (addressee_id, created_at desc);

create index if not exists idx_user_decks_user_id
  on public.user_decks (user_id, updated_at desc);

create index if not exists idx_user_deck_entries_deck_id
  on public.user_deck_entries (deck_id);

create index if not exists idx_community_deck_likes_deck_id
  on public.community_deck_likes (deck_id, created_at desc);

create index if not exists idx_community_deck_views_deck_id
  on public.community_deck_views (deck_id, created_at desc);

create index if not exists idx_user_matches_user_id
  on public.user_matches (user_id, played_at desc);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.handle_updated_at();

drop trigger if exists friendships_set_updated_at on public.friendships;
create trigger friendships_set_updated_at
before update on public.friendships
for each row execute function public.handle_updated_at();

drop trigger if exists user_collection_entries_set_updated_at on public.user_collection_entries;
create trigger user_collection_entries_set_updated_at
before update on public.user_collection_entries
for each row execute function public.handle_updated_at();

drop trigger if exists user_decks_set_updated_at on public.user_decks;
create trigger user_decks_set_updated_at
before update on public.user_decks
for each row execute function public.handle_updated_at();

drop trigger if exists user_deck_entries_set_updated_at on public.user_deck_entries;
create trigger user_deck_entries_set_updated_at
before update on public.user_deck_entries
for each row execute function public.handle_updated_at();

drop trigger if exists user_matches_set_updated_at on public.user_matches;
create trigger user_matches_set_updated_at
before update on public.user_matches
for each row execute function public.handle_updated_at();

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.user_collection_entries enable row level security;
alter table public.user_decks enable row level security;
alter table public.user_deck_entries enable row level security;
alter table public.community_deck_likes enable row level security;
alter table public.community_deck_views enable row level security;
alter table public.user_matches enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
using (auth.role() = 'authenticated');

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "friendships_select_related" on public.friendships;
create policy "friendships_select_related"
on public.friendships
for select
using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "friendships_insert_own" on public.friendships;
create policy "friendships_insert_own"
on public.friendships
for insert
with check (auth.uid() = requester_id);

drop policy if exists "friendships_update_addressee" on public.friendships;
create policy "friendships_update_addressee"
on public.friendships
for update
using (auth.uid() = addressee_id)
with check (auth.uid() = addressee_id);

drop policy if exists "friendships_delete_related" on public.friendships;
create policy "friendships_delete_related"
on public.friendships
for delete
using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "collection_select_own" on public.user_collection_entries;
create policy "collection_select_own"
on public.user_collection_entries
for select
using (auth.uid() = user_id);

drop policy if exists "collection_select_public_favorites" on public.user_collection_entries;
create policy "collection_select_public_favorites"
on public.user_collection_entries
for select
using (wanted = true);

drop policy if exists "collection_insert_own" on public.user_collection_entries;
create policy "collection_insert_own"
on public.user_collection_entries
for insert
with check (auth.uid() = user_id);

drop policy if exists "collection_update_own" on public.user_collection_entries;
create policy "collection_update_own"
on public.user_collection_entries
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "collection_delete_own" on public.user_collection_entries;
create policy "collection_delete_own"
on public.user_collection_entries
for delete
using (auth.uid() = user_id);

drop policy if exists "decks_select_own_or_public" on public.user_decks;
drop policy if exists "decks_select_own_friends_or_public" on public.user_decks;
create policy "decks_select_own_friends_or_public"
on public.user_decks
for select
using (
  auth.uid() = user_id
  or is_public = true
  or exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and (
        (f.requester_id = auth.uid() and f.addressee_id = user_id)
        or
        (f.addressee_id = auth.uid() and f.requester_id = user_id)
      )
  )
);

drop policy if exists "decks_insert_own" on public.user_decks;
create policy "decks_insert_own"
on public.user_decks
for insert
with check (auth.uid() = user_id);

drop policy if exists "decks_update_own" on public.user_decks;
create policy "decks_update_own"
on public.user_decks
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "decks_delete_own" on public.user_decks;
create policy "decks_delete_own"
on public.user_decks
for delete
using (auth.uid() = user_id);

drop policy if exists "deck_entries_select_own_or_public" on public.user_deck_entries;
drop policy if exists "deck_entries_select_own_friends_or_public" on public.user_deck_entries;
create policy "deck_entries_select_own_friends_or_public"
on public.user_deck_entries
for select
using (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and (
        d.user_id = auth.uid()
        or d.is_public = true
        or exists (
          select 1
          from public.friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = auth.uid() and f.addressee_id = d.user_id)
              or
              (f.addressee_id = auth.uid() and f.requester_id = d.user_id)
            )
        )
      )
  )
);

drop policy if exists "deck_entries_insert_own" on public.user_deck_entries;
create policy "deck_entries_insert_own"
on public.user_deck_entries
for insert
with check (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.user_id = auth.uid()
  )
);

drop policy if exists "deck_entries_update_own" on public.user_deck_entries;
create policy "deck_entries_update_own"
on public.user_deck_entries
for update
using (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.user_id = auth.uid()
  )
);

drop policy if exists "deck_entries_delete_own" on public.user_deck_entries;
create policy "deck_entries_delete_own"
on public.user_deck_entries
for delete
using (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.user_id = auth.uid()
  )
);

drop policy if exists "matches_select_own" on public.user_matches;
create policy "matches_select_own"
on public.user_matches
for select
using (auth.uid() = user_id);

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

drop policy if exists "community_likes_select_accessible" on public.community_deck_likes;
create policy "community_likes_select_accessible"
on public.community_deck_likes
for select
using (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and (
        d.user_id = auth.uid()
        or d.is_public = true
        or exists (
          select 1
          from public.friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = auth.uid() and f.addressee_id = d.user_id)
              or
              (f.addressee_id = auth.uid() and f.requester_id = d.user_id)
            )
        )
      )
  )
);

drop policy if exists "community_likes_insert_public_non_owner" on public.community_deck_likes;
create policy "community_likes_insert_public_non_owner"
on public.community_deck_likes
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.is_public = true
      and d.user_id <> auth.uid()
  )
);

drop policy if exists "community_likes_delete_own" on public.community_deck_likes;
create policy "community_likes_delete_own"
on public.community_deck_likes
for delete
using (auth.uid() = user_id);

drop policy if exists "community_views_select_accessible" on public.community_deck_views;
create policy "community_views_select_accessible"
on public.community_deck_views
for select
using (
  exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and (
        d.user_id = auth.uid()
        or d.is_public = true
        or exists (
          select 1
          from public.friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = auth.uid() and f.addressee_id = d.user_id)
              or
              (f.addressee_id = auth.uid() and f.requester_id = d.user_id)
            )
        )
      )
  )
);

drop policy if exists "community_views_insert_public_non_owner" on public.community_deck_views;
create policy "community_views_insert_public_non_owner"
on public.community_deck_views
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.user_decks d
    where d.id = deck_id
      and d.is_public = true
      and d.user_id <> auth.uid()
  )
);

drop policy if exists "matches_insert_own" on public.user_matches;
create policy "matches_insert_own"
on public.user_matches
for insert
with check (auth.uid() = user_id);

drop policy if exists "matches_update_own" on public.user_matches;
create policy "matches_update_own"
on public.user_matches
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "matches_delete_own" on public.user_matches;
create policy "matches_delete_own"
on public.user_matches
for delete
using (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();
