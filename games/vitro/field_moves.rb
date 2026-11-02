# Vitro's field moves ask for a Pokemon that could learn the move, known or not: its pbCheckMove (0204_PSystem_Utilities) asks
# isCompatibleWithMove?. The last Kernel.pbCut (0318_MO Mejoradas) takes SLASH, or EMBER offered in its place, and the last
# Kernel.pbSurf (0362_Pokemon_Followpoke_Bezier) takes WATERFALL, refusing while anyone but the following Pokemon walks along;
# Kernel.pbStrength takes STRENGTH or SUPERPOWER and Kernel.pbRockSmash ROCKSMASH (0121_PField_HiddenMoves). None of the four
# asks a badge; pbWaterfall and pbDive stay stock. Its trees and rocks are events named Arbol and Roca, cleared through common
# events (29 and 30), so nothing in their own page calls pbCut or pbRockSmash. Its waterfalls are events named Cascada, crossed
# from their foot or their top by a page that tests pbUseWaterfall (0318_MO Mejoradas), which asks for WATERFALL and no badge.
module PokeAccess
  module VitroFieldMoves
    # The moves each function that asks no badge takes.
    MOVES = { :CUT => [:SLASH, :EMBER], :SURF => [:WATERFALL], :STRENGTH => [:STRENGTH, :SUPERPOWER],
              :ROCKSMASH => [:ROCKSMASH] }
    # What each event of the game's own names is, by its name less the editor's flags.
    LABELS = { "Arbol" => :loc_cut_tree, "Roca" => :loc_rock_smash, "Cascada" => :surf_waterfall }

    # Whether the game rules a move its own way.
    def self.handles?(move)
      MOVES.key?(move)
    end

    # Whether a party Pokemon could use a move handles? answers for, by the finder the game asks; nil when it cannot be asked.
    def self.can?(move)
      return nil unless Kernel.respond_to?(:pbCheckMove)
      MOVES[move].any? { |m| Kernel.pbCheckMove(m) } ? true : false
    end

    # The move the game offers for an obstacle: Ember for the thorns, in a party with no Pokemon for Cut and one for Ember.
    def self.offered(move)
      return move unless move == :CUT && Kernel.respond_to?(:pbCheckMove)
      !Kernel.pbCheckMove(:SLASH) && Kernel.pbCheckMove(:EMBER) ? :EMBER : move
    end

    # Whether everyone walking along is the following Pokemon, the one company its Surf lets through.
    def self.only_the_follower?
      ($PokemonGlobal.dependentEvents || []).all? { |ev| ev.nil? || ev[8] == FOLLOW_EVENTNAME }
    end

    # The label of one of the game's own events still standing, or nil.
    def self.label(ev)
      key = LABELS[(ev.name.to_s rescue "").sub(/\/.*$/, "")]
      key && !PokeAccess::Locator.pageless?(ev) ? key : nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  surf_company(:dependents) { PokeAccess::VitroFieldMoves.only_the_follower? }
  script_condition(/\ApbUseWaterfall\b/) do |_match, _context|
    able = PokeAccess::VitroFieldMoves.can?(:SURF)
    able.nil? ? :unknown : able
  end
  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    PokeAccess::VitroFieldMoves.handles?(args[0]) ? PokeAccess::VitroFieldMoves.can?(args[0]) : original.call
  end
  override("PokeAccess::FieldMoves", :name) do |_mod, original, args|
    args[0] = PokeAccess::VitroFieldMoves.offered(args[0])
    original.call
  end
  override("PokeAccess::Locator", :fieldmove_label) do |_mod, original, args|
    PokeAccess::VitroFieldMoves.label(args[0]) || original.call
  end
end
