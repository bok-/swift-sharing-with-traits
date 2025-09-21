#if canImport(IssueReporting)

  import IssueReporting

  package func reportIssue(
    _ message: @autoclosure () -> String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    IssueReporting.reportIssue(
      message(), fileID: fileID, filePath: filePath, line: line, column: column)
  }

#else

  package func reportIssue(
    _ message: @autoclosure () -> String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    assertionFailure(message() ?? "Nil issue reported", file: fileID, line: line)
  }

#endif
