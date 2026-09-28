import AppKit
import SwiftUI
import UsageCore

/// 메뉴바 문자열을 만든다.
///
/// 이미지 대신 `attributedTitle`을 쓴다. 이미지와 타이틀을 함께 두면 이미지의 기하 중심과
/// 숫자의 광학 중심이 어긋나 한쪽이 떠 보인다. 텍스트만 쓰면 AppKit이 세로 정렬을 처리한다.
enum MenuBarLabel {
    private static let fontSize: CGFloat = 12.5

    static func attributedTitle(
        items: [MenuBarItem],
        strings: Strings,
        placeholder: String,
        needsAttention: Bool = false
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let separator = strings("menubar.separator")

        // 값이 `--`인 것만으로는 불러오는 중인지 조치가 필요한지 구분되지 않는다.
        if needsAttention, let mark = attentionMark {
            result.append(mark)
            result.append(NSAttributedString(string: " ", attributes: labelAttributes))
        }

        for (index, item) in items.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: separator, attributes: labelAttributes))
            }
            result.append(
                NSAttributedString(string: strings(item.labelKey) + " ", attributes: labelAttributes)
            )
            result.append(
                NSAttributedString(
                    string: item.percent.map { "\(Int($0))%" } ?? placeholder,
                    attributes: valueAttributes(for: item.level)
                )
            )
        }

        return result
    }

    /// 라벨에는 색을 지정하지 않는다.
    ///
    /// `NSColor.labelColor`는 앱의 외형 기준으로 해석된다. 이 앱은 창이 없어 밝은 외형으로
    /// 잡히므로, 어두운 메뉴바에 검은 글자를 그리게 되어 보이지 않는다.
    /// 색을 비워두면 AppKit이 메뉴바에 맞는 기본 색으로 그린다.
    /// 값과의 위계는 굵기와 크기로 만든다.
    private static var labelAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: fontSize - 1.5, weight: .regular)]
    }

    /// 경고 색을 직접 칠한다. 템플릿 이미지는 첨부 문자열 안에서 메뉴바 색을 따르지 않는다.
    private static var attentionMark: NSAttributedString? {
        let configuration = NSImage.SymbolConfiguration(pointSize: fontSize - 1.5, weight: .semibold)
            .applying(.init(paletteColors: [NSColor(Theme.color(for: .warning))]))
        guard let image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration) else { return nil }

        let attachment = NSTextAttachment()
        attachment.image = image
        // 글자 기준선에 맞춘다. 그대로 두면 기호 아래쪽이 기준선에 붙어 떠 보인다.
        let font = NSFont.systemFont(ofSize: fontSize)
        attachment.bounds = CGRect(
            x: 0,
            y: (font.capHeight - image.size.height) / 2,
            width: image.size.width,
            height: image.size.height
        )
        return NSAttributedString(attachment: attachment)
    }

    /// 숫자는 고정폭이라 자릿수가 같으면 폭이 흔들리지 않는다.
    private static func valueAttributes(for level: UsageLevel?) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        ]
        // 단계를 모를 때도 색을 비워둔다. 같은 이유다.
        if let level {
            attributes[.foregroundColor] = NSColor(Theme.color(for: level))
        }
        return attributes
    }
}
