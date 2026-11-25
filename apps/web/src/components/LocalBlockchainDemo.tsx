'use client'

import { useState } from 'react'
import { formatUnits } from 'viem'
import { useChargingContract } from '../hooks/useChargingContract'
import { WalletConnect } from './WalletConnect'

export function LocalBlockchainDemo() {
  const { address, account, session, sessions, advance } = useChargingContract()
  const [pending, setPending] = useState(false)
  const [error, setError] = useState('')
  const settled = session?.state === 3
  let action = 'Start on-chain session'
  if (session?.state === 1) {
    action = session.energyConsumed === BigInt(0) ? 'Record 5 simulated kWh' : 'Complete on-chain session'
  } else if (session?.state === 2) {
    action = session.paid ? 'Settle on-chain session' : `Pay ${formatUnits(session.totalCost, 18)} RET`
  } else if (settled) {
    action = 'Start another on-chain session'
  }

  async function handleAdvance() {
    setPending(true)
    setError('')
    try {
      await advance()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message.split('\n')[0] : 'Transaction failed.')
    } finally {
      setPending(false)
    }
  }

  return (
    <details className="mb-6 rounded-lg border p-3 text-sm">
      <summary className="cursor-pointer font-semibold">Local blockchain demo</summary>
      <p className="my-2">Sample station #1 on Anvil. Payments use RET test tokens.</p>
      <WalletConnect />
      {address && !account && <p className="mt-2">Switch your wallet to Anvil (chain 31337).</p>}
      {account && (
        <div className="mt-3 space-y-2">
          {session && (
            <p>
              Session #{session.id.toString()} · {formatUnits(session.energyConsumed, 18)} kWh
              {settled && ' · Settled on the local blockchain'}
            </p>
          )}
          {sessions.isError ? (
            <>
              <p role="alert">Could not read the charging contract. Check that Anvil is running and the contract is deployed.</p>
              <button onClick={() => void sessions.refetch()} className="underline">Retry connection</button>
            </>
          ) : (
            <button
              onClick={handleAdvance}
              disabled={pending || !sessions.isSuccess}
              className="rounded-lg bg-blue-600 px-3 py-2 font-semibold text-white disabled:opacity-50"
            >
              {pending ? 'Waiting for wallet and confirmation…' : action}
            </button>
          )}
          {error && <p role="alert" className="break-words text-red-700">{error}</p>}
        </div>
      )}
    </details>
  )
}
