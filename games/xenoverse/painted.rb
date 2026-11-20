module PokeAccess
  # The text Xenoverse's sprite screens paint, kept per bitmap: they draw labels once onto bitmaps they show later
  # (buttons, option bars, quantity boxes, a selected row), and their readers look them up by the bitmap in sight.
  # What one frame paints onto a bitmap replaces what an earlier frame left there.
  module XenoversePainted
    LIMIT = 300
    @rows = {}

    # Keeps strings painted onto a bitmap, after what the same frame already painted there.
    def self.keep(bitmap, strings)
      return if bitmap.nil? || strings.empty?
      @rows.clear if @rows.length > LIMIT
      frame = (Graphics.frame_count rescue 0)
      entry = @rows[bitmap.object_id]
      if entry && entry[0].equal?(bitmap) && entry[1] == frame
        entry[2].concat(strings)
      else
        @rows[bitmap.object_id] = [bitmap, frame, strings]
      end
    end

    # The rows of a pbDrawTextPositions call as the strings they paint.
    def self.positions(args)
      rows = args[1]
      return [] unless rows.is_a?(Array)
      rows.select { |r| r.is_a?(Array) && r[0].is_a?(String) }.map { |r| r[0] }
    end

    # The cleaned strings last painted onto a bitmap, in painting order; [] for none.
    def self.of(bitmap)
      entry = bitmap ? @rows[bitmap.object_id] : nil
      return [] unless entry && entry[0].equal?(bitmap)
      entry[2].map { |s| PokeAccess.clean(s.to_s) }.reject { |s| s.empty? }
    end

    # The strings painted onto a sprite's bitmap.
    def self.of_sprite(sprite)
      sprite ? of((sprite.bitmap rescue nil)) : []
    end

    # A hint naming each painted label with the key the screen pictures beside it, for the key hints.
    # param pairs [label, button, the letter painted for it] for each label to name
    def self.hint(pairs)
      lines = pairs.reject { |p| p[0].to_s.empty? }.map do |label, button, letter|
        PokeAccess::I18n.t(:xenoverse_named, :name => PokeAccess::KeyHints.key(button, letter), :text => label)
      end
      PokeAccess.sentences(lines)
    end

    # The line with the hint after it while key hints are said.
    def self.with_hint(text, pairs)
      hint = hint(pairs)
      hint.empty? ? text : PokeAccess::Verbosity.with_hint(text, hint)
    end

    # Forgets everything kept, as a screen closes.
    def self.forget
      @rows.clear
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  kernel("pbDrawTextPositions", :after) do |args, _r|
    PokeAccess::XenoversePainted.keep(args[0], PokeAccess::XenoversePainted.positions(args))
  end
  kernel("drawTextExH", :after) do |args, _r|
    PokeAccess::XenoversePainted.keep(args[0], [args[5].to_s]) if args[5].is_a?(String)
  end
end
