drop policy if exists "collection_select_public_favorites" on public.user_collection_entries;
create policy "collection_select_public_favorites"
on public.user_collection_entries
for select
using (wanted = true);
