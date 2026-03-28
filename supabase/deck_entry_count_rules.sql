alter table public.user_deck_entries
drop constraint if exists user_deck_entries_count_check;

alter table public.user_deck_entries
add constraint user_deck_entries_count_check
check (
  (slot = 'battlefield' and count = 1)
  or (slot = 'rune' and count > 0 and count <= 12)
  or (slot in ('main', 'sideboard') and count > 0 and count <= 3)
);
