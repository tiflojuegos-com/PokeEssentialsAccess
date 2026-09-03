# One armed collector for capture-the-paint readers: arm a tag before the game paints, the global wraps
# collect every painted string, take() returns them in paint order. Reading the paint keeps a reader
# correct across per-language builds (the same game compiled with its literals swapped). Screens are
# modal, so a single armed tag at a time: arming replaces any stale one.
module PokeAccess
  module PaintCapture
    def self.arm(tag)
      @tag = tag
      @rows = []
    end

    def self.note(text)
      return if @tag.nil?
      t = text.to_s
      @rows.push(t) unless t.strip.empty?
    rescue StandardError
      nil
    end

    def self.note_positions(rows)
      return if @tag.nil? || !rows.is_a?(Array)
      rows.each { |r| note(r[0]) if r.is_a?(Array) }
    rescue StandardError
      nil
    end

    # True while tag is armed and at least one row has landed (the burst a frame poll waits for).
    def self.pending?(tag)
      @tag == tag && !@rows.empty?
    end

    # The collected rows if tag is the armed one (disarming), else nil.
    def self.take(tag)
      return nil unless @tag == tag
      rows = @rows
      @tag = nil
      @rows = []
      rows
    end

    # The captured rows as one spoken line: uniq (screens repaint their labels), joined with ", ", cleaned.
    def self.text(rows)
      rows.is_a?(Array) ? PokeAccess.clean(rows.uniq.join(", ")).to_s.strip : ""
    end

    # The common capture reader in one call: arms tag, runs the block (the game's paint), then speaks what
    # landed, or nothing when the screen painted no words. Returns the block's value.
    def self.speak_around(tag, interrupt)
      arm(tag)
      begin
        yield
      ensure
        t = text(take(tag))
        PokeAccess.speak(t, interrupt) unless t.empty?
      end
    end

    # The frame-poll twin of speak_around for a tag armed before a blocking loop: speaks the rows once a
    # burst has landed, leaving the tag disarmed until the next arm.
    def self.flush_pending(tag, interrupt)
      return unless pending?(tag)
      t = text(take(tag))
      PokeAccess.speak(t, interrupt) unless t.empty?
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "paint_capture_positions", :before) do |args, _r|
  PokeAccess::PaintCapture.note_positions(args[1])
end
PokeAccess::Hooks.wrap_kernel("drawTextEx", "paint_capture_dtex", :before) do |args, _r|
  PokeAccess::PaintCapture.note(args[5])
end
