module PokeAccess
  # The Ekans snake minigame, SETUP MENU only.
  #
  # The menu is an ordinary vertical list -- @index over @options, redrawn by draw on every move and on every
  # value change -- but it belongs to a class that inherits from nothing, so the generic window reader never
  # had a chance at it. Each row is a Symbol, and the plugin resolves it to a label and a right-hand value
  # through Ekans_Game.option_name and .rhs_text, which is where both halves of a row come from.
  #
  # The GAME itself is deliberately not covered here. It is real-time and needs a narration model of its own
  # -- what to announce and how often, without drowning the player -- rather than a focus reader, and doing
  # that badly is worse than leaving it silent.
  module EkansSnake
    def self.row(scene)
      opts = PokeAccess.ivar(scene, :@options)
      i = PokeAccess.ivar(scene, :@index)
      return unless opts.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < opts.length
      c = opts[i]
      name = PokeAccess.clean((Ekans_Game.option_name(c) rescue "").to_s).to_s.strip
      return if name.empty?
      value = PokeAccess.clean((Ekans_Game.rhs_text(c) rescue "").to_s).to_s.strip
      text = value.empty? ? name : "#{name}, #{value}"
      PokeAccess::Cursor.announce(scene, :ekans_row, [i, value], true) { text }
    rescue StandardError
      nil
    end
  end
end

# draw runs when the menu opens and on every cursor move or value change, so it covers the opening read and
# both kinds of change. The value is part of the dedup key: changing a setting leaves the cursor where it is.
PokeAccess::Hooks.after_hook("Ekans_Interface_Main", :draw, :optional => true) do |scene, _r, _a|
  PokeAccess::EkansSnake.row(scene)
end
