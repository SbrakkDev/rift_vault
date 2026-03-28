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

create index if not exists idx_community_deck_likes_deck_id
  on public.community_deck_likes (deck_id, created_at desc);

create index if not exists idx_community_deck_views_deck_id
  on public.community_deck_views (deck_id, created_at desc);

alter table public.community_deck_likes enable row level security;
alter table public.community_deck_views enable row level security;

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
