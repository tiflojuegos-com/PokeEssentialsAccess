# Core's lines said in Perseida's own words: what the orange gem clears is thorns (0108_PField_HiddenMoves), the turquoise
# gem sails rather than surfs (0317_Pokemon_Followpoke_Bezier), the bike is a Zaldyelm to ride (PBS/items.txt), the lens is
# the dark gem's power, and its money is shown in Crowns, a hundredth of what it counts (0055_Messages), which is also what
# its messages' \PM says and what \MP and \mp write the unit of; \MG opens the savings window (core's money_window) and writes
# nothing.
module PokeAccess
  module PerseidaWords
    WORDS = { :loc_cut_tree => :perseida_thorns, :surf_ahead => :perseida_sail_ahead,
              :loc_surf_here => :perseida_sail_here, :loc_surf_toward => :perseida_sail_toward,
              :loc_surf_company => :perseida_sail_company, :loc_dismount_here => :perseida_dismount_here,
              :loc_dismount_route => :perseida_dismount_route, :loc_dismount_spot => :perseida_dismount_spot,
              :fs_lens_on => :edas_lens_on, :fs_lens_off => :edas_lens_off }

    # An amount of money as the pause menu and the shop paint it, with the game's own unit.
    def self.crowns(amount)
      "#{sprintf('%g', sprintf('%.2f', amount.to_i / 100.0).to_f)}#{pbGoldUnit(true)}"
    end

    # A message with the codes core's cleaning does not know as pbMessageDisplay takes them: the unit written out, spoken as
    # any other word, and the window's code gone, which the cleaning would take with the start of the next word.
    def self.money_codes(text)
      text.gsub(/\\MP/) { pbGoldUnit(true) }.gsub(/\\mp/) { pbGoldUnit }.gsub(/\\[Mm][Gg]/, "")
    end
  end
end

PokeAccess::Game.define("perseida") do
  override(PokeAccess, :money_text) { |_mod, _original, _args| "#{pbGoldCountDisplay}#{pbGoldUnit}" }
  override(PokeAccess, :clean) do |_mod, original, args|
    args[0] = PokeAccess::PerseidaWords.money_codes(args[0]) if args[0].is_a?(String) && args[0].index("\\")
    original.call
  end
  override("PokeAccess::I18n", :t) do |_mod, original, args|
    key = PokeAccess::PerseidaWords::WORDS[args[0]]
    if key
      PokeAccess::I18n.t(key, args[1])
    else
      args[0] == :tr_money ? PokeAccess::PerseidaWords.crowns(args[1][:n]) : original.call
    end
  end
end
