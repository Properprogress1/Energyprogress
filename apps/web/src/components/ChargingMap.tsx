'use client'

import { useEffect, useRef, useState } from 'react'
import { MapContainer, TileLayer, Marker, Popup, CircleMarker, Tooltip, useMap, useMapEvents } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { LocalBlockchainDemo } from './LocalBlockchainDemo'
import { UrbanPlanningAnalysis } from './UrbanPlanningAnalysis'
import { SiteShortlist } from './SiteShortlist'
import { readSavedSites, SITE_STORAGE_KEY, type ProposedSite } from '../lib/siteShortlist'
import { calculateDistance, identifyCoverageGaps, COVERAGE_RADIUS_KM } from '../lib/coverage'

const stationIcon = L.icon({
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
})

export interface ChargingStation {
  id: number
  operator: string
  latitude: number
  longitude: number
  capacity: number
  pricePerKwh: number
  energySource: 'Solar' | 'Grid' | 'CommunitySolar' | 'BatteryStorage'
  available: boolean
  maxChargingRate: number
  active: boolean
}

export interface ChargingSession {
  id: number
  stationId: number
  user: string
  state: 'None' | 'Active' | 'Completed' | 'Settled'
  energyConsumed: number
  startTime: number
  endTime: number
  pricePerKwh: number
  totalCost: number
  paid: boolean
}

type Coordinates = [latitude: number, longitude: number]

const UK_CITIES: {
  name: string
  centre: Coordinates
  stationLocations: Coordinates[]
}[] = [
  {
    name: 'London',
    centre: [51.5074, -0.1278],
    stationLocations: [[51.5033, -0.1195], [51.5315, -0.1246], [51.5154, -0.1755], [51.5122, -0.0904], [51.4946, -0.1003]],
  },
  {
    name: 'Birmingham',
    centre: [52.4862, -1.8904],
    stationLocations: [[52.4778, -1.9058], [52.4812, -1.9088], [52.4892, -1.8766], [52.4915, -1.9232], [52.5107, -1.8872]],
  },
  {
    name: 'Manchester',
    centre: [53.4808, -2.2426],
    stationLocations: [[53.4774, -2.2309], [53.4816, -2.2555], [53.4677, -2.2347], [53.4901, -2.2381], [53.4717, -2.2919]],
  },
  {
    name: 'Cardiff',
    centre: [51.4816, -3.1791],
    stationLocations: [[51.4761, -3.1785], [51.4634, -3.1649], [51.4932, -3.1781], [51.4881, -3.2038], [51.4928, -3.1515]],
  },
  {
    name: 'Edinburgh',
    centre: [55.9533, -3.1883],
    stationLocations: [[55.9526, -3.1892], [55.9458, -3.2188], [55.9575, -3.1742], [55.9717, -3.1748], [55.9338, -3.1834]],
  },
  {
    name: 'Belfast',
    centre: [54.5973, -5.9301],
    stationLocations: [[54.5945, -5.9292], [54.6065, -5.9107], [54.5826, -5.9357], [54.6004, -5.9555], [54.6131, -5.9332]],
  },
]

const STATION_PROFILES: Pick<ChargingStation, 'capacity' | 'pricePerKwh' | 'energySource' | 'available' | 'maxChargingRate'>[] = [
  { capacity: 50, pricePerKwh: 0.20, energySource: 'Solar', available: true, maxChargingRate: 7 },
  { capacity: 100, pricePerKwh: 0.35, energySource: 'Grid', available: true, maxChargingRate: 22 },
  { capacity: 75, pricePerKwh: 0.28, energySource: 'CommunitySolar', available: false, maxChargingRate: 11 },
  { capacity: 60, pricePerKwh: 0.42, energySource: 'BatteryStorage', available: true, maxChargingRate: 15 },
  { capacity: 80, pricePerKwh: 0.25, energySource: 'Solar', available: true, maxChargingRate: 12 },
]

const cityNetworks = UK_CITIES.map((city, cityIndex) => ({
  ...city,
  stations: city.stationLocations.map(([latitude, longitude], stationIndex): ChargingStation => ({
    ...STATION_PROFILES[stationIndex],
    id: cityIndex * STATION_PROFILES.length + stationIndex + 1,
    operator: 'Demo operator',
    latitude,
    longitude,
    active: true,
  })),
}))

const CITY_ZOOM = 12
const formatPrice = new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'GBP' })

