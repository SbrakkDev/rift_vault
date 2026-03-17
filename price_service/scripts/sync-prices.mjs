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
const JUSTTCG_BATCH_LIMIT = 20;
const JUSTTCG_DELAY_MS = 7000;

const config = {
  riftCodexBaseURL: process.env.RIFTCODEX_API_BASE_URL || "https://api.riftcodex.com",
  justTCGBaseURL: process.env.JUSTTCG_API_BASE_URL || "https://api.justtcg.com/v1",
  frankfurterBaseURL: process.env.FRANKFURTER_API_BASE_URL || "https://api.frankfurter.dev/v1",
  justTCGAPIKey: process.env.JUSTTCG_API_KEY || "",
};

if (!config.justTCGAPIKey) {
  console.error("Missing JUSTTCG_API_KEY. Export the key before running the sync.");
  process.exit(1);
}

main().catch((error) => {
  console.error("");
  console.error("Price sync failed.");
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

async function main() {
  console.log("Starting Rift Vault daily sync...");

  const startedAt = new Date().toISOString();
  const catalog = await fetchCatalog();
  console.log(`Catalog loaded: ${catalog.length} cards.`);

  const usdToEUR = await fetchUSDtoEURRate();
  console.log(`USD -> EUR rate: ${usdToEUR}`);

  const quotesByTCGPlayerID = await fetchQuotesByTCGPlayerID(catalog, usdToEUR);
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
  const setID = String(item?.set?.set_id ?? "").trim();
  const setName = String(item?.set?.label ?? "Unknown Set").trim();
  const publicCode = String(item?.public_code ?? "").trim();
  const collectorNumber = String(item?.collector_number ?? "").trim();
  const type = String(item?.classification?.type ?? "").trim();
  const domains = Array.isArray(item?.classification?.domain)
    ? item.classification.domain.map((value) => String(value).trim()).filter(Boolean)
    : [];

  return {
    id: String(item?.id ?? "").trim(),
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

async function fetchUSDtoEURRate() {
  const url = `${config.frankfurterBaseURL}/latest?base=USD&symbols=EUR`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Frankfurter exchange rate request failed with HTTP ${response.status}.`);
  }

  const payload = await response.json();
  const rate = payload?.rates?.EUR;
  if (typeof rate !== "number" || Number.isNaN(rate)) {
    throw new Error("Frankfurter did not return a valid EUR exchange rate.");
  }

  return rate;
}

async function fetchQuotesByTCGPlayerID(cards, usdToEUR) {
  const eligibleCards = cards.filter((card) => card.tcgplayerId);
  const chunks = chunk(eligibleCards, JUSTTCG_BATCH_LIMIT);
  const quotes = new Map();

  for (let index = 0; index < chunks.length; index += 1) {
    const currentChunk = chunks[index];
    const batchQuotes = await fetchJustTCGBatch(currentChunk, usdToEUR);

    for (const [tcgplayerId, quote] of batchQuotes.entries()) {
      quotes.set(tcgplayerId, quote);
    }

    if (index < chunks.length - 1) {
      await sleep(JUSTTCG_DELAY_MS);
    }
  }

  return quotes;
}

async function fetchJustTCGBatch(cards, usdToEUR) {
  const response = await fetch(`${config.justTCGBaseURL}/cards`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": config.justTCGAPIKey,
    },
    body: JSON.stringify(
      cards
        .filter((card) => card.tcgplayerId)
        .map((card) => ({
          tcgplayerId: card.tcgplayerId,
          condition: "NM",
          printing: "Normal",
        }))
    ),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`JustTCG batch failed with HTTP ${response.status}: ${body}`);
  }

  const payload = await response.json();
  const results = Array.isArray(payload?.data) ? payload.data : [];
  const quotes = new Map();

  for (const result of results) {
    const tcgplayerId = valueOrNull(result?.tcgplayerId);
    if (!tcgplayerId) {
      continue;
    }

    const variants = Array.isArray(result?.variants) ? result.variants : [];
    const variant = selectVariant(variants);
    if (!variant || typeof variant.price !== "number") {
      continue;
    }

    const priceEUR = roundMoney(variant.price * usdToEUR);
    const deltaEUR = typeof variant.priceChange24hr === "number"
      ? roundMoney(variant.priceChange24hr * usdToEUR)
      : null;

    quotes.set(tcgplayerId, {
      provider: "JustTCG",
      currency: "EUR",
      amount: priceEUR,
      originalCurrency: "USD",
      originalAmount: roundMoney(variant.price),
      delta24h: deltaEUR,
      sourceUpdatedAt: typeof variant.lastUpdated === "number"
        ? new Date(variant.lastUpdated * 1000).toISOString()
        : null,
      syncedAt: new Date().toISOString(),
    });
  }

  return quotes;
}

function selectVariant(variants) {
  const pricedVariants = variants.filter((variant) => typeof variant?.price === "number" && variant.price > 0);
  if (pricedVariants.length === 0) {
    return null;
  }

  return (
    pricedVariants.find((variant) => isNearMint(variant) && isNormalPrinting(variant)) ||
    pricedVariants.find((variant) => isNearMint(variant)) ||
    pricedVariants.find((variant) => isNormalPrinting(variant)) ||
    pricedVariants[0]
  );
}

function isNearMint(variant) {
  return String(variant?.condition ?? "").toLowerCase().includes("near mint");
}

function isNormalPrinting(variant) {
  return String(variant?.printing ?? "").toLowerCase().includes("normal");
}

function buildMeta(cards, startedAt, generatedAt) {
  const pricedCards = cards.filter((card) => card.price !== null).length;
  const setNames = new Set(cards.map((card) => card.set.name));

  return {
    service: "Rift Vault Price Service",
    generatedAt,
    syncStartedAt: startedAt,
    currency: "EUR",
    provider: "JustTCG",
    sources: {
      catalog: "RiftCodex",
      prices: "JustTCG",
      fx: "Frankfurter",
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

function chunk(items, size) {
  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
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
