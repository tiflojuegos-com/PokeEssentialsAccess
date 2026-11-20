module PokeAccess
  # Xenoverse clears its obstacles with the PokéWES gems (0197): each move works once its gem's switch is on, with no
  # Pokemon asked, and the event that gives the gem turns that switch on (maps 265, 317, 274 and 10). Surf alone also
  # asks the badge BADGEFORSURF names (pbOdysseumN, and PokemonFollow before calling it). Trees are events named EV###
  # that run pbKaiseriumN, rocks run pbPerseumN, boulders go by their name to pbHeracliumN, water to pbOdysseumN.
  module XenoverseFieldMoves
    GEMS = { :CUT => [186, :KAISERIUMN, false], :SURF => [188, :ODYSSEUMN, true],
             :STRENGTH => [189, :HERACLIUMN, false], :ROCKSMASH => [190, :PERSEUMN, false] }

    # Whether the gem for a move was won, and the badge too where the game asks one; nil when the switches cannot be
    # read.
    def self.won?(move)
      switch, _item, badge = GEMS[move]
      v = ($game_switches[switch] rescue nil)
      return nil if v.nil?
      return false unless v
      badge ? PokeAccess::FieldMoves.badge_ok?(move) : true
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  field_gate(/\bpbKaiseriumN\b/, :loc_cut_tree, :KAISERIUMN)

  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    PokeAccess::XenoverseFieldMoves::GEMS[args[0]] ? PokeAccess::XenoverseFieldMoves.won?(args[0]) : original.call
  end
  override("PokeAccess::FieldMoves", :name) do |_mod, original, args|
    gem = PokeAccess::XenoverseFieldMoves::GEMS[args[0]]
    gem ? PokeAccess::FieldMoves.item_name(gem[1]) : original.call
  end
end
