# NEXRAD Radar (iOS)

SwiftUI + MapLibre Native app. OpenFreeMap basemap (Liberty/Bright/Positron), pan / zoom / rotate / tilt
(two-finger drag, or the tilt slider), NEXRAD Level 2 + Level 3 decoded on-device, GOES imagery overlay.

## Build
1. On a Mac with Xcode 15+:  `brew install xcodegen`
2. `cd NexradRadar && xcodegen generate && open NexradRadar.xcodeproj`
3. Select the target > Signing & Capabilities > pick your Team (a free Apple ID works), change the bundle ID if needed.
4. Plug in your iPhone, choose it as the run destination, press Run.
   For an .ipa: Product > Archive > Distribute App > Development / Ad Hoc.

Swift packages (MapLibre Native, SWCompression for bzip2) resolve automatically.

## Data sources
* Level 2: `unidata-nexrad-level2` S3 bucket (latest complete volume, usually 5-10 min old)
* Level 3: `unidata-nexrad-level3` S3 bucket
* Satellite: NASA GIBS WMTS (GOES-East/West)

## Products
Level 2: Reflectivity, Velocity, Spectrum Width, ZDR, CC, PhiDP (any elevation cut; VCP shown in the status bar).
Level 3: Reflectivity (N0B..N3B), Velocity, ZDR, CC, KDP, Hydrometeor Class (4 tilts each), Spectrum Width,
Composite Reflectivity, Echo Tops, VIL, Precip Rate, 1-hr and Storm Total precip.

## Known limitations / things to verify
This code was written without being able to compile or run it. Expect to fix a few compile errors and verify:
* Level 3 calibration (scale/offset) for products other than reflectivity/velocity is based on the ICD from memory.
  Check `Level3Decoder.floatScaleCodes` / `minIncCodes` if colours look wrong. Legacy 16-level products are not supported
  (except composite reflectivity, approximated).
* Level 3 product IDs for Spectrum Width ("NSW") and the digital precip products may differ in the bucket.
* GIBS layer names / formats / latency are in `MapOptions.swift`.
* Range is computed in a flat-earth approximation (fine within ~460 km); no beam-height correction.
* Level 2 uses full volume files; for lower latency add support for the `unidata-nexrad-level2-chunks` bucket.
* Only a partial list of radar sites is included (`NexradSites.swift`).
