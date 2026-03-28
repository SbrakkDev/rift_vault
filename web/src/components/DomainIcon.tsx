import type { DomainName } from "../types";

const assetByDomain: Record<DomainName, string> = {
  Body: "/domains/body.webp",
  Calm: "/domains/calm.webp",
  Chaos: "/domains/chaos.webp",
  Fury: "/domains/fury.webp",
  Mind: "/domains/mind.webp",
  Order: "/domains/order.webp"
};

const colorByDomain: Record<DomainName, string> = {
  Body: "#F28705",
  Calm: "#18B870",
  Chaos: "#7D42D9",
  Fury: "#CF2437",
  Mind: "#2682C8",
  Order: "#D5A800"
};

type DomainIconProps = {
  domain: DomainName;
  size?: number;
};

export function DomainIcon({ domain, size = 30 }: DomainIconProps) {
  return (
    <span
      className="domain-icon"
      style={{
        width: size,
        height: size,
        backgroundColor: colorByDomain[domain]
      }}
    >
      <img src={assetByDomain[domain]} alt={domain} />
    </span>
  );
}

export function domainGradient(domains: DomainName[]) {
  const colors = domains.map((domain) => colorByDomain[domain]);
  if (colors.length === 0) {
    return ["#2a3558", "#131A31"];
  }

  if (colors.length === 1) {
    return [colors[0], "#131A31"];
  }

  return [colors[0], colors[1]];
}
