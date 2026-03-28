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
