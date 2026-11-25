type Coordinates = readonly [latitude: number, longitude: number]

export const COVERAGE_RADIUS_KM = 2

export function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

export function coverageSamplePoints([latitude, longitude]: Coordinates): Coordinates[] {
  const latitudeOffset = 3 / 111
  const longitudeOffset = latitudeOffset / Math.cos(latitude * Math.PI / 180)
  return [
    [latitude, longitude],
    [latitude + latitudeOffset, longitude],
    [latitude - latitudeOffset, longitude],
    [latitude, longitude + longitudeOffset],
    [latitude, longitude - longitudeOffset],
  ]
}

export function identifyCoverageGaps(
  stations: readonly { latitude: number; longitude: number }[],
  centre: Coordinates,
): number[] {
  return coverageSamplePoints(centre).flatMap(([latitude, longitude], index) => {
    const covered = stations.some((station) =>
      calculateDistance(latitude, longitude, station.latitude, station.longitude) <= COVERAGE_RADIUS_KM,
    )
    return covered ? [] : [index]
  })
}
