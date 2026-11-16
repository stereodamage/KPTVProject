# KPTV — kino.pub for Apple TV

![Platform](https://img.shields.io/badge/platform-tvOS%2018%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Xcode](https://img.shields.io/badge/Xcode-26%2B-blue.svg)

A native SwiftUI client for [kino.pub](https://kino.pub) on **tvOS 18+**, built to the tvOS Human Interface
Guidelines: sidebar navigation, focus-driven shelves and grids, and the system player. The UI is in Russian.

Unofficial. Not affiliated with kino.pub. You sign in with your own kino.pub account (device code); the app
bundles no user credentials.

## Features

- Home with featured banners, Continue Watching and curated shelves
- Catalog: movies, series, cartoons and more, with sort / genre / country / year / rating / quality filters
- «Я смотрю»: new episodes, unfinished movies, followed shows; watch history grouped by day
- Title pages with seasons, cast, similar titles and Kinopoisk facts; version picker for multi-version films
- System player (`AVPlayerViewController`) with resume, kino.pub progress sync, skip intro / recap / credits
  (SkipDB, TheIntroDB) and Up Next with autoplay
- Live sport channels with a programme guide (XMLTV)

## Build and run

Requirements: Xcode 26+, tvOS 18 SDK.

```bash
open KinoPubAppleClient.xcodeproj     # scheme: KinoPubTV, destination: an Apple TV simulator or device
./scripts/tv-sim.sh run home          # or: clean-build, install and open in the Apple TV Simulator
cd Packages/KinoPubBackend && swift test
```

To run on a real Apple TV, select your own team under Signing & Capabilities. `DEVELOPMENT_TEAM` stays empty
in the repository — do not commit it.

Debug builds accept `-tvTab <section>` (open on a sidebar section) and `-tvSeekTo <seconds>` (jump the first
player, for testing episode endings).

## Credits

Based on [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client) and its community fork
[dungeon-master-xx/kinopub-apple-client](https://github.com/dungeon-master-xx/kinopub-apple-client).
Skip data: [SkipDB](https://skipdb.tv) (ODbL) and [TheIntroDB](https://theintrodb.org).
