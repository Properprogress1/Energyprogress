import { shortlistCsv, type ProposedSite, type SiteComparison } from '../lib/siteShortlist'

interface SiteShortlistProps {
  city: string
  sites: ProposedSite[]
  compare: (site: ProposedSite) => SiteComparison
  onUpdate: (update: (sites: ProposedSite[]) => ProposedSite[]) => void
  storageError: boolean
}

export function SiteShortlist({ city, sites, compare, onUpdate, storageError }: SiteShortlistProps) {
  const count = sites.filter(site => site.shortlisted).length

  function updateSite(id: string, changes: Partial<ProposedSite>) {
    onUpdate(current => current.map(site => site.id === id ? { ...site, ...changes } : site))
  }

  function exportShortlist() {
    const csv = shortlistCsv(city, sites, compare)
    const url = URL.createObjectURL(new Blob(['\uFEFF', csv], { type: 'text/csv;charset=utf-8' }))
    const link = document.createElement('a')
    link.href = url
    link.download = `ropa-citi-${city.toLowerCase()}-shortlist.csv`
    link.click()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  return (
    <div className="space-y-3">
      {storageError && <p role="alert" className="text-sm text-red-700">Browser storage is unavailable. Export before closing this page.</p>}
      {sites.length > 0 && (
        <>
          <ul className="space-y-3" aria-label="Proposed sites">
            {sites.map((site, index) => {
              const { nearestKm, coverageGain } = compare(site)
              return (
                <li key={site.id} className="space-y-2 rounded-md bg-violet-50 p-3 text-sm">
                  <div className="flex items-center justify-between gap-2">
                    <strong>Site {index + 1}</strong>
                    <button
                      onClick={() => onUpdate(current => current.filter(entry => entry.id !== site.id))}
                      aria-label={`Remove site ${index + 1}`}
                      className="text-violet-800 underline"
                    >
                      Remove
                    </button>
                  </div>
                  <p>{nearestKm.toFixed(2)} km from the nearest sample charger</p>
                  <p>{coverageGain} additional sample points within charger coverage</p>
                  <label className="block">
                    Site name
                    <input
                      value={site.name}
                      onChange={event => updateSite(site.id, { name: event.target.value })}
                      maxLength={100}
                      className="mt-1 w-full rounded border border-violet-300 bg-white px-2 py-1"
                      placeholder="e.g. Library car park"
                    />
                  </label>
                  <label className="block">
                    Estimated installation cost (£)
                    <input
                      type="number"
                      min="0"
                      step="0.01"
                      value={site.installationCost}
                      onChange={event => {
                        if (event.target.validity.valid) updateSite(site.id, { installationCost: event.target.value })
                      }}
                      className="mt-1 w-full rounded border border-violet-300 bg-white px-2 py-1"
                    />
                  </label>
                  <label className="block">
                    Local evidence and assumptions
                    <textarea
                      value={site.evidence}
                      onChange={event => updateSite(site.id, { evidence: event.target.value })}
                      maxLength={2000}
                      rows={3}
                      className="mt-1 w-full rounded border border-violet-300 bg-white px-2 py-1"
                      placeholder="Record demand, accessibility, and the sources for your estimates."
                    />
                  </label>
                  <label className="flex items-center gap-2 font-medium">
                    <input
                      type="checkbox"
                      checked={site.shortlisted}
                      onChange={event => updateSite(site.id, { shortlisted: event.target.checked })}
                    />
                    Include in shortlist
                  </label>
                </li>
              )
            })}
          </ul>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm" aria-live="polite">{count} of {sites.length} shortlisted</p>
            <button
              onClick={exportShortlist}
              disabled={count === 0}
              className="rounded-md bg-violet-700 px-3 py-2 text-sm font-semibold text-white disabled:opacity-50"
            >
              Export shortlist CSV
            </button>
          </div>
        </>
      )}
    </div>
  )
}
