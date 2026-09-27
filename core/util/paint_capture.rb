# Collector for capture-the-paint readers: arm a tag before the game paints, the global wraps collect every
# painted string, take() returns them in paint order. One tag at a time: arming replaces a stale one.
module PokeAccess
  module PaintCapture
    def self.arm(tag)
      @tag = tag
      @rows = []
    end

    # Records one painted string with the call that painted it (the source) and, when given, where (x, y).
    def self.note(text, source = :dtex, x = nil, y = nil)
      return if @tag.nil?
      t = text.to_s
      @rows.push([t, source, x, y]) unless t.strip.empty?
    rescue StandardError
      nil
    end

    def self.note_positions(rows)
      return if @tag.nil? || !rows.is_a?(Array)
      rows.each { |r| note(r[0], :positions, r[1], r[2]) if r.is_a?(Array) }
    rescue StandardError
      nil
    end

    # The texts of take_pairs rows in reading order (by y, then x); rows without a position follow in paint order.
    def self.laid_out(pairs)
      placed = []
      loose = []
      (pairs || []).each_with_index do |r, i|
        if r[2].is_a?(Numeric) && r[3].is_a?(Numeric)
          placed.push([r, i])
        else
          loose.push(r)
        end
      end
      placed.sort_by { |r, i| [r[3], r[2], i] }.map { |r, _i| r[0] } + loose.map { |r| r[0] }
    end

    # take_pairs rows as the lines a page lays out, top to bottom, each height's rows joined left to right; rows
    # without a position are left out, and an optional block filters the rows.
    def self.lines(pairs)
      rows = (pairs || []).select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }
      rows = rows.select { |r| yield(r) } if block_given?
      rows.map { |r| r[3] }.uniq.sort.map do |y|
        rows.select { |r| r[3] == y }.sort_by { |r| r[2] }.map { |r| PokeAccess.clean(r[0]) }.reject { |t| t.empty? }.join(" ")
      end.reject { |l| l.empty? }
    end

    # Rows trimmed, blanks dropped, and each one ending in a colon joined to the next ("Registered: 12").
    def self.pair_labels(rows)
      out = []
      (rows || []).each do |r|
        t = r.to_s.strip
        next if t.empty?
        if !out.empty? && out.last =~ /:\z/
          out[-1] = "#{out.last} #{t}"
        else
          out.push(t)
        end
      end
      out
    end

    # True while tag is armed, rows or not.
    def self.armed?(tag)
      @tag == tag
    end

    # True while tag is armed and at least one row has landed (the burst a frame poll waits for).
    def self.pending?(tag)
      @tag == tag && !@rows.empty?
    end

    # The collected texts if tag is armed, else nil; disarms, so a second call answers nil (take_by_source gives
    # several sources). A source keeps one call's rows: :dtex (drawTextEx), :positions, :formatted.
    def self.take(tag, source = nil)
      return nil unless @tag == tag
      rows = @rows
      @tag = nil
      @rows = []
      rows = rows.select { |r| r[1] == source } if source
      rows.map { |r| r[0] }
    end

    # The collected rows as [text, source, x, y] in paint order (x, y nil when not given), disarming.
    def self.take_pairs(tag)
      return [] unless @tag == tag
      rows = @rows
      @tag = nil
      @rows = []
      rows
    end

    # Every collected row as {source => [text, ...]}, disarming.
    def self.take_by_source(tag)
      return {} unless @tag == tag
      rows = @rows
      @tag = nil
      @rows = []
      out = {}
      rows.each { |r| (out[r[1]] ||= []).push(r[0]) }
      out
    end

    # The captured rows as one spoken line, joined with ", " and cleaned; repeats dropped unless dedup is false
    # (a page that paints the same value in several places on purpose).
    def self.text(rows, dedup = true)
      return "" unless rows.is_a?(Array)
      PokeAccess.clean((dedup ? rows.uniq : rows).join(", "))
    end

    # Arms tag, runs the block (the game's paint) and speaks what landed through KeyHints.gate; returns its value.
    def self.speak_around(tag, interrupt)
      arm(tag)
      begin
        yield
      ensure
        t = text(PokeAccess::KeyHints.gate(take(tag) || []))
        PokeAccess.speak(t, interrupt)
      end
    end

    # The frame-poll twin of speak_around for a tag armed before a blocking loop: speaks the rows once a
    # burst has landed, leaving the tag disarmed until the next arm.
    def self.flush_pending(tag, interrupt)
      return unless pending?(tag)
      t = text(PokeAccess::KeyHints.gate(take(tag) || []))
      PokeAccess.speak(t, interrupt)
    end

    # What the block paints, as take_pairs gives it, under its own tag; a capture already armed is restored after.
    def self.sample
      saved = [@tag, @rows]
      arm(:sample)
      yield
      take_pairs(:sample)
    ensure
      @tag, @rows = saved
    end

    # The strings the block paints with pbDrawShadowText (command-list rows), which armed captures leave out.
    def self.shadow_sample
      saved = @shadow
      @shadow = []
      yield
      @shadow
    ensure
      @shadow = saved
    end

    def self.note_shadow(text)
      @shadow.push(text.to_s) if @shadow
    rescue StandardError
      nil
    end

    # The image paths the block draws through pbDrawImagePositions (its icons), also handed to an enclosing capture.
    def self.icons
      saved = @icons
      @icons = []
      yield
      @icons
    ensure
      mine = @icons
      @icons = saved
      @icons.concat(mine) if @icons && mine
    end

    # The images the block draws through pbDrawImagePositions as [path, x, y, source x, source y] rows in paint
    # order: where each icon sits, and which frame of a strip picture it shows; also handed to an enclosing capture.
    def self.icon_rows
      saved = @icon_rows
      @icon_rows = []
      yield
      @icon_rows
    ensure
      mine = @icon_rows
      @icon_rows = saved
      @icon_rows.concat(mine) if @icon_rows && mine
    end

    def self.note_icons(rows)
      return unless (@icons || @icon_rows) && rows.is_a?(Array)
      rows.each do |r|
        next unless r.is_a?(Array)
        @icons.push(r[0].to_s) if @icons
        @icon_rows.push([r[0].to_s, r[1], r[2], r[3], r[4]]) if @icon_rows
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "paint_capture_positions", :before) do |args, _r|
  PokeAccess::PaintCapture.note_positions(args[1])
end
PokeAccess::Hooks.wrap_kernel("drawTextEx", "paint_capture_dtex", :before) do |args, _r|
  PokeAccess::PaintCapture.note(args[5], :dtex, args[1], args[2])
end

# Formatted paragraphs (drawFormattedTextEx), captured as :formatted.
PokeAccess::Hooks.wrap_kernel("drawFormattedTextEx", "paint_capture_formatted", :before) do |args, _r|
  PokeAccess::PaintCapture.note(args[4], :formatted, args[1], args[2])
end

# Only for shadow_sample, icons and icon_rows, and no-ops outside them.
PokeAccess::Hooks.wrap_kernel("pbDrawShadowText", "paint_capture_shadow", :before) do |args, _r|
  PokeAccess::PaintCapture.note_shadow(args[5])
end
PokeAccess::Hooks.wrap_kernel("pbDrawImagePositions", "paint_capture_icons", :before) do |args, _r|
  PokeAccess::PaintCapture.note_icons(args[1])
end
