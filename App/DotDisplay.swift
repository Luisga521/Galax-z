import DotKit
import MetalKit
import OPZStage
import SwiftUI

/// The screen: the stage's dots on the GPU. A frame is drawn only when something moves; a still picture costs nothing.
struct DotDisplay: UIViewRepresentable {
    let live: Live
    let look: Look
    /// Something is over it: nothing to draw.
    var covered = false
    let action: (Stage.Action) -> Void

    /// How the matrix looks (Settings › Screen).
    struct Look: Equatable {
        /// Dots along the short side.
        var fineness = 240
        var glow = 0.8
        var afterglow = 0.5
    }

    func makeUIView(context: Context) -> DotView { DotView(stage: live.stage) }

    func updateUIView(_ view: DotView, context: Context) {
        view.look = look
        view.action = action
        view.covered = covered
        view.shown = { [weak live] s in live?.frameShown(s) }
        live.stageChanged = { [weak view] in view?.changed() }
    }

    static func dismantleUIView(_ view: DotView, coordinator: ()) { view.stop() }
}

final class DotView: UIView, UIGestureRecognizerDelegate {
    override class var layerClass: AnyClass { CAMetalLayer.self }
    private var metal: CAMetalLayer { layer as! CAMetalLayer }

    var look = DotDisplay.Look() { didSet { if look != oldValue { relayout(); changed() } } }
    var action: (Stage.Action) -> Void = { _ in }

    /// How long after its moment a frame was shown, now and then.
    var shown: (@MainActor @Sendable (Double) -> Void)?

    var covered = false { didSet { if covered != oldValue { link?.isPaused = covered; if covered { stage.letGo(); fingers = [:] }; changed() } } }

    private let stage: Stage
    private let canvas = DotCanvas(width: 1, height: 1)
    private let gpu: GPU?
    private var link: CADisplayLink?
    private var lastTime = 0.0
    private var lead = 0.0
    private var movedAt = 0.0
    private var pitch = 6, origin = SIMD2<Float>(0, 0)
    private var touchStart: (CGPoint, Double)?
    private var fingers: [UITouch: Int] = [:], nextFinger = 0
    private(set) var framesDrawn = 0
    /// For the self test.
    var shape: String { "\(canvas.width)x\(canvas.height) dots of \(pitch) px, drawable \(Int(metal.drawableSize.width))x\(Int(metal.drawableSize.height))" }

    init(stage: Stage) {
        self.stage = stage
        gpu = GPU()
        super.init(frame: .zero)
        isOpaque = true
        backgroundColor = .black
        metal.device = gpu?.device
        metal.pixelFormat = .bgra8Unorm
        metal.framebufferOnly = true
        metal.maximumDrawableCount = 2               // a third would be a frame further behind
        metal.isOpaque = true
        isMultipleTouchEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = [.updatesFrequently]
        for (direction, by) in [(UISwipeGestureRecognizer.Direction.left, 1), (.right, -1)] {
            let g = UISwipeGestureRecognizer(target: self, action: by > 0 ? #selector(nextPage) : #selector(previousPage))
            g.direction = direction
            g.cancelsTouchesInView = true
            g.delegate = self
            addGestureRecognizer(g)
        }
    }

    required init?(coder: NSCoder) { fatalError("not from a storyboard") }

    // MARK: when to draw

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return stop() }
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        l.isPaused = covered
        changed()
        becomeFirstResponder()
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    /// Something to show: full speed until it is still again.
    func changed() {
        movedAt = CACurrentMediaTime()
        rate(120)
    }

    private func rate(_ fps: Float) {
        guard let link, link.preferredFrameRateRange.preferred != fps else { return }
        link.preferredFrameRateRange = fps > 60 ? CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            : CAFrameRateRange(minimum: fps / 2, maximum: max(fps, 10), preferred: fps)
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.targetTimestamp
        // after the last change: long enough for the afterglow to go out, then rest
        if stage.still, CACurrentMediaTime() - movedAt > 1.2 {
            rate(8)
            lastTime = 0
            return
        }
        // nothing played or touched for a while: what still drifts can drift at 30
        if !stage.playhead.playing, CACurrentMediaTime() - movedAt > 6 { rate(30) }
        draw(now, dt: lastTime == 0 ? 1.0 / 120 : min(0.1, max(0.001, now - lastTime)))
        lastTime = now
    }

    private func draw(_ now: Double, dt: Double) {
        guard let gpu, bounds.width > 1, metal.drawableSize.width > 1 else { return }
        guard let drawable = metal.nextDrawable() else { return }
        stage.frame(canvas, time: now + lead, dt: dt)
        gpu.draw(canvas, to: drawable, GPU.Look(origin: origin, pitch: Float(pitch), glow: Float(look.glow) * 0.42, unlit: 0.0046,
                                                decay: look.afterglow <= 0 ? 0 : Float(pow(0.5, dt / (0.012 + look.afterglow * 0.06))),
                                                size: SIMD2(Float(canvas.width), Float(canvas.height))))
        #if !targetEnvironment(simulator)
        if framesDrawn % 10 == 0 {
            let aimed = now + lead
            drawable.addPresentedHandler { [weak self] d in
                let t = d.presentedTime
                guard t > 0 else { return }
                Task { @MainActor in self?.seen(after: t - now, aimed: t - aimed) }
            }
        }
        #endif
        framesDrawn += 1
        if framesDrawn % 60 == 0 { describe() }
    }

