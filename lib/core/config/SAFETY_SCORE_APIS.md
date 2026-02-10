# Live Safety Score – Sri Lanka

The app is **optimized for Sri Lanka only**. The safety score is generated from:

1. **Population density** – District-based density (census) + activity density (OpenStreetMap POIs).
2. **Closest distance to police station** – From OpenStreetMap (Overpass API). Closer = safer.
3. **Time of day** – Sunrise–sunset API for your location. Night = higher risk.
4. **Past incidents** – **Sri Lanka data only** (district-level risk from Sri Lankan records). No foreign crime APIs (no UK, no Crimeometer).

## Data sources (no API keys)

| Factor             | Source                                                    | Notes                                                       |
| ------------------ | --------------------------------------------------------- | ----------------------------------------------------------- |
| Time of day        | [Sunrise-Sunset.org](https://api.sunrise-sunset.org/json) | Sunrise/sunset for your coordinates                         |
| Distance to police | [Overpass / OpenStreetMap](https://overpass-api.de)       | Nearest `amenity=police` in Sri Lanka                       |
| Population density | Sri Lanka districts + Overpass                            | District density + nearby POI count                         |
| Past incidents     | Sri Lanka only (embedded)                                 | District-level risk from Sri Lanka data; no foreign records |

## Sri Lanka configuration

- **Bounds:** Lat 5.9–9.8, Lon 79.5–82.0.
- **Default map center:** Colombo (6.9271, 79.8612).
- **25 districts** with centroid, population density, and incident risk from Sri Lankan records.

## Note

The live safety score uses Overpass/OSM for nearby POIs and emergency services.

## Attribution

- Sunrise-Sunset.org (attribution as per their terms).
- © OpenStreetMap contributors, ODbL.
- Sri Lanka district and incident risk data: based on Sri Lankan official/census and police statistics.
