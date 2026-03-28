import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const publicRoot = path.join(projectRoot, "public");
const apiRoot = path.join(publicRoot, "api");
const cardsRoot = path.join(apiRoot, "cards");
const setsRoot = path.join(apiRoot, "sets");

const PAGE_SIZE = 50;
const CARDTRADER_DELAY_MS = 1200;

const config = {
  riftCodexBaseURL: process.env.RIFTCODEX_API_BASE_URL || "https://api.riftcodex.com",
  cardTraderBaseURL: process.env.CARDTRADER_API_BASE_URL || "https://api.cardtrader.com/api/v2",
  cardTraderBearerToken: process.env.CARDTRADER_BEARER_TOKEN || "",
};

if (!config.cardTraderBearerToken) {
  console.error("Missing CARDTRADER_BEARER_TOKEN. Export the token before running the sync.");
  process.exit(1);
}

main().catch((error) => {
  console.error("");
  console.error("Price sync failed.");
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

async function main() {
  console.log("Starting RuneShelf daily sync...");

  const startedAt = new Date().toISOString();
  const catalog = await fetchCatalog();
  console.log(`Catalog loaded: ${catalog.length} cards.`);

  const quotesByTCGPlayerID = await fetchCardTraderQuotesByTCGPlayerID(catalog);
  console.log(`Quotes loaded: ${quotesByTCGPlayerID.size} priced cards.`);

  const cards = catalog.map((card) => {
    const quote = card.tcgplayerId ? quotesByTCGPlayerID.get(card.tcgplayerId) ?? null : null;
    return {
      ...card,
      price: quote,
    };
  });

  const generatedAt = new Date().toISOString();
  const meta = buildMeta(cards, startedAt, generatedAt);

  await ensureDirectories();
  await writeJSON(path.join(apiRoot, "meta.json"), meta);
  await writeJSON(path.join(apiRoot, "catalog.json"), { meta, cards });
  await writeJSON(path.join(apiRoot, "prices.json"), buildPriceIndex(meta, cards));

  for (const card of cards) {
    await writeJSON(path.join(cardsRoot, `${card.id}.json`), card);
  }

  for (const setPayload of buildSetPayloads(meta, cards)) {
    await writeJSON(path.join(setsRoot, `${setPayload.slug}.json`), setPayload);
  }

  console.log("Static API generated successfully.");
  console.log(`Output: ${apiRoot}`);
}

async function fetchCatalog() {
  const cards = [];
  let page = 1;

  while (true) {
    const url = new URL(`${config.riftCodexBaseURL}/cards`);
    url.searchParams.set("page", String(page));
    url.searchParams.set("size", String(PAGE_SIZE));

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`RiftCodex catalog request failed with HTTP ${response.status}.`);
    }

    const payload = await response.json();
    const items = Array.isArray(payload.items) ? payload.items : [];
    if (items.length === 0) {
      break;
    }

    for (const item of items) {
      cards.push(normalizeRiftCodexCard(item));
    }

    if (items.length < PAGE_SIZE) {
      break;
    }
    page += 1;
  }

  return cards.sort(compareCards);
}

function normalizeRiftCodexCard(item) {
  const cardID = valueOrNull(item?.riftbound_id) ?? valueOrNull(item?.id) ?? "";
  const setID = String(item?.set?.set_id ?? "").trim();
  const setName = String(item?.set?.label ?? "Unknown Set").trim();
  const publicCode = String(item?.public_code ?? "").trim();
  const collectorNumber = String(item?.collector_number ?? "").trim();
  const type = String(item?.classification?.type ?? "").trim();
  const domains = Array.isArray(item?.classification?.domain)
    ? item.classification.domain.map((value) => String(value).trim()).filter(Boolean)
    : [];

  return {
    id: cardID,
    sourceID: valueOrNull(item?.id),
    riftboundID: valueOrNull(item?.riftbound_id),
    name: String(item?.name ?? "Unknown Card").trim(),
    publicCode,
    collectorNumber,
    tcgplayerId: valueOrNull(item?.tcgplayer_id),
    set: {
      id: setID,
      name: setName,
      slug: slugify(setName),
    },
    category: mapCategory(type),
    rawType: type || "Unit",
    rarity: String(item?.classification?.rarity ?? "").trim() || null,
    cost: numberOrNull(item?.attributes?.energy),
    domains,
    text: valueOrNull(item?.text?.plain),
    imageUrl: valueOrNull(item?.media?.image_url),
    artist: valueOrNull(item?.media?.artist),
    updatedAt: new Date().toISOString(),
  };
}

