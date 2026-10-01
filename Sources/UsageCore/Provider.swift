import Foundation

/// 사용량을 조회하는 AI 코딩 도구.
///
/// 공급자마다 정규화 함수가 따로 있고, 결과는 같은 `UsageReading`이다.
public enum Provider: String, CaseIterable, Sendable {
    case claude
    case codex
}
