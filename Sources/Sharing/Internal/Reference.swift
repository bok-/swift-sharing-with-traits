#if canImport(Dependencies)
import Dependencies
#endif
import Foundation
#if canImport(IdentifiedCollections)
import IdentifiedCollections
#endif
#if canImport(IssueReporting)
import IssueReporting
#endif
#if canImport(PerceptionCore)
import PerceptionCore
#endif

#if canImport(Combine)
  import Combine
#endif

#if canImport(PerceptionCore)
protocol Reference<Value>:
  AnyObject,
  CustomStringConvertible,
  Sendable,
  Perceptible
{
  associatedtype Value

  var id: ObjectIdentifier { get }
  var isLoading: Bool { get }
  var loadError: (any Error)? { get }
  var wrappedValue: Value { get }
  func load() async throws
  func touch()
  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> { get }
  #endif
}
#else
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
protocol Reference<Value>:
  AnyObject,
  CustomStringConvertible,
  Sendable,
  Observable
{
  associatedtype Value

  var id: ObjectIdentifier { get }
  var isLoading: Bool { get }
  var loadError: (any Error)? { get }
  var wrappedValue: Value { get }
  func load() async throws
  func touch()
  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> { get }
  #endif
}
#endif

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
protocol MutableReference<Value>: Reference, Equatable {
  var saveError: (any Error)? { get }
  var snapshot: Value? { get }
  func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R
  func takeSnapshot(
    _ value: Value,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  )
  func save() async throws
}

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
final class _BoxReference<Value>: MutableReference, Observable, @unchecked Sendable {

  #if canImport(PerceptionCore)
  private let _$perceptionRegistrar = PerceptionRegistrar(isPerceptionCheckingEnabled: false)
  #else
  private let _$observationRegistrar = ObservationRegistrar()
  #endif
  private let lock = NSRecursiveLock()

  #if canImport(Combine)
    private var value: Value {
      willSet {
        #if canImport(Dependencies)
        @Dependency(\.snapshots) var snapshots
        #else
        let snapshots = Snapshots()
        #endif
        if !snapshots.isAsserting {
          subject.send(newValue)
        }
      }
    }
    let subject = PassthroughRelay<Value>()

    var publisher: any Publisher<Value, Never> {
      subject.prepend(lock.withLock { value })
    }
  #else
    private var value: Value
  #endif

  init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  var id: ObjectIdentifier { ObjectIdentifier(self) }

  var isLoading: Bool {
    false
  }

  var loadError: (any Error)? {
    nil
  }

  var saveError: (any Error)? {
    nil
  }

  var wrappedValue: Value {
    access(keyPath: \.value)
    return lock.withLock { value }
  }

  var snapshot: Value? {
    #if canImport(Dependencies)
    @Dependency(\.snapshots) var snapshots
    #else
    let snapshots = Snapshots()
    #endif
    return snapshots[self]
  }

