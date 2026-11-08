import CoreGraphics
import Testing
@testable import Pesty

@Suite("BarResizeGeometry")
struct BarResizeGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test("heights outside the preference range are pulled back into it")
    func normalizes() {
        #expect(BarResizeGeometry.normalizedPersistedHeight(10)
                == BarResizeGeometry.minimumHeight)
        #expect(BarResizeGeometry.normalizedPersistedHeight(5000)
                == BarResizeGeometry.maximumHeight)
        #expect(BarResizeGeometry.normalizedPersistedHeight(.nan)
                == BarResizeGeometry.defaultHeight)
    }

    @Test("the panel floats inside the visible frame")
    func floats() {
        let frame = BarResizeGeometry.panelFrame(for: 400, in: screen)
        #expect(frame.minX == BarResizeGeometry.sideInset)
        #expect(frame.minY == BarResizeGeometry.bottomInset)
        #expect(frame.width == screen.width - BarResizeGeometry.sideInset * 2)
        #expect(frame.height == 400)
    }

    @Test("a short display caps the panel height instead of pushing it off-screen")
    func capsToTheDisplay() {
        let short = CGRect(x: 0, y: 0, width: 1200, height: 640)
        let frame = BarResizeGeometry.panelFrame(for: BarResizeGeometry.maximumHeight, in: short)
        #expect(frame.height == short.height - BarResizeGeometry.bottomInset)
        #expect(frame.maxY <= short.maxY)
    }

    @Test("a screen too short for the bar never produces a negative height")
    func degenerateScreen() {
        let tiny = CGRect(x: 0, y: 0, width: 800, height: 20)
        #expect(BarResizeGeometry.effectiveHeight(for: 400, in: tiny) == 0)
    }
}
