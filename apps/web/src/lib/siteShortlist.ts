export interface ProposedSite {
  id: string
  latitude: number
  longitude: number
  name: string
  evidence: string
  installationCost: string
  shortlisted: boolean
}

export interface SiteComparison {
  nearestKm: number
  coverageGain: number
}

export const SITE_STORAGE_KEY = 'ropa-citi:proposed-sites:v1'
export type SitesByCity = Record<string, ProposedSite[]>

export function readSavedSites(): SitesByCity {
  try {
    const saved = localStorage.getItem(SITE_STORAGE_KEY)
    const parsed = saved ? JSON.parse(saved) : null
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {}
  } catch {
    return {}
  }
}

export function shortlistCsv(
  city: string,
  sites: ProposedSite[],
  compare: (site: ProposedSite) => SiteComparison,
): string {
  const headers = [
    'City', 'Site', 'Latitude', 'Longitude', 'Nearest sample charger (km)',
    'Additional sample points covered', 'Estimated installation cost (GBP)', 'Evidence and assumptions',
    'Coverage data',
  ]
  const rows = sites.filter(site => site.shortlisted).map(site => {
    const { nearestKm, coverageGain } = compare(site)
    return [
      city, site.name || 'Unnamed site', site.latitude.toFixed(6), site.longitude.toFixed(6),
      nearestKm.toFixed(2), coverageGain, site.installationCost, site.evidence,
      'Simulated station inventory and five sample points. Straight-line coverage radius: 2 km.',
    ]
  })
  return [headers, ...rows].map(row => row.map(csvCell).join(',')).join('\r\n') + '\r\n'
}

function csvCell(value: number | string): string {
  const content = String(value)
  // Treat free text as text when a spreadsheet opens the exported file.
  const safe = /^[\t\r\n]|^\s*[=+@-]/.test(content) && !/^-?\d+(\.\d+)?$/.test(content)
    ? "'" + content
    : content
  return '"' + safe.replaceAll('"', '""') + '"'
}
