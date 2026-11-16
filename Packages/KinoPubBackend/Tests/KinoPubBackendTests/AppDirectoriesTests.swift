//
//  AppDirectoriesTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class AppDirectoriesTests: XCTestCase {
  func testPersistentDataIsDocumentsOutsideTVOS() {
#if !os(tvOS)
    XCTAssertEqual(AppDirectories.persistentData,
                   FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
#endif
  }
}
