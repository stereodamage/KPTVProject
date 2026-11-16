//
//  TVPlayerView.swift
//  KinoPubTV
//
//  The system tvOS player (AVPlayerViewController): transport bar, scrubbing with thumbnails,
//  audio-track / subtitle menus, info panel and Siri Remote gestures all come for free. Progress is
//  reported to kino.pub by `PlayerManager`.
//

import SwiftUI
import AVKit
import KinoPubBackend

struct TVPlayerView: View {
  @StateObject private var session: TVPlaybackSession
  @Environment(\.dismiss) private var dismiss
  @Environment(\.appContext) private var appContext
  @State private var context: TVPlaybackContext?

  init(session: @autoclosure @escaping () -> TVPlaybackSession) {
    _session = StateObject(wrappedValue: session())
  }

  var body: some View {
    PlayerPresenter(player: session.manager.player,
                    resumeTime: session.manager.continueTime,
                    skip: context?.skip,
                    hasNext: context?.next != nil,
                    onResume: { [session] in session.manager.seekToContinueWatching() },
                    onNext: playNext,
                    onFinished: { dismiss() })
      .ignoresSafeArea()
      .toolbar(.hidden, for: .navigationBar)
      .onAppear {
        UIApplication.shared.isIdleTimerDisabled = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
      }
      .task(id: ObjectIdentifier(session.manager)) { [session, contentService = appContext.contentService] in
        context = nil
        let manager = session.manager
        async let mark: Void = manager.fetchWatchMark()
        let loaded = await TVPlaybackContext.load(item: manager.playItem, mode: manager.watchMode,
                                                  contentService: contentService)
        await mark
        guard manager === session.manager else { return }
        context = loaded
      }
      .alert("Playback error".localized,
             isPresented: Binding(get: { [session] in session.manager.playbackError != nil },
                                  set: { [session] in if !$0 { session.manager.playbackError = nil } })) {
        Button("OK") { dismiss() }
      } message: {
        Text(session.manager.playbackError ?? "")
      }
  }

  private func playNext() {
    guard let next = context?.next else { return }
    context = nil
    session.advance(to: next)
  }
}

/// Presents the player modally from a black host once it's on screen (so presentation can't race the
/// window), and reports when the user leaves it with Menu/Back so the route pops.
private struct PlayerPresenter: UIViewControllerRepresentable {
  let player: AVPlayer
  let resumeTime: TimeInterval?
  let skip: TVSkipSetup?
  let hasNext: Bool
  let onResume: () -> Void
  let onNext: () -> Void
  let onFinished: () -> Void

  static func dismantleUIViewController(_ host: PlayerHostController, coordinator: ()) {
    host.stopPlayback()
  }

  func makeUIViewController(context: Context) -> PlayerHostController {
    let host = PlayerHostController()
    host.player = player
    update(host)
    return host
  }

  func updateUIViewController(_ host: PlayerHostController, context: Context) {
    if host.player !== player { host.replacePlayer(player) }
    update(host)
    host.resumeIfNeeded()
  }

  private func update(_ host: PlayerHostController) {
    host.resumeTime = resumeTime
    host.onResume = onResume
    host.onNext = onNext
    host.onFinished = onFinished
    host.setButtons(skip: skip, hasNext: hasNext)
  }
}

final class PlayerHostController: UIViewController {
  var player: AVPlayer?
  var resumeTime: TimeInterval?
  var onResume: (() -> Void)?
  var onNext: (() -> Void)?
  var onFinished: (() -> Void)?

  private var skip: TVSkipSetup?
  private var hasNext = false
  private var buttonObserver: Any?
  private var endObserver: NSObjectProtocol?
  private var shownButton: PlayerButton?
  private var autoSkip = AutoSkipState()
  private var lastTick: Double?