const ENERGY_SOURCE_COLORS: Record<string, string> = {
  Solar: '#10B981', // green
  Grid: '#3B82F6', // blue
  CommunitySolar: '#8B5CF6', // purple
  BatteryStorage: '#F59E0B', // amber
}

function MapUpdater({ centre, selectedStation }: {
  centre: Coordinates
  selectedStation: ChargingStation | null
}) {
  const map = useMap()

  useEffect(() => {
    if (selectedStation) {
      map.setView([selectedStation.latitude, selectedStation.longitude], 15)
    } else {
      map.setView(centre, CITY_ZOOM)
    }
  }, [centre, selectedStation, map])

  return null
}

function SitePicker({ onPick }: { onPick: (point: Coordinates) => void }) {
  useMapEvents({
    click: ({ latlng }) => onPick([latlng.lat, latlng.lng]),
  })
  return null
}

const MAX_PROPOSED_SITES = 3

export function ChargingMap() {
  const [cityIndex, setCityIndex] = useState(0)
  const { name, centre, stations } = cityNetworks[cityIndex]
  const [selectedStation, setSelectedStation] = useState<ChargingStation | null>(null)
  const [activeSession, setActiveSession] = useState<ChargingSession | null>(null)
  const [energyConsumed, setEnergyConsumed] = useState(0)
  const [sitesByCity, setSitesByCity] = useState(readSavedSites)
  const latestSites = useRef(sitesByCity)
  const [storageError, setStorageError] = useState(false)
  const proposedSites = sitesByCity[name] ?? []
  const [pickingSite, setPickingSite] = useState(false)
  const baselineGaps = identifyCoverageGaps(stations, centre).length

  function updateProposedSites(update: (sites: ProposedSite[]) => ProposedSite[]) {
    const current = latestSites.current
    const updated = { ...current, [name]: update(current[name] ?? []) }
    latestSites.current = updated
    setSitesByCity(updated)
    try {
      localStorage.setItem(SITE_STORAGE_KEY, JSON.stringify(updated))
      setStorageError(false)
    } catch {
      setStorageError(true)
    }
  }

  function addProposedSite([latitude, longitude]: Coordinates) {
    updateProposedSites(sites => {
      if (sites.length >= MAX_PROPOSED_SITES) return sites
      return [...sites, {
        id: crypto.randomUUID(),
        latitude,
        longitude,
        name: '',
        evidence: '',
        installationCost: '',
        shortlisted: false,
      }]
    })
    setPickingSite(false)
  }

  function compareSite(site: ProposedSite) {
    const nearestKm = Math.min(...stations.map(station =>
      calculateDistance(site.latitude, site.longitude, station.latitude, station.longitude),
    ))
    const remainingGaps = identifyCoverageGaps([...stations, site], centre).length
    return { nearestKm, coverageGain: baselineGaps - remainingGaps }
  }

  const handleStartSession = (station: ChargingStation) => {
    const newSession: ChargingSession = {
      id: Date.now(),
      stationId: station.id,
      user: '0xUserAddress',
      state: 'Active',
      energyConsumed: 0,
      startTime: Date.now(),
      endTime: 0,
      pricePerKwh: station.pricePerKwh,
      totalCost: 0,
      paid: false,
    }
    setActiveSession(newSession)
    setSelectedStation(station)
  }

  const handleCompleteSession = () => {
    if (activeSession) {
      const totalCost = energyConsumed * activeSession.pricePerKwh
      setActiveSession({
        ...activeSession,
        state: 'Completed',
        energyConsumed,
        endTime: Date.now(),
        totalCost,
      })
    }
  }

  const handlePaySession = () => {
    if (activeSession) {
      setActiveSession({
        ...activeSession,
        paid: true,
        state: 'Settled',
      })
    }
  }

  const simulateEnergyConsumption = () => {
    const increment = Math.random() * 5 + 1 // 1-6 kWh increment
    setEnergyConsumed(prev => prev + increment)
  }

  return (
    <div className="flex h-dvh flex-col text-gray-900 md:flex-row">
      {/* Main Map Area */}
      <div className="relative min-h-0 flex-1">
        <MapContainer
          center={centre}
          zoom={CITY_ZOOM}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <MapUpdater centre={centre} selectedStation={selectedStation} />
          {pickingSite && <SitePicker onPick={addProposedSite} />}
          {proposedSites.map(({ id, latitude, longitude, name: siteName }, index) => (
            <CircleMarker
              key={id}
              center={[latitude, longitude]}
              radius={8}
              bubblingMouseEvents={false}
              pathOptions={{ color: '#6d28d9', fillColor: '#a78bfa', fillOpacity: 1 }}
            >
              <Tooltip permanent direction="top">{siteName || `Site ${index + 1}`}</Tooltip>
            </CircleMarker>
          ))}
          {stations.map((station) => (
            <Marker
              key={station.id}
              icon={stationIcon}
              position={[station.latitude, station.longitude]}
              eventHandlers={{
                click: () => {
                  setPickingSite(false)
                  setSelectedStation(station)
                },
              }}
            >
              <Popup>
                <div className="p-2">
                  <h3 className="font-bold text-lg">Station #{station.id}</h3>
                  <p className="text-sm text-gray-600">
                    <strong>Operator:</strong> {station.operator}
                  </p>
                  <p className="text-sm text-gray-600">
                    <strong>Energy Source:</strong> {station.energySource}
                  </p>
                  <p className="text-sm text-gray-600">
                    <strong>Capacity:</strong> {station.capacity} kW
                  </p>
                  <p className="text-sm text-gray-600">
                    <strong>Price:</strong> {formatPrice.format(station.pricePerKwh)}/kWh
                  </p>
                  <p className="text-sm">
                    <strong>Status:</strong>{' '}
                    <span
                      className={`font-semibold ${
                        station.available ? 'text-green-600' : 'text-red-600'
                      }`}
                    >
                      {station.available ? 'Available' : 'Unavailable'}
                    </span>
                  </p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>

        {/* Dashboard Overlay */}
        <div className="absolute z-[1000] top-4 left-14 rounded-lg bg-white/95 p-3 shadow-lg md:p-4">
          <h2 className="mb-2 font-bold md:text-xl">{name} network</h2>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span>Total Stations:</span>
              <span className="font-semibold">{stations.length}</span>
            </div>
            <div className="flex justify-between">
              <span>Available:</span>
              <span className="font-semibold text-green-600">
                {stations.filter(s => s.available).length}
              </span>
            </div>
            <div className="flex justify-between">
              <span>Active Sessions:</span>
              <span className="font-semibold">{activeSession?.state === 'Active' ? 1 : 0}</span>
            </div>
            <div className="flex justify-between">
              <span>Energy Consumed:</span>
              <span className="font-semibold">{energyConsumed.toFixed(1)} kWh</span>
            </div>
          </div>
        </div>
      </div>

      {/* Side Panel */}
      <div className="h-1/2 overflow-y-auto border-t bg-white p-4 md:h-full md:w-96 md:border-l md:border-t-0 md:p-6">
        <div className="mb-4">
          <label htmlFor="uk-city" className="block font-semibold">UK city</label>
          <select
            id="uk-city"
            value={cityIndex}
            onChange={(event) => {
              setCityIndex(Number(event.target.value))
              setSelectedStation(null)
              setPickingSite(false)
            }}
            disabled={activeSession !== null}
            aria-describedby="uk-city-help"
            className="mt-1 w-full rounded-md border border-gray-400 bg-white px-3 py-2"
          >
            {cityNetworks.map((city, index) => (
              <option key={city.name} value={index}>{city.name}</option>
            ))}
          </select>
          <p id="uk-city-help" className="mt-1 text-sm text-gray-600">
            {activeSession ? 'Finish the session to change cities.' : 'Sample stations and prices for planning and charging simulations.'}
          </p>
        </div>
        <LocalBlockchainDemo />
        {selectedStation ? (
          <div>
            <div className="mb-4 flex items-center justify-between gap-2">
              <h2 className="text-xl font-bold">Station Details</h2>
              {!activeSession && (
                <button onClick={() => setSelectedStation(null)} className="text-sm text-blue-700 underline">
                  Planning overview
                </button>
              )}
            </div>
            <div className="space-y-3">
              <div>
                <label className="text-sm font-semibold text-gray-600">Station ID</label>
                <p className="text-lg">{selectedStation.id}</p>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Operator</label>
                <p className="text-lg font-mono">{selectedStation.operator}</p>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Location</label>
                <p className="text-lg">
                  {selectedStation.latitude.toFixed(4)}, {selectedStation.longitude.toFixed(4)}
                </p>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Energy Source</label>
                <div className="flex items-center gap-2">
                  <div
                    className="w-4 h-4 rounded"
                    style={{ backgroundColor: ENERGY_SOURCE_COLORS[selectedStation.energySource] }}
                  />
                  <p className="text-lg">{selectedStation.energySource}</p>
                </div>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Capacity</label>
                <p className="text-lg">{selectedStation.capacity} kW</p>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Max Charging Rate</label>
                <p className="text-lg">{selectedStation.maxChargingRate} kW</p>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Price</label>
                <p className="text-lg">{formatPrice.format(selectedStation.pricePerKwh)}/kWh</p>
              </div>
              <div>
                <label className="text-sm font-semibold text-gray-600">Status</label>
                <p
                  className={`text-lg font-semibold ${
                    selectedStation.available ? 'text-green-600' : 'text-red-600'
                  }`}
                >
                  {selectedStation.available ? 'Available' : 'Unavailable'}
                </p>
              </div>

              {/* Charging Controls */}
              {!activeSession ? (
                <button
                  onClick={() => handleStartSession(selectedStation)}
                  disabled={!selectedStation.available}
                  className="w-full mt-4 bg-blue-600 text-white py-3 px-4 rounded-lg font-semibold hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
                >
                  Start simulated session
                </button>
              ) : (
                <div className="mt-4 space-y-3">
                  <div className="bg-gray-100 p-4 rounded-lg">
                    <h3 className="font-semibold mb-2">Simulated session at station #{activeSession.stationId}</h3>
                    <div className="space-y-1 text-sm">
                      <p>Energy Consumed: {energyConsumed.toFixed(2)} kWh</p>
                      <p>Estimated Cost: {formatPrice.format(energyConsumed * activeSession.pricePerKwh)}</p>
                    </div>
                  </div>

                  {activeSession.state === 'Active' && (
                    <>
                      <button
                        onClick={simulateEnergyConsumption}
                        className="w-full bg-green-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-green-700"
                      >
                        Simulate Energy Consumption
                      </button>
                      <button
                        onClick={handleCompleteSession}
                        className="w-full bg-orange-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-orange-700"
                      >
                        Complete Session
                      </button>
                    </>
                  )}

                  {activeSession.state === 'Completed' && !activeSession.paid && (
                    <button
                      onClick={() => handlePaySession()}
                      className="w-full bg-purple-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-purple-700"
                    >
                      Simulate payment of {formatPrice.format(activeSession.totalCost)}
                    </button>
                  )}

                  {activeSession.paid && (
                    <div className="bg-green-100 p-4 rounded-lg text-center">
                      <p className="text-green-800 font-semibold">Simulated payment complete</p>
                      <button
                        onClick={() => {
                          setActiveSession(null)
                          setEnergyConsumed(0)
                        }}
                        className="mt-2 font-semibold underline"
                      >
                        Finish session
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            <div className="text-center text-gray-500">
              <p className="text-lg">Select a charging station from the map</p>
              <p className="text-sm mt-2">Click on any marker to view station details</p>
            </div>
            <section aria-labelledby="proposed-sites" className="space-y-3 rounded-lg border p-4">
              <h2 id="proposed-sites" className="font-bold">Compare proposed charger sites</h2>
              <p className="text-sm text-gray-600">
                Compare up to {MAX_PROPOSED_SITES} sites. Coverage uses {COVERAGE_RADIUS_KM} km straight-line distance
                from five sample points around the city centre.
              </p>
              <div className="flex flex-wrap gap-3">
                <button
                  onClick={() => setPickingSite(!pickingSite)}
                  disabled={proposedSites.length >= MAX_PROPOSED_SITES}
                  className="rounded-md bg-violet-700 px-3 py-2 text-sm font-semibold text-white disabled:opacity-50"
                >
                  {pickingSite ? 'Cancel' : 'Add a proposed site'}
                </button>
                {pickingSite && (
                  <button onClick={() => addProposedSite(centre)} className="text-sm text-violet-800 underline">
                    Use city centre
                  </button>
                )}
              </div>
              {pickingSite && <p role="status" className="text-sm">Click the map to place a proposed charger.</p>}
              <p className="text-sm">Baseline coverage: {5 - baselineGaps} of 5 sample points.</p>
              <p className="text-sm text-gray-600">Site details are saved in this browser. Export a shortlist to share it.</p>
              <SiteShortlist
                city={name}
                sites={proposedSites}
                compare={compareSite}
                onUpdate={updateProposedSites}
                storageError={storageError}
              />
            </section>
            <UrbanPlanningAnalysis stations={stations} centre={centre} />
          </div>
        )}
      </div>
    </div>
  )
}