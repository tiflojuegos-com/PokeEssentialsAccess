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

    # Records one painted string, remembering WHICH of the engine's two text calls painted it. A screen
    # paints its list rows through pbDrawTextPositions and its own caption through drawTextEx, in whatever
    # order it likes, and a reader after the caption must be able to say so: taking simply "the first row"
    # read out the first ITEM of the item store in every game of the modern era, because the list refreshes
    # before the title is drawn.
    def self.note(text, source = :dtex)
      return if @tag.nil?
      t = text.to_s
      @rows.push([t, source]) unless t.strip.empty?
    rescue StandardError
      nil
    end

    def self.note_positions(rows)
      return if @tag.nil? || !rows.is_a?(Array)
      rows.each { |r| note(r[0], :positions) if r.is_a?(Array) }
    rescue StandardError
      nil
    end

    # True while tag is armed and at least one row has landed (the burst a frame poll waits for).
    def self.pending?(tag)
      @tag == tag && !@rows.empty?
    end

    # The collected rows if tag is the armed one (disarming), else nil. With a source, only the rows that
    # call painted: :dtex for drawTextEx (captions, titles, free paragraphs) and :positions for the
    # pbDrawTextPositions batches (list rows, labelled panels).
    #
    # It DISARMS, so a reader that wants two of the three sources cannot call it twice -- the second call
    # returns nil. take_by_source is for that.
    def self.take(tag, source = nil)
      return nil unless @tag == tag
      rows = @rows
      @tag = nil
      @rows = []
      rows = rows.select { |r| r[1] == source } if source
      rows.map { |r| r[0] }
    end

    # Every collected row at once, as {source => [text, ...]}, disarming. For a screen that says part of
    # itself through one call and part through another: the move panel of one plugin writes its figures in a
    # pbDrawTextPositions batch and the move's description under it with drawTextEx, and both are wanted.
    def self.take_by_source(tag)
      return {} unless @tag == tag
      rows = @rows
      @tag = nil
      @rows = []
      out = {}
      rows.each { |r| (out[r[1]] ||= []).push(r[0]) }
      out
    end

    # The captured rows as one spoken line: uniq (screens repaint their labels), joined with ", ", cleaned.
    def self.text(rows)
      rows.is_a?(Array) ? PokeAccess.clean(rows.uniq.join(", ")) : ""
    end

    # The common capture reader in one call: arms tag, runs the block (the game's paint), then speaks what
    # landed, or nothing when the screen painted no words. Returns the block's value.
    def self.speak_around(tag, interrupt)
      arm(tag)
      begin
        yield
      ensure
        t = text(take(tag))
        PokeAccess.speak(t, interrupt)
      end
    end

    # The frame-poll twin of speak_around for a tag armed before a blocking loop: speaks the rows once a
    # burst has landed, leaving the tag disarmed until the next arm.
    def self.flush_pending(tag, interrupt)
      return unless pending?(tag)
      t = text(take(tag))
      PokeAccess.speak(t, interrupt)
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "paint_capture_positions", :before) do |args, _r|
  PokeAccess::PaintCapture.note_positions(args[1])
end
PokeAccess::Hooks.wrap_kernel("drawTextEx", "paint_capture_dtex", :before) do |args, _r|
  PokeAccess::PaintCapture.note(args[5], :dtex)
end

# The third way a screen paints text: a whole formatted PARAGRAPH, which is where the screens that have
# something to say rather than to label put it -- the summary's trainer memo, the egg's hatch state.
PokeAccess::Hooks.wrap_kernel("drawFormattedTextEx", "paint_capture_formatted", :before) do |args, _r|
  PokeAccess::PaintCapture.note(args[4], :formatted)
end
