import type { BinderPreview, CommunityProfile, DeckPreview } from "../types";

export const deckPreviews: DeckPreview[] = [
  {
    id: "deck-1",
    name: "Ahri Control",
    owner: "@davide",
    isPublic: false,
    priceLabel: "€ 78",
    setCodes: ["OGN"],
    domains: ["Calm", "Mind"],
    legendImage: "/illustrations/origins.png",
    views: 12,
    likes: 4
  },
  {
    id: "deck-2",
    name: "MF aggro ganking",
    owner: "@sbrakkius",
    isPublic: true,
    priceLabel: "€ 126",
    setCodes: ["OGN", "SFD"],
    domains: ["Body", "Chaos"],
    legendImage: "/illustrations/spiritforged.png",
    views: 132,
    likes: 48
  },
  {
    id: "deck-3",
    name: "Rosso-giallo",
    owner: "@davide",
    isPublic: false,
    priceLabel: "€ 95",
    setCodes: ["OGN"],
    domains: ["Fury", "Order"],
    legendImage: "/illustrations/unleashed.png",
    views: 7,
    likes: 1
  }
];

export const binderPreviews: BinderPreview[] = [
  {
    id: "origins",
    title: "Origins",
    code: "OGN",
    cardCountLabel: "298 carte",
    illustration: "/illustrations/origins.png",
    colors: ["#693a59", "#335f88"]
  },
  {
    id: "proving-grounds",
    title: "Proving Grounds",
    code: "PG",
    cardCountLabel: "34 carte",
    illustration: "/illustrations/proving-grounds.png",
    colors: ["#8d522a", "#345861"]
  },
  {
    id: "spiritforged",
    title: "SpiritForged",
    code: "SFD",
    cardCountLabel: "221 carte",
    illustration: "/illustrations/spiritforged.png",
    colors: ["#5b3d77", "#1e385f"]
  },
  {
    id: "unleashed",
    title: "Unleashed",
    code: "UNL",
    cardCountLabel: "215 carte",
    illustration: "/illustrations/unleashed.png",
    colors: ["#8e451d", "#293525"]
  },
  {
    id: "favorites",
    title: "Preferiti",
    code: "FAV",
    cardCountLabel: "27 carte",
    illustration: "/illustrations/favorite.png",
    colors: ["#6a5227", "#204f46"]
  }
];

export const communityProfiles: CommunityProfile[] = [
  {
    username: "@sbrakkius",
    decks: deckPreviews.filter((deck) => deck.owner === "@sbrakkius"),
    favorites: ["Miss Fortune", "Ahri", "Jinx", "Yasuo", "Vi", "Jhin"]
  },
  {
    username: "@davide",
    decks: deckPreviews.filter((deck) => deck.owner === "@davide" && deck.isPublic),
    favorites: ["Ahri", "Yasuo", "Jinx"]
  }
];
