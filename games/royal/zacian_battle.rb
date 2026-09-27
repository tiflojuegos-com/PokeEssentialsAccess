# Royal's Zacian battle (switch BATALLA_ZACIAN, 84): the foe's databox and DBK battler panel paint "??" for its
# level, so it is said as unknown.
module PokeAccess
  module RoyalZacianBattle
    SWITCH = 84

    # True for a foe while the special battle's switch is on.
    def self.hidden?(b)
      ($game_switches[SWITCH] rescue false) && ((b.opposes?(0) rescue false) || (b.index.odd? rescue false)) ? true : false
    end
  end
end

PokeAccess::Game.define("royal") do
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    PokeAccess::RoyalZacianBattle.hidden?(args[0]) ? PokeAccess::I18n.t(:bt_level_unknown) : original.call
  end
  override("PokeAccess::DBKBattlerInfo", :panel_level) do |_mod, original, args|
    PokeAccess::RoyalZacianBattle.hidden?(args[0]) ? :unknown : original.call
  end
end
