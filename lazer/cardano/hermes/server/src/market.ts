import type { Market } from "./types.js";

export const MARKET_DURATION_MS = 5 * 60 * 1000; // 5 minutes

// TODO: When reading the current market from the blockchain, replace
// createMarket() calls in index.ts with a fetch from the contract:
//
//   import { ethers } from "ethers"
//
//   const CONTRACT_ADDRESS = "0x..." // TODO: deployed market factory address
//   const ABI = [...]                // TODO: contract ABI
//   const provider = new ethers.WebSocketProvider("wss://your-rpc-url")
//   const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider)
//
//   async function fetchCurrentMarket(): Promise<Market> {
//     const marketId   = await contract.currentMarketId()
//     const marketData = await contract.markets(marketId)
//     return {
//       id:          marketId.toString(),
//       startTime:   Number(marketData.startTime) * 1000,  // contract: unix seconds
//       endTime:     Number(marketData.endTime) * 1000,
//       strikePrice: Number(marketData.strikePrice) / 1e18,
//     }
//   }
//
// TODO: When creating a new market on-chain, replace createMarket() with:
//
//   async function createOnChainMarket(strikePrice: number): Promise<Market> {
//     const strikePriceWei = ethers.parseEther(strikePrice.toString())
//     const tx = await contract.createMarket(strikePriceWei)
//     await tx.wait()
//     return fetchCurrentMarket()
//   }

export function createMarket(strikePrice: number): Market {
  const now = Date.now();
  return {
    id: crypto.randomUUID(),
    startTime: now,
    endTime: now + MARKET_DURATION_MS,
    strikePrice,
  };
}