function mapCategory(rawType) {
  const normalized = rawType.toLowerCase();
  if (normalized.includes("legend")) return "Legend";
  if (normalized.includes("champion")) return "Champion";
  if (normalized.includes("battlefield")) return "Battlefield";
  if (normalized.includes("rune")) return "Rune";
  if (normalized.includes("gear")) return "Gear";
  if (normalized.includes("spell")) return "Spell";
  return "Unit";
}

function compareCards(lhs, rhs) {
  if (lhs.set.name !== rhs.set.name) {
    return lhs.set.name.localeCompare(rhs.set.name);
  }

  const leftNumber = Number.parseInt(lhs.collectorNumber, 10);
  const rightNumber = Number.parseInt(rhs.collectorNumber, 10);
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber) && leftNumber !== rightNumber) {
    return leftNumber - rightNumber;
  }

  return lhs.name.localeCompare(rhs.name);
}

async function fetchCardTraderQuotesByTCGPlayerID(cards) {
  const eligibleTCGPlayerIDs = new Set(
    cards.map((card) => card.tcgplayerId).filter(Boolean)
  );

  const game = await fetchCardTraderGame();
  console.log(`CardTrader game: ${game.name} (#${game.id}).`);

  const expansions = await fetchCardTraderExpansions(game.id);
  console.log(`CardTrader expansions loaded: ${expansions.length}.`);

  const quotes = new Map();

  for (const expansion of expansions) {
    const blueprints = await fetchBlueprintsForExpansion(expansion.id);
    const tcgplayerToBlueprint = new Map();

    for (const blueprint of blueprints) {
      const tcgplayerId = valueOrNull(blueprint?.tcg_player_id);
      const blueprintID = numberOrNull(blueprint?.id);
      if (!tcgplayerId || blueprintID === null) {
        continue;
      }
      if (!eligibleTCGPlayerIDs.has(tcgplayerId)) {
        continue;
      }
      tcgplayerToBlueprint.set(String(blueprintID), tcgplayerId);
    }

    if (tcgplayerToBlueprint.size === 0) {
      continue;
    }

    const productsByBlueprint = await fetchMarketplaceProductsForExpansion(expansion.id);
    let pricedInExpansion = 0;

    for (const [blueprintID, tcgplayerId] of tcgplayerToBlueprint.entries()) {
      const products = Array.isArray(productsByBlueprint[blueprintID]) ? productsByBlueprint[blueprintID] : [];
      const selected = selectCardTraderProduct(products);
      if (!selected) {
        continue;
      }

      quotes.set(tcgplayerId, buildCardTraderQuote(selected));
      pricedInExpansion += 1;
    }

    console.log(`CardTrader priced ${pricedInExpansion} cards for expansion ${expansion.name}.`);
    await sleep(CARDTRADER_DELAY_MS);
  }

  return quotes;
}

async function fetchCardTraderGame() {
  const games = await cardTraderGET("/games");
  const list = unwrapCardTraderArray(games);
  const game = list.find((entry) => {
    const haystack = [
      entry?.name,
      entry?.display_name,
    ].map(normalizeComparableText).join(" ");
    return haystack.includes("riftbound");
  });

  if (!game?.id) {
    throw new Error("CardTrader game lookup failed: Riftbound was not found.");
  }

  return {
    id: Number(game.id),
    name: String(game.name),
  };
}

async function fetchCardTraderExpansions(gameID) {
  const expansions = await cardTraderGET("/expansions");
  const list = unwrapCardTraderArray(expansions);

  return list
    .filter((entry) => Number(entry?.game_id) === Number(gameID))
    .map((entry) => ({
      id: Number(entry.id),
      name: String(entry.name ?? "Unknown Expansion"),
    }))
    .sort((lhs, rhs) => lhs.name.localeCompare(rhs.name));
}

async function fetchBlueprintsForExpansion(expansionID) {
  const payload = await cardTraderGET(`/blueprints/export?expansion_id=${encodeURIComponent(expansionID)}`);
  return unwrapCardTraderArray(payload);
}

async function fetchMarketplaceProductsForExpansion(expansionID) {
  return cardTraderGET(`/marketplace/products?expansion_id=${encodeURIComponent(expansionID)}&language=en`);
}