    /// A frame was seen this long after the moment the display link gave it: the next are drawn for when they will be seen.
    private func seen(after late: Double, aimed: Double) {
        guard late.isFinite, abs(late) < 0.1 else { return }
        lead += (min(0.04, max(0, late)) - lead) * 0.15
        shown?(aimed)
    }

    // MARK: size

    override func layoutSubviews() {
        super.layoutSubviews()
        relayout()
    }

    /// Whole pixels a dot, so every dot is exactly alike; what is left over goes round the edge.
    private func relayout() {
        let scale = window?.screen.nativeScale ?? traitCollection.displayScale
        let px = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        guard px.width > 8, px.height > 8 else { return }
        metal.contentsScale = scale
        metal.drawableSize = px
        pitch = max(3, Int((min(px.width, px.height) / CGFloat(look.fineness)).rounded()))
        // never so wide or narrow that a page cannot be laid out
        while Int(px.width) / pitch < 200, pitch > 3 { pitch -= 1 }
        let w = min(1600, Int(px.width) / pitch), h = min(1600, Int(px.height) / pitch)
        canvas.resize(w, h)
        origin = SIMD2(Float((Int(px.width) - w * pitch) / 2), Float((Int(px.height) - h * pitch) / 2))
        changed()
    }

    // MARK: touch and keys

    private func dot(_ p: CGPoint) -> (Int, Int) {
        let s = metal.contentsScale
        return (Int((p.x * s - CGFloat(origin.x)) / CGFloat(pitch)), Int((p.y * s - CGFloat(origin.y)) / CGFloat(pitch)))
    }

    /// Not a swipe where there is something to hold.
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive t: UITouch) -> Bool {
        let (x, y) = dot(t.location(in: self))
        return !stage.holds(x, y)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        becomeFirstResponder()
        for t in touches {
            let (x, y) = dot(t.location(in: self))
            nextFinger += 1
            if stage.grab(nextFinger, x, y) { fingers[t] = nextFinger } else { touchStart = (t.location(in: self), t.timestamp) }
        }
        changed()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { if let id = fingers[t] { let (x, y) = dot(t.location(in: self)); stage.drag(id, x, y) } }
        changed()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { if let id = fingers.removeValue(forKey: t) { stage.release(id, -1000, -1000) } else { touchStart = nil } }
        changed()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self), (x, y) = dot(p)
            if let id = fingers.removeValue(forKey: t) { stage.release(id, x, y); changed(); continue }
            guard let (from, _) = touchStart else { continue }
            touchStart = nil
            guard hypot(p.x - from.x, p.y - from.y) < 16 else { continue }
            let what = stage.tap(x, y)
            changed()
            if what != .none { action(what) }
        }
    }

    @objc private func nextPage() { stage.turn(1); changed() }
    @objc private func previousPage() { stage.turn(-1); changed() }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        var all = Stage.Page.allCases.map { p -> UIKeyCommand in
            let k = UIKeyCommand(input: "\((p.rawValue + 1) % 10)", modifierFlags: [], action: #selector(key(_:)))
            k.discoverabilityTitle = p.name.capitalized
            return k
        }
        for (input, title) in [(UIKeyCommand.inputRightArrow, "Next page"), (UIKeyCommand.inputLeftArrow, "Previous page"),
                               (UIKeyCommand.inputDownArrow, "Next track"), (UIKeyCommand.inputUpArrow, "Previous track"), ("h", "Galax-z OS"), (",", "Settings")] {
            let k = UIKeyCommand(input: input, modifierFlags: input == "," ? .command : [], action: #selector(key(_:)))
            k.discoverabilityTitle = title
            k.wantsPriorityOverSystemBehavior = true
            all.append(k)
        }
        return all
    }

    @objc private func key(_ k: UIKeyCommand) {
        switch k.input {
        case UIKeyCommand.inputRightArrow: stage.turn(1)
        case UIKeyCommand.inputLeftArrow: stage.turn(-1)
        case UIKeyCommand.inputDownArrow: stage.select(track: stage.track + 1)
        case UIKeyCommand.inputUpArrow: stage.select(track: stage.track - 1)
        case "h": action(.hub)
        case ",": action(.settings)
        case let n?: if let i = Int(n), let p = Stage.Page(rawValue: (i + 9) % 10) { stage.page = p }
        case nil: break
        }
        changed()
    }

    // MARK: for VoiceOver: what is on it, and its pages as actions

    private func describe() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        accessibilityLabel = stage.spoken
        accessibilityCustomActions = Stage.Page.allCases.map { p in
            UIAccessibilityCustomAction(name: p.name.capitalized) { [weak self] _ in self?.stage.page = p; self?.changed(); return true }
        } + [UIAccessibilityCustomAction(name: "Hub") { [weak self] _ in self?.action(.hub); return true },
             UIAccessibilityCustomAction(name: "Settings") { [weak self] _ in self?.action(.settings); return true }]
    }
}

