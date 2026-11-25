'use client'

import type { ChargingStation } from './ChargingMap'
import { calculateDistance, identifyCoverageGaps } from '../lib/coverage'

export interface UrbanPlanningMetrics {
  chargingAccessibility: number // 0-100 score
  averageStationDistance: number // in km
  renewableEnergyPercentage: number // percentage
  coverageGaps: number[] // areas with insufficient coverage
  infrastructureDensity: number // stations per square km
  estimatedDemandCoverage: number // percentage of demand met
}

export function UrbanPlanningAnalysis({ stations, centre }: {
  stations: ChargingStation[]
  centre: readonly [number, number]
}) {
  const metrics = calculateUrbanPlanningMetrics(stations, centre)

  return (
    <div className="bg-white p-4 rounded-lg shadow-lg">
      <h3 className="text-lg font-bold mb-3">Urban Planning Intelligence</h3>
      
      <div className="space-y-4">
        {/* Overall Score */}
        <div className="bg-gradient-to-r from-blue-50 to-green-50 p-3 rounded-lg">
          <div className="flex justify-between items-center mb-2">
            <span className="font-semibold">Overall Infrastructure Score</span>
            <span className="text-2xl font-bold text-green-600">
              {metrics.chargingAccessibility.toFixed(0)}%
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-green-600 h-2 rounded-full transition-all"
              style={{ width: `${metrics.chargingAccessibility}%` }}
            />
          </div>
        </div>

        {/* Key Metrics */}
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-blue-50 p-3 rounded-lg">
            <div className="text-sm text-gray-600">Avg Station Distance</div>
            <div className="text-lg font-semibold">{metrics.averageStationDistance.toFixed(2)} km</div>
          </div>
          <div className="bg-green-50 p-3 rounded-lg">
            <div className="text-sm text-gray-600">Renewable Energy</div>
            <div className="text-lg font-semibold">{metrics.renewableEnergyPercentage.toFixed(0)}%</div>
          </div>
          <div className="bg-purple-50 p-3 rounded-lg">
            <div className="text-sm text-gray-600">Infrastructure Density</div>
            <div className="text-lg font-semibold">{metrics.infrastructureDensity.toFixed(2)}/km²</div>
          </div>
          <div className="bg-orange-50 p-3 rounded-lg">
            <div className="text-sm text-gray-600">Demand Coverage</div>
            <div className="text-lg font-semibold">{metrics.estimatedDemandCoverage.toFixed(0)}%</div>
          </div>
        </div>

        {/* Energy Source Distribution */}
        <div>
          <h4 className="font-semibold mb-2">Energy Source Distribution</h4>
          <div className="space-y-2">
            {getEnergySourceDistribution(stations).map((source) => (
              <div key={source.name} className="flex items-center gap-2">
                <div
                  className="w-3 h-3 rounded"
                  style={{ backgroundColor: source.color }}
                />
                <div className="flex-1">
                  <div className="flex justify-between text-sm">
                    <span>{source.name}</span>
                    <span>{source.percentage.toFixed(0)}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-1.5">
                    <div
                      className="h-1.5 rounded-full"
                      style={{ 
                        width: `${source.percentage}%`,
                        backgroundColor: source.color
                      }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Coverage Analysis */}
        <div>
          <h4 className="font-semibold mb-2">Coverage Analysis</h4>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-600">High Coverage Areas:</span>
              <span className="font-semibold text-green-600">
                {stations.filter(s => s.available).length} zones
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Coverage Gaps:</span>
              <span className="font-semibold text-red-600">
                {metrics.coverageGaps.length} areas
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Optimal Station Range:</span>
              <span className="font-semibold">
                0.5-2.0 km
              </span>
            </div>
          </div>
        </div>

        {/* Recommendations */}
        <div className="bg-yellow-50 p-3 rounded-lg">
          <h4 className="font-semibold mb-2 text-yellow-800">Urban Planning Recommendations</h4>
          <ul className="text-sm text-yellow-700 space-y-1">
            {getRecommendations(metrics).map((rec, index) => (
              <li key={index} className="flex items-start gap-2">
                <span className="text-yellow-600">•</span>
                <span>{rec}</span>
              </li>
            ))}
          </ul>
        </div>

        {/* Accessibility Heatmap Legend */}
        <div>
          <h4 className="font-semibold mb-2">Accessibility Legend</h4>
          <div className="flex items-center gap-2 text-sm">
            <div className="flex-1 h-4 rounded bg-gradient-to-r from-red-500 via-yellow-500 to-green-500" />
            <div className="flex gap-2 text-xs">
              <span className="text-red-600">Low</span>
              <span className="text-yellow-600">Medium</span>
              <span className="text-green-600">High</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function calculateUrbanPlanningMetrics(
  stations: ChargingStation[],
  centre: readonly [number, number],
): UrbanPlanningMetrics {
  if (stations.length === 0) {
    return {
      chargingAccessibility: 0,
      averageStationDistance: 0,
      renewableEnergyPercentage: 0,
      coverageGaps: [],
      infrastructureDensity: 0,
      estimatedDemandCoverage: 0,
    }
  }

  // Calculate average distance between stations
  let totalDistance = 0
  let distanceCount = 0
  for (let i = 0; i < stations.length; i++) {
    for (let j = i + 1; j < stations.length; j++) {
      const distance = calculateDistance(
        stations[i].latitude,
        stations[i].longitude,
        stations[j].latitude,
        stations[j].longitude
      )
      totalDistance += distance
      distanceCount++
    }
  }
  const averageDistance = distanceCount > 0 ? totalDistance / distanceCount : 0

  // Calculate renewable energy percentage
  const renewableStations = stations.filter(
    s => s.energySource === 'Solar' || s.energySource === 'CommunitySolar'
  )
  const renewablePercentage = (renewableStations.length / stations.length) * 100

  // Calculate infrastructure density (simplified - assuming 10km² area)
  const infrastructureDensity = stations.length / 10

  // Calculate charging accessibility score
  const accessibilityScore = calculateAccessibilityScore(
    averageDistance,
    renewablePercentage,
    infrastructureDensity,
    stations.filter(s => s.available).length / stations.length
  )

  // Identify coverage gaps (areas far from any station)
  const coverageGaps = identifyCoverageGaps(stations, centre)

  // Estimate demand coverage (simplified heuristic)
  const demandCoverage = Math.min(100, (stations.length * 15)) // Each station covers ~15% of demand

  return {
    chargingAccessibility: accessibilityScore,
    averageStationDistance: averageDistance,
    renewableEnergyPercentage: renewablePercentage,
    coverageGaps,
    infrastructureDensity,
    estimatedDemandCoverage: demandCoverage,
  }
}

function calculateAccessibilityScore(
  avgDistance: number,
  renewablePercentage: number,
  density: number,
  availabilityRate: number
): number {
  // Normalize factors and weight them
  const distanceScore = Math.max(0, 100 - (avgDistance * 50)) // Lower distance = higher score
  const renewableScore = renewablePercentage
  const densityScore = Math.min(100, density * 20) // Higher density = higher score
  const availabilityScore = availabilityRate * 100

  // Weighted average
  return (
    distanceScore * 0.3 +
    renewableScore * 0.25 +
    densityScore * 0.25 +
    availabilityScore * 0.2
  )
}

function getEnergySourceDistribution(stations: ChargingStation[]) {
  const distribution = {
    Solar: stations.filter(s => s.energySource === 'Solar').length,
    Grid: stations.filter(s => s.energySource === 'Grid').length,
    CommunitySolar: stations.filter(s => s.energySource === 'CommunitySolar').length,
    BatteryStorage: stations.filter(s => s.energySource === 'BatteryStorage').length,
  }

  const total = stations.length
  const colors = {
    Solar: '#10B981',
    Grid: '#3B82F6',
    CommunitySolar: '#8B5CF6',
    BatteryStorage: '#F59E0B',
  }

  return Object.entries(distribution).map(([name, count]) => ({
    name,
    count,
    percentage: (count / total) * 100,
    color: colors[name as keyof typeof colors],
  }))
}

function getRecommendations(metrics: UrbanPlanningMetrics): string[] {
  const recommendations: string[] = []

  if (metrics.averageStationDistance > 1.5) {
    recommendations.push('Consider adding more stations to reduce average distance')
  }

  if (metrics.renewableEnergyPercentage < 50) {
    recommendations.push('Increase renewable energy sources for better sustainability')
  }

  if (metrics.coverageGaps.length > 0) {
    recommendations.push(`Address ${metrics.coverageGaps.length} coverage gap areas`)
  }

  if (metrics.estimatedDemandCoverage < 70) {
    recommendations.push('Expand infrastructure to meet projected EV demand')
  }

  if (metrics.infrastructureDensity < 0.5) {
    recommendations.push('Increase station density in high-demand areas')
  }

  if (recommendations.length === 0) {
    recommendations.push('Current infrastructure distribution is optimal')
  }

  return recommendations
}