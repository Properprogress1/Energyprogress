'use client'

import { useAccount, useConnect, useDisconnect } from 'wagmi'

export function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <div className="flex items-center gap-3">
        <div className="text-sm">
          <span className="text-gray-600">Connected:</span>{' '}
          <span className="font-mono font-semibold">{address?.slice(0, 6)}...{address?.slice(-4)}</span>
        </div>
        <button
          onClick={() => disconnect()}
          className="bg-red-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-red-700"
        >
          Disconnect
        </button>
      </div>
    )
  }

  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-gray-600">Wallet not connected</span>
      {connectors.map((connector) => (
        <button
          key={connector.id}
          onClick={() => connect({ connector })}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-blue-700"
        >
          Connect {connector.name}
        </button>
      ))}
    </div>
  )
}