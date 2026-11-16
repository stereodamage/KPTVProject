//
//  AppDirectories.swift
//  KinoPubBackend
//

import Foundation

public enum AppDirectories {
  public static var persistentData: URL {
#if os(tvOS)
    // Apple TV has no persistent Documents folder; the server rebuilds this state after a purge.
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
#else
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
#endif
  }
}
