module PokeAccess
  # Royal paints the key its own F1 menu gives each button (KeybindingReader, "[Z] Restablecer valores"), so the
  # hint letters are asked of that reader rather than taken from RPG Maker XP's defaults.
  module RoyalKeys
    # The standard buttons by the names KeybindingReader takes, and the mod's action for each.
    BUTTONS = { :ACTION => :a, :BACK => :b, :USE => :c, :JUMPUP => :x, :JUMPDOWN => :y, :SPECIAL => :z,
                :AUX1 => :l, :AUX2 => :r }

    # Each button's painted key and its action, or nil when the game's reader answers nothing.
    def self.letters
      out = {}
      BUTTONS.each do |name, sym|
        k = (::KeybindingReader.key_name(name) rescue nil).to_s
        out[k] = sym unless k.empty? || k == "?" || out.key?(k)
      end
      out.empty? ? nil : out
    end
  end
end

PokeAccess::Game.define("royal") do
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
  override("PokeAccess::KeyHints", :table) { |_m, original, _a| PokeAccess::RoyalKeys.letters || original.call }
end
