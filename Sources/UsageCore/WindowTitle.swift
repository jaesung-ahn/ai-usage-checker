import Foundation

/// 팝오버 카드의 제목.
///
/// 5시간과 7일 외의 길이도 버리지 않고 길이 그대로 이름을 만든다. 공급자가 새 창을 보내도
/// 화면에서 빠지지 않아야 한다.
public func windowTitle(_ window: UsageWindow, strings: Strings) -> String {
    switch (window.scope, window.length) {
    case (nil, .fiveHours):
        return strings("pool.session")
    case (nil, .sevenDays):
        return strings("pool.weeklyAll")
    case (nil, let length):
        return strings("pool.window", ["length": lengthLabel(length, strings: strings)])
    case (let name?, .sevenDays):
        return strings("pool.weeklyScoped", ["name": name])
    case (let name?, let length):
        return strings("pool.scopedWindow", ["name": name, "length": lengthLabel(length, strings: strings)])
    }
}

/// 나누어떨어지는 가장 큰 단위로 표시한다.
func lengthLabel(_ length: WindowLength, strings: Strings) -> String {
    let seconds = length.seconds
    if seconds % 86_400 == 0 {
        return strings("length.days", ["n": String(seconds / 86_400)])
    }
    if seconds % 3_600 == 0 {
        return strings("length.hours", ["n": String(seconds / 3_600)])
    }
    return strings("length.minutes", ["n": String(seconds / 60)])
}
