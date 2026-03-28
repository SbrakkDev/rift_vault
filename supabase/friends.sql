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

create unique index if not exists idx_friendships_unique_pair
  on public.friendships ((least(requester_id::text, addressee_id::text)), (greatest(requester_id::text, addressee_id::text)));

create index if not exists idx_friendships_requester_id
  on public.friendships (requester_id, created_at desc);

create index if not exists idx_friendships_addressee_id
  on public.friendships (addressee_id, created_at desc);

drop trigger if exists friendships_set_updated_at on public.friendships;
create trigger friendships_set_updated_at
before update on public.friendships
for each row execute function public.handle_updated_at();

alter table public.friendships enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
using (auth.role() = 'authenticated');

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
