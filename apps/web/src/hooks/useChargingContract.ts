'use client'

import { erc20Abi, parseAbi, parseUnits } from 'viem'
import { useAccount, usePublicClient, useReadContract, useWriteContract } from 'wagmi'

const abi = parseAbi([
  'struct Station { uint256 id; address operator; int256 latitude; int256 longitude; uint256 capacity; uint256 pricePerKwh; uint8 energySource; bool available; uint256 maxChargingRate; address paymentToken; bool active; }',
  'struct Session { uint256 id; uint256 stationId; address user; uint8 state; uint256 energyConsumed; uint256 startTime; uint256 endTime; uint256 totalCost; bool paid; }',
  'function getStation(uint256 stationId) view returns (Station)',
  'function getUserSessions(address user) view returns (Session[])',
  'function startSession(uint256 stationId) returns (uint256)',
  'function recordEnergyConsumption(uint256 sessionId, uint256 energy)',
  'function completeSession(uint256 sessionId)',
  'function paySession(uint256 sessionId)',
  'function settleSession(uint256 sessionId)',
])

const chainId = 31337
const network = (process.env.NEXT_PUBLIC_CHARGING_NETWORK_ADDRESS ??
  '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512') as `0x${string}`
const stationId = BigInt(1)

export function useChargingContract() {
  const { address, chainId: walletChainId } = useAccount()
  const account = walletChainId === chainId ? address : undefined
  const client = usePublicClient({ chainId })
  const { mutateAsync: write } = useWriteContract()
  const contract = { address: network, abi, chainId } as const
  const sessions = useReadContract({
    ...contract,
    functionName: 'getUserSessions',
    args: account ? [account] : undefined,
    query: { enabled: Boolean(account) },
  })
  const session = sessions.data?.findLast((item) => item.stationId === stationId)

  async function advance() {
    if (!account || !client) throw new Error('Connect a wallet on the local Anvil network.')

    const confirm = async (hash: `0x${string}`) => {
      const receipt = await client.waitForTransactionReceipt({ hash })
      if (receipt.status !== 'success') throw new Error('The transaction reverted.')
    }

    // Read current state before submitting so a partial payment can be retried.
    const latest = await client.readContract({
      ...contract,
      functionName: 'getUserSessions',
      args: [account],
    })
    const current = latest.findLast((item) => item.stationId === stationId)
    if (
      current?.id !== session?.id ||
      current?.state !== session?.state ||
      current?.energyConsumed !== session?.energyConsumed ||
      current?.paid !== session?.paid
    ) {
      await sessions.refetch({ throwOnError: true })
      throw new Error('The session changed. Check its current status and try again.')
    }
    const transaction = { ...contract, account }

    if (!current || current.state === 3) {
      await confirm(await write({ ...transaction, functionName: 'startSession', args: [stationId] }))
    } else if (current.state === 1 && current.energyConsumed === BigInt(0)) {
      await confirm(await write({
        ...transaction,
        functionName: 'recordEnergyConsumption',
        args: [current.id, parseUnits('5', 18)],
      }))
    } else if (current.state === 1) {
      await confirm(await write({ ...transaction, functionName: 'completeSession', args: [current.id] }))
    } else if (!current.paid) {
      const station = await client.readContract({
        ...contract,
        functionName: 'getStation',
        args: [stationId],
      })
      const token = { address: station.paymentToken, abi: erc20Abi } as const
      const allowance = await client.readContract({
        ...token,
        functionName: 'allowance',
        args: [account, network],
      })
      if (allowance < current.totalCost) {
        await confirm(await write({
          ...token,
          chainId,
          account,
          functionName: 'approve',
          args: [network, current.totalCost],
        }))
      }
      await confirm(await write({ ...transaction, functionName: 'paySession', args: [current.id] }))
    } else {
      await confirm(await write({ ...transaction, functionName: 'settleSession', args: [current.id] }))
    }

    await sessions.refetch({ throwOnError: true })
  }

  return { address, account, session, sessions, advance }
}
