export type DomainName = "Body" | "Calm" | "Chaos" | "Fury" | "Mind" | "Order";

export type DeckPreview = {
  id: string;
  name: string;
  owner: string;
  isPublic: boolean;
  priceLabel: string;
  setCodes: string[];
  domains: DomainName[];
  legendImage: string;
  views: number;
  likes: number;
};

export type BinderPreview = {
  id: string;
  title: string;
  code: string;
  cardCountLabel: string;
  illustration: string;
  colors: [string, string];
};

export type CommunityProfile = {
  username: string;
  decks: DeckPreview[];
  favorites: string[];
};