/// Uploads the dots and draws them.
final class GPU {
    struct Look {
        var origin: SIMD2<Float>
        var pitch, glow, unlit, decay: Float
        var size: SIMD2<Float>
    }

    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let afterglow, across, down: MTLComputePipelineState
    private let screen: MTLRenderPipelineState
    private var dots: [MTLTexture] = [], light: [MTLTexture] = [], blur: [MTLTexture] = []
    private var frame = 0
    private let free = DispatchSemaphore(value: 3)

    init?() {
        guard let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue(), let lib = try? d.makeLibrary(source: dotShaders, options: nil),
              let a = lib.makeFunction(name: "afterglow"), let x = lib.makeFunction(name: "blurAcross"), let y = lib.makeFunction(name: "blurDown"),
              let v = lib.makeFunction(name: "wholeScreen"), let f = lib.makeFunction(name: "matrixOfLights") else { return nil }
        let p = MTLRenderPipelineDescriptor()
        p.vertexFunction = v
        p.fragmentFunction = f
        p.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let ap = try? d.makeComputePipelineState(function: a), let xp = try? d.makeComputePipelineState(function: x),
              let yp = try? d.makeComputePipelineState(function: y), let fp = try? d.makeRenderPipelineState(descriptor: p) else { return nil }
        (device, queue, afterglow, across, down, screen) = (d, q, ap, xp, yp, fp)
    }

    private func sized(_ w: Int, _ h: Int) {
        guard dots.first?.width != w || dots.first?.height != h else { return }
        func make(_ format: MTLPixelFormat, _ shared: Bool) -> MTLTexture {
            let t = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: w, height: h, mipmapped: false)
            t.usage = [.shaderRead, .shaderWrite]
            t.storageMode = shared ? .shared : .private
            return device.makeTexture(descriptor: t)!
        }
        frame = 0                       // nothing to glow after
        dots = (0..<3).map { _ in make(.rgba8Unorm, true) }
        light = (0..<2).map { _ in make(.rgba16Float, false) }
        blur = (0..<2).map { _ in make(.rgba16Float, false) }
    }

    func draw(_ c: DotCanvas, to drawable: CAMetalDrawable, _ look: Look) { _ = draw(c, into: drawable.texture, look, drawable) }

    @discardableResult
    func draw(_ c: DotCanvas, into target: MTLTexture, _ look: Look, _ drawable: CAMetalDrawable? = nil) -> MTLCommandBuffer? {
        free.wait()
        sized(c.width, c.height)
        let up = dots[frame % 3], before = light[frame % 2], now = light[(frame + 1) % 2]
        up.replace(region: MTLRegionMake2D(0, 0, c.width, c.height), mipmapLevel: 0, withBytes: c.dots, bytesPerRow: c.width * 4)
        frame += 1
        guard let b = queue.makeCommandBuffer() else { free.signal(); return nil }
        var look = look
        if frame <= 2 { look.decay = 0 }
        let grid = MTLSize(width: c.width, height: c.height, depth: 1)
        if let e = b.makeComputeCommandEncoder() {
            func pass(_ p: MTLComputePipelineState, _ textures: [MTLTexture]) {
                e.setComputePipelineState(p)
                for (i, t) in textures.enumerated() { e.setTexture(t, index: i) }
                e.dispatchThreads(grid, threadsPerThreadgroup: MTLSize(width: p.threadExecutionWidth, height: max(1, p.maxTotalThreadsPerThreadgroup / p.threadExecutionWidth / 4), depth: 1))
            }
            e.setBytes(&look, length: MemoryLayout<Look>.stride, index: 0)
            pass(afterglow, [up, before, now])
            pass(across, [now, blur[0]])
            pass(down, [blur[0], blur[1]])
            e.endEncoding()
        }
        let r = MTLRenderPassDescriptor()
        r.colorAttachments[0].texture = target
        r.colorAttachments[0].loadAction = .dontCare
        r.colorAttachments[0].storeAction = .store
        if let e = b.makeRenderCommandEncoder(descriptor: r) {
            e.setRenderPipelineState(screen)
            e.setFragmentTexture(now, index: 0)
            e.setFragmentTexture(blur[1], index: 1)
            e.setFragmentBytes(&look, length: MemoryLayout<Look>.stride, index: 0)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }
        if let drawable { b.present(drawable) }
        b.addCompletedHandler { [free] _ in free.signal() }
        b.commit()
        return b
    }
}