async function cardTraderGET(pathname) {
  const url = pathname.startsWith("http") ? pathname : `${config.cardTraderBaseURL}${pathname}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${config.cardTraderBearerToken}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`CardTrader request failed with HTTP ${response.status}: ${body}`);
  }

  return response.json();
}

function selectCardTraderProduct(products) {
  const candidates = products
    .filter((product) => isAvailableCardTraderProduct(product))
    .map((product) => ({
      product,
      priceCents: extractCardTraderPriceCents(product),
      conditionRank: cardTraderConditionRank(product),
    }))
    .filter((entry) => Number.isFinite(entry.priceCents) && entry.priceCents > 0);

  if (candidates.length === 0) {
    return null;
  }

  candidates.sort((lhs, rhs) => {
    if (lhs.conditionRank !== rhs.conditionRank) {
      return lhs.conditionRank - rhs.conditionRank;
    }
    return lhs.priceCents - rhs.priceCents;
  });

  return candidates[0].product;
}

function isAvailableCardTraderProduct(product) {
  const quantity = Number(product?.quantity ?? 0);
  const graded = Boolean(product?.graded);
  const onVacation = Boolean(product?.seller?.vacation_mode ?? product?.seller?.on_vacation ?? false);

  return quantity > 0 && !graded && !onVacation;
}

function extractCardTraderPriceCents(product) {
  const directPrice = numberOrNull(product?.price_cents);
  if (directPrice !== null) {
    return directPrice;
  }

  const nestedPrice = numberOrNull(product?.price?.cents);
  if (nestedPrice !== null) {
    return nestedPrice;
  }

  const amount = numberOrNull(product?.price?.amount);
  if (amount !== null) {
    return Math.round(amount * 100);
  }

  return null;
}

function cardTraderConditionRank(product) {
  const raw = normalizeComparableText(
    product?.properties_hash?.condition ||
    product?.condition ||
    product?.bundle?.properties_hash?.condition
  );

  if (raw.includes("near mint")) return 0;
  if (raw.includes("excellent")) return 1;
  if (raw.includes("good")) return 2;
  if (raw.includes("light played")) return 3;
  if (raw.includes("played")) return 4;
  if (raw.includes("poor")) return 5;
  return 9;
}

function buildCardTraderQuote(product) {
  const priceCents = extractCardTraderPriceCents(product);
  const amount = roundMoney(priceCents / 100);
  const currency = String(
    product?.price_currency ||
    product?.price?.currency ||
    "EUR"
  ).toUpperCase();
  const updatedAt = valueOrNull(product?.updated_at) ?? new Date().toISOString();

  return {
    provider: "CardTrader",
    currency,
    amount,
    delta24h: null,
    sourceUpdatedAt: updatedAt,
    syncedAt: new Date().toISOString(),
  };
}

function buildMeta(cards, startedAt, generatedAt) {
  const pricedCards = cards.filter((card) => card.price !== null).length;
  const setNames = new Set(cards.map((card) => card.set.name));

  return {
    service: "RuneShelf Price Service",
    generatedAt,
    syncStartedAt: startedAt,
    currency: "EUR",
    provider: "CardTrader",
    sources: {
      catalog: "RiftCodex",
      prices: "CardTrader",
    },
    counts: {
      cards: cards.length,
      pricedCards,
      unpricedCards: cards.length - pricedCards,
      sets: setNames.size,
    },
  };
}

function buildPriceIndex(meta, cards) {
  const prices = {};

  for (const card of cards) {
    prices[card.id] = card.price;
  }

  return {
    meta,
    prices,
  };
}

function buildSetPayloads(meta, cards) {
  const grouped = new Map();

  for (const card of cards) {
    const key = card.set.slug;
    const current = grouped.get(key) ?? {
      set: card.set,
      cards: [],
    };
    current.cards.push(card);
    grouped.set(key, current);
  }

  return Array.from(grouped.values())
    .map((entry) => ({
      slug: entry.set.slug,
      set: entry.set,
      meta: {
        generatedAt: meta.generatedAt,
        currency: meta.currency,
        provider: meta.provider,
        cardCount: entry.cards.length,
        pricedCards: entry.cards.filter((card) => card.price !== null).length,
      },
      cards: entry.cards,
    }))
    .sort((lhs, rhs) => lhs.set.name.localeCompare(rhs.set.name));
}

async function ensureDirectories() {
  await mkdir(cardsRoot, { recursive: true });
  await mkdir(setsRoot, { recursive: true });
}

async function writeJSON(filePath, payload) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function slugify(value) {
  return String(value)
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function roundMoney(value) {
  return Math.round(value * 100) / 100;
}

function valueOrNull(value) {
  if (value === null || value === undefined) {
    return null;
  }
  const normalized = String(value).trim();
  return normalized.length > 0 ? normalized : null;
}

function numberOrNull(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return null;
  }
  return value;
}

function normalizeComparableText(value) {
  return String(value ?? "")
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

function unwrapCardTraderArray(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }

  if (Array.isArray(payload?.array)) {
    return payload.array;
  }

  return [];
}