  func takeSnapshot(
    _ value: Value,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    #if canImport(Dependencies)
    @Dependency(\.snapshots) var snapshots
    #else
    let snapshots = Snapshots()
    #endif
    snapshots.save(
      key: self,
      value: value,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  func load() {}

  func touch() {
    withMutation(keyPath: \.value) {}
  }

  func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
    try withMutation(keyPath: \.value) {
      try lock.withLock { try body(&value) }
    }
  }

  func save() {}

  static func == (lhs: _BoxReference, rhs: _BoxReference) -> Bool {
    lhs === rhs
  }

  func access<Member>(
    keyPath: KeyPath<_BoxReference, Member>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    #if canImport(PerceptionCore)
    _$perceptionRegistrar.access(
      self,
      keyPath: keyPath,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
    #else
      _$observationRegistrar.access(self, keyPath: keyPath)
    #endif
  }

  func withMutation<Member, MutationResult>(
    keyPath: _SendableKeyPath<_BoxReference, Member>,
    _ mutation: () throws -> MutationResult
  ) rethrows -> MutationResult {
    #if canImport(PerceptionCore)
    #if os(WASI)
      return try _$perceptionRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    #else
      if Thread.isMainThread {
        return try _$perceptionRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
      } else {
        DispatchQueue.main.async {
          self._$perceptionRegistrar.withMutation(of: self, keyPath: keyPath) {}
        }
        return try mutation()
      }
    #endif
    #else
#if os(WASI)
      return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
#else
      if Thread.isMainThread {
        return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
      } else {
        DispatchQueue.main.async {
          self._$observationRegistrar.withMutation(of: self, keyPath: keyPath) {}
        }
      }
#endif
    return try mutation()
    #endif
  }

  var description: String {
    "value: \(String(reflecting: wrappedValue))"
  }
}
#if canImport(PerceptionCore)
extension _BoxReference: Perceptible {}
#endif

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
final class _PersistentReference<Key: SharedReaderKey>:
  Reference, Observable, @unchecked Sendable
{
  #if canImport(PerceptionCore)
  private let _$perceptionRegistrar = PerceptionRegistrar(isPerceptionCheckingEnabled: false)
  #else
  private let _$observationRegistrar = ObservationRegistrar()
  #endif
  private let key: Key
  private let lock = NSRecursiveLock()

  #if canImport(Combine)
    private var value: Key.Value {
      willSet {
        #if canImport(Dependencies)
        @Dependency(\.snapshots) var snapshots
        #else
        let snapshots = Snapshots()
        #endif
        if !snapshots.isAsserting {
          subject.send(newValue)
        }
      }
    }
    private let subject = PassthroughRelay<Value>()

    var publisher: any Publisher<Key.Value, Never> {
      SharedPublisherLocals.isLoading ? subject : subject.prepend(lock.withLock { value })
    }
  #else
    private var value: Key.Value
  #endif

  private var _isLoading = false
  private var _loadError: (any Error)?
  private var _saveError: (any Error)?
  private var subscription: SharedSubscription?
  internal var onDeinit: (() -> Void)?

  init(key: Key, value initialValue: Key.Value, skipInitialLoad: Bool) {
    self.key = key
    self.value = initialValue
    let callback: @Sendable (Result<Value?, any Error>) -> Void = { [weak self] result in
      guard let self else { return }
      isLoading = false
      switch result {
      case let .failure(error):
        loadError = error
      case let .success(newValue):
        if _loadError != nil { loadError = nil }
        wrappedValue = newValue ?? initialValue
      }
    }
    if !skipInitialLoad {
      isLoading = true
      key.load(
        context: .initialValue(initialValue),
        continuation: LoadContinuation("\(key)", callback: callback)
      )
    }
    let context: LoadContext<Key.Value> =
      skipInitialLoad
      ? .userInitiated
      : .initialValue(initialValue)
    self.subscription = key.subscribe(
      context: context,
      subscriber: SharedSubscriber(
        callback: callback,
        onLoading: { [weak self] in self?.isLoading = $0 }
      )
    )
  }

  deinit {
    onDeinit?()
  }

  var id: ObjectIdentifier { ObjectIdentifier(self) }

  var isLoading: Bool {
    get {
      access(keyPath: \._isLoading)
      return lock.withLock { _isLoading }
    }
    set {
      withMutation(keyPath: \._isLoading) {
        lock.withLock { _isLoading = newValue }
      }
    }
  }

  var loadError: (any Error)? {
    get {
      access(keyPath: \._loadError)
      return lock.withLock { _loadError }
    }
    set {
      withMutation(keyPath: \._loadError) {
        lock.withLock { _loadError = newValue }
      }
      #if DEBUG && canImport(IssueReporting)
        if !isTesting, let newValue {
          reportIssue(newValue)
        }
      #endif
    }
  }

  var wrappedValue: Key.Value {
    get {
      access(keyPath: \.value)
      return lock.withLock { value }
    }
    set {
      withMutation(keyPath: \.value) {
        lock.withLock { value = newValue }
      }
    }
  }

  func load() async throws {
    isLoading = true
    defer { isLoading = false }
    do {
      try await withUnsafeThrowingContinuation { continuation in
        let key = key
        key.load(
          context: .userInitiated,
          continuation: LoadContinuation("\(key)") { result in
            switch result {
            case .success(.some(let newValue)):
              self.wrappedValue = newValue
              continuation.resume()
            case .success(.none):
              continuation.resume()
            case .failure(let error):
              continuation.resume(throwing: error)
            }
          }
        )
      }
      if _loadError != nil { loadError = nil }
    } catch {
      loadError = error
      throw error
    }
  }

  func touch() {
    withMutation(keyPath: \.value) {}
  }

  func access<Member>(
    keyPath: KeyPath<_PersistentReference, Member>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
#if canImport(PerceptionCore)
    _$perceptionRegistrar.access(
      self,
      keyPath: keyPath,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
#else
    _$observationRegistrar.access(self, keyPath: keyPath)
#endif
  }

  func withMutation<Member, MutationResult>(
    keyPath: _SendableKeyPath<_PersistentReference, Member>,
    _ mutation: () throws -> MutationResult
  ) rethrows -> MutationResult {
#if canImport(PerceptionCore)
#if os(WASI)
    return try _$perceptionRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
#else
    if Thread.isMainThread {
      return try _$perceptionRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    } else {
      DispatchQueue.main.async {
        self._$perceptionRegistrar.withMutation(of: self, keyPath: keyPath) {}
      }
      return try mutation()
    }
#endif
#else
#if os(WASI)
    return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
#else
    if Thread.isMainThread {
      return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    } else {
      DispatchQueue.main.async {
        self._$observationRegistrar.withMutation(of: self, keyPath: keyPath) {}
      }
    }
#endif
    return try mutation()
#endif
  }

  var description: String {
    String(reflecting: key)
  }
}
#if canImport(PerceptionCore)
extension _PersistentReference: Perceptible {}
#endif

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
extension _PersistentReference: MutableReference, Equatable where Key: SharedKey {
  var saveError: (any Error)? {
    get {
      access(keyPath: \._saveError)
      return lock.withLock { _saveError }
    }
    set {
      withMutation(keyPath: \._saveError) {
        lock.withLock { _saveError = newValue }
      }
      #if DEBUG && canImport(IssueReporting)
        if !isTesting, let newValue {
          reportIssue(newValue)
        }
      #endif
    }
  }

  var snapshot: Key.Value? {
    #if canImport(Dependencies)
    @Dependency(\.snapshots) var snapshots
    #else
    let snapshots = Snapshots()
    #endif
    return snapshots[self]
  }

  func takeSnapshot(
    _ value: Key.Value,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
#if canImport(Dependencies)
@Dependency(\.snapshots) var snapshots
#else
let snapshots = Snapshots()
#endif
    snapshots.save(
      key: self,
      value: value,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  func withLock<R>(_ body: (inout Key.Value) throws -> R) rethrows -> R {
    try withMutation(keyPath: \.value) {
      defer {
        let key = key
        key.save(
          value,
          context: .didSet,
          continuation: SaveContinuation("\(key)") { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
              if _loadError != nil { loadError = nil }
              if _saveError != nil { saveError = nil }
            case let .failure(error):
              saveError = error
            }
          }
        )
      }
      return try lock.withLock {
        try body(&value)
      }
    }
  }

  func save() async throws {
    if _saveError != nil { saveError = nil }
    do {
      _ = try await withUnsafeThrowingContinuation { continuation in
        let key = key
        key.save(
          lock.withLock { value },
          context: .userInitiated,
          continuation: SaveContinuation("\(key)") { result in
            continuation.resume(with: result)
          }
        )
      }
    } catch {
      saveError = error
      throw error
    }
    if _loadError != nil { loadError = nil }
  }

  static func == (lhs: _PersistentReference, rhs: _PersistentReference) -> Bool {
    lhs === rhs
  }
}

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
final class _AppendKeyPathReference<
  Base: Reference, Value, Path: KeyPath<Base.Value, Value> & Sendable
>: Reference, Observable {
  private let base: Base
  private let keyPath: Path

  init(base: Base, keyPath: Path) {
    self.base = base
    self.keyPath = keyPath
  }

  var id: ObjectIdentifier {
    base.id
  }

  var isLoading: Bool {
    base.isLoading
  }

  var loadError: (any Error)? {
    base.loadError
  }

  var wrappedValue: Value {
    base.wrappedValue[keyPath: keyPath]
  }

  func load() async throws {
    try await base.load()
  }

  func touch() {
    base.touch()
  }

  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> {
      func open(_ publisher: some Publisher<Base.Value, Never>) -> any Publisher<Value, Never> {
        publisher.map(keyPath)
      }
      return open(base.publisher)
    }
  #endif

  var description: String {
    "\(base.description)[dynamicMember: \(keyPath)]"
  }
}

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
extension _AppendKeyPathReference: MutableReference, Equatable
where Base: MutableReference, Path: WritableKeyPath<Base.Value, Value> {
  var saveError: (any Error)? {
    base.saveError
  }

  var snapshot: Value? {
    base.snapshot?[keyPath: keyPath]
  }

  func takeSnapshot(
    _ value: Value,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    var snapshot = base.snapshot ?? base.wrappedValue
    snapshot[keyPath: keyPath as WritableKeyPath] = value
    base.takeSnapshot(snapshot, fileID: fileID, filePath: filePath, line: line, column: column)
  }

  func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
    try base.withLock { try body(&$0[keyPath: keyPath as WritableKeyPath]) }
  }

  func save() async throws {
    try await base.save()
  }

  static func == (lhs: _AppendKeyPathReference, rhs: _AppendKeyPathReference) -> Bool {
    lhs.base == rhs.base && lhs.keyPath == rhs.keyPath
  }
}

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
final class _ReadClosureReference<Base: Reference, Value>:
  Reference,
  Observable
{
  private let base: Base
  private let body: @Sendable (Base.Value) -> Value

  init(base: Base, body: @escaping @Sendable (Base.Value) -> Value) {
    self.base = base
    self.body = body
  }

  var id: ObjectIdentifier {
    base.id
  }

  var isLoading: Bool {
    base.isLoading
  }

  var loadError: (any Error)? {
    base.loadError
  }

  var wrappedValue: Value {
    body(base.wrappedValue)
  }

  func load() async throws {
    try await base.load()
  }

  func touch() {
    base.touch()
  }

  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> {
      func open(_ publisher: some Publisher<Base.Value, Never>) -> any Publisher<Value, Never> {
        publisher.map(body)
      }
      return open(base.publisher)
    }
  #endif

  var description: String {
    ".map(\(base.description), as: \(Value.self).self)"
  }
}

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
final class _OptionalReference<Base: Reference<Value?>, Value>:
  Reference,
  Observable,
  @unchecked Sendable
{
  private let base: Base
  private var cachedValue: Value
  private let lock = NSRecursiveLock()

  init(base: Base, initialValue: Value) {
    self.base = base
    self.cachedValue = initialValue
  }

  var id: ObjectIdentifier {
    base.id
  }

  var isLoading: Bool {
    base.isLoading
  }

  var loadError: (any Error)? {
    base.loadError
  }

  var wrappedValue: Value {
    guard let wrappedValue = base.wrappedValue else { return lock.withLock { cachedValue } }
    lock.withLock { cachedValue = wrappedValue }
    return wrappedValue
  }

  func load() async throws {
    try await base.load()
  }

  func touch() {
    base.touch()
  }

  #if canImport(Combine)
    var publisher: any Publisher<Value, Never> {
      func open(_ publisher: some Publisher<Value?, Never>) -> any Publisher<Value, Never> {
        publisher.compactMap { $0 }
      }
      return open(base.publisher)
    }
  #endif

  var description: String {
    "\(base.description)!"
  }
}

#if !canImport(PerceptionCore)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
#endif
extension _OptionalReference: MutableReference, Equatable where Base: MutableReference {
  var saveError: (any Error)? {
    base.saveError
  }

  var snapshot: Value? {
    base.snapshot ?? nil
  }

  func takeSnapshot(
    _ value: Value,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    guard base.wrappedValue != nil else { return }
    base.takeSnapshot(value, fileID: fileID, filePath: filePath, line: line, column: column)
  }

  func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
    try base.withLock { value in
      guard var unwrapped = value else { return try lock.withLock { try body(&cachedValue) } }
      defer {
        value = unwrapped
        lock.withLock { cachedValue = unwrapped }
      }
      return try body(&unwrapped)
    }
  }

  func save() async throws {
    try await base.save()
  }

  static func == (lhs: _OptionalReference, rhs: _OptionalReference) -> Bool {
    lhs.base == rhs.base
  }
}
