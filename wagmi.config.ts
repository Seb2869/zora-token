import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";
import fs from "fs";
import path from "path";

// Define the type for addresses
interface AddressData {
  ZORA_TOKEN?: string;
  ZORA_TOKEN_COMMUNITY_CLAIM?: string;
  DEVELOPMENT_COMMUNITY_CLAIM?: string;
  [key: string]: string | undefined;
}

// Read all address files from the addresses directory
const addressesDir = path.join(__dirname, "addresses");
const addressFiles = fs
  .readdirSync(addressesDir)
  .filter((file) => file.endsWith(".json"));

// Create a mapping of chainIds to addresses
const chainAddresses: Record<number, AddressData> = {};

// Process each address file
addressFiles.forEach((file) => {
  // Extract chainId from filename (e.g., "8453.json" -> 8453)
  const chainId = parseInt(path.basename(file, ".json"));

  // Skip if not a valid number
  if (isNaN(chainId)) return;

  // Read and parse the addresses file
  const filePath = path.join(addressesDir, file);
  const addresses = JSON.parse(
    fs.readFileSync(filePath, "utf8"),
  ) as AddressData;

  // Store addresses for this chain
  chainAddresses[chainId] = addresses;
});

// Create deployments configuration
const deployments = {
  ZoraTokenCommunityClaim: {},
  Zora: {},
  DevelopmentCommunityClaim: {},
};

// Populate deployments with addresses from all chains
Object.entries(chainAddresses).forEach(([chainId, addresses]) => {
  const numericChainId = parseInt(chainId);

  if (addresses.ZORA_TOKEN_COMMUNITY_CLAIM) {
    deployments.ZoraTokenCommunityClaim[numericChainId] =
      addresses.ZORA_TOKEN_COMMUNITY_CLAIM;
  }

  if (addresses.ZORA_TOKEN) {
    deployments.Zora[numericChainId] = addresses.ZORA_TOKEN;
  }

  if (addresses.DEVELOPMENT_COMMUNITY_CLAIM) {
    deployments.DevelopmentCommunityClaim[numericChainId] =
      addresses.DEVELOPMENT_COMMUNITY_CLAIM;
  }
});

export default defineConfig({
  out: "package/generated.ts",
  contracts: [],
  plugins: [
    foundry({
      include: ["Zora*", "DevelopmentCommunityClaim*"],
      deployments: deployments,
    }),
  ],
});