  private var didPresent = false
  private var didResume = false
  private weak var playerController: AVPlayerViewController?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !didPresent {
      present()
    } else if presentedViewController == nil {
      stopPlayback()
      onFinished?()
    }
  }

  /// Not in SwiftUI's `onDisappear`: that fires as soon as the full-screen player covers this host.
  func stopPlayback() {
    player?.pause()
    UIApplication.shared.isIdleTimerDisabled = false
    removeObservers()
  }

  private func present() {
    guard let player else { return }
    didPresent = true
    let controller = AVPlayerViewController()
    controller.player = player
    controller.modalPresentationStyle = .fullScreen
    playerController = controller
    present(controller, animated: true) { [weak self] in
      player.play()
      self?.resumeIfNeeded()
      self?.installObservers()
#if DEBUG
      // Test hook: launch with `-tvSeekTo <seconds>` to jump the first player near an episode's end.
      let debugSeek = UserDefaults.standard.double(forKey: "tvSeekTo")
      if debugSeek > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.seek(to: debugSeek) }
      }
#endif
    }
  }

  /// The next episode: same on-screen player, new `AVPlayer`.
  func replacePlayer(_ newPlayer: AVPlayer) {
    removeObservers()
    player = newPlayer
    playerController?.player = newPlayer
    playerController?.contextualActions = []
    didResume = false
    shownButton = nil
    lastTick = nil
    autoSkip = AutoSkipState()
    newPlayer.play()
    installObservers()
  }

  func setButtons(skip: TVSkipSetup?, hasNext: Bool) {
    guard skip != self.skip || hasNext != self.hasNext else { return }
    self.skip = skip
    self.hasNext = hasNext
    installObservers()
  }

  // MARK: - Skip / next episode buttons, autoplay

  private func installObservers() {
    guard let player, let item = player.currentItem, playerController != nil else { return }
    if endObserver == nil {
      endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item,
                                                           queue: .main) { [weak self] _ in
        guard let self, self.hasNext else { return }
        self.onNext?()
      }
    }
    guard buttonObserver == nil, skip != nil || hasNext else { return }
    buttonObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                    queue: .main) { [weak self] time in
      self?.tick(at: time.seconds)
    }
  }

  private func removeObservers() {
    if let buttonObserver { player?.removeTimeObserver(buttonObserver) }
    buttonObserver = nil
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = nil
  }

  private func tick(at time: Double) {
    guard let controller = playerController else { return }
    let streamLength = player?.currentItem?.duration.seconds ?? .nan
    let duration = streamLength.isFinite ? streamLength : (skip?.apiDuration ?? .nan)
    let segments = skip?.segments ?? []
    let schedule = SkipSchedule(segments: segments, isFilm: skip?.isFilm ?? false, duration: duration)
    let offer = hasNext ? UpNext.offerTime(duration: duration, credits: segments.first { $0.kind == .credits }) : nil
    let button = UpNext.button(at: time, schedule: schedule, offerTime: offer, hasNext: hasNext)
    let previous = lastTick
    lastTick = time

    if case .skip(let segment) = button,
       autoSkip.shouldAutoSkip(segment, at: time, previous: previous, isPlaying: (player?.rate ?? 0) > 0,
                               enabled: UserDefaults.standard.bool(forKey: TVSkipSegments.autoSkipKey)) {
      seek(to: schedule.skipTarget(for: segment))
      return
    }
    guard button != shownButton else { return }
    shownButton = button
    switch button {
    case .skip(let segment):
      controller.contextualActions = [UIAction(title: TVSkipSegments.title(for: segment.kind)) { [weak self] _ in
        self?.seek(to: schedule.skipTarget(for: segment))
      }]
    case .nextEpisode:
      controller.contextualActions = [UIAction(title: "Next episode".localized) { [weak self] _ in
        self?.onNext?()
      }]
    case nil:
      controller.contextualActions = []
    }
  }

  private func seek(to seconds: Double) {
    player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
  }

  /// Always continue from where the user left off (the resume point can arrive after presentation).
  func resumeIfNeeded() {
    guard !didResume, let resume = resumeTime, resume > 0,
          playerController?.viewIfLoaded?.window != nil else { return }
    didResume = true
    onResume?()
  }
}
