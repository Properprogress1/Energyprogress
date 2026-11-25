import { http, createConfig } from 'wagmi'
import { injected } from 'wagmi/connectors'

// Local Anvil chain configuration
const localhost = {
  id: 31337,
  name: 'Localhost',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
  },
} as const

export const config = createConfig({
  chains: [localhost],
  connectors: [
    injected(),
  ],
  ssr: true,
  transports: {
    [localhost.id]: http(),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}