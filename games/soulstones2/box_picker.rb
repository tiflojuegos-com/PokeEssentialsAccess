# The multi-box picker (PokemonBox_Scene, this game's Multi-Box Modifier): a grid of thirty boxes walked
# with an arrow sprite and nothing else. pbUpdateOverlay repaints the focused box's name, count and set on
# every move, so the line is captured from that paint; only its first batch is the focus, the second is the
# two set-switch buttons and would repeat on every step.
module PokeAccess
  module SS2BoxPicker
    # Row positions inside the focus batch, in the order the screen pushes them.
    HOLDS = 0
    SET   = 2
    NAME  = 4
    FOCUS_ROWS = 5

    # The focused box: name and count, with the set of thirty prepended only when it just changed.
    def self.say(scene)
      rows = PokeAccess::PaintCapture.take(:ss2_boxpick, :positions)
      return if rows.nil? || rows.length < FOCUS_ROWS
      name = rows[NAME].to_s.strip
      holds = rows[HOLDS].to_s.strip
      set = rows[SET].to_s.strip
      return if name.empty?
      parts = [name]
      parts.push(holds) unless holds.empty?
      parts.push(set) if !set.empty? && PokeAccess::Cursor.changed?(scene, :ss2_boxset, set)
      line = parts.join(", ")
      return unless PokeAccess::Cursor.changed?(scene, :ss2_boxpick, line)
      PokeAccess.speak_clean(line, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("PokemonBox_Scene", :pbUpdateOverlay, :optional => true) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:ss2_boxpick)
    begin
      nxt.call
    ensure
      PokeAccess::SS2BoxPicker.say(scene)
    end
  end
end
