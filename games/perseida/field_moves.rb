# Perseida's field moves. Its Kernel.pbCut (0108_PField_HiddenMoves) asks only for the orange gem, its switch, and its
# Kernel.pbSurf (0317_Pokemon_Followpoke_Bezier, the last of three definitions) only for the turquoise gem, refusing on
# NO_SURF_MAPS and while anyone but the following Pokemon walks along; neither asks a move or a badge. Its Kernel.pbRockSmash
# asks for the BRAZALFUERZA in the bag, whatever the party knows. Strength, Waterfall and Dive are stock. Its trees are
# events named Arbol, which fell through a common event (56), so nothing in their own page calls pbCut.
module PokeAccess
  module PerseidaFieldMoves
    GEMS = { :CUT => :JOYA_NARANJA, :SURF => :JOYA_TURQUESA }
    GEM_NAMES = { :CUT => :perseida_gem_orange, :SURF => :perseida_gem_turquoise }

    # Whether the switch of the gem that does a move is on.
    def self.gem_on?(move)
      $game_switches[Object.const_get(GEMS[move])] ? true : false
    end

    # True on the maps whose water the turquoise gem does nothing on.
    def self.no_surf_map?
      NO_SURF_MAPS.include?(($game_map.map_id rescue nil))
    end

    # Whether the game rules a move its own way, by a gem or the bracelet.
    def self.handles?(move)
      GEMS.key?(move) || move == :ROCKSMASH
    end

    # Whether the player can use a move handles? answers for; nil when that cannot be read, which is not a no.
    def self.can?(move)
      return PokeAccess::FieldMoves.bag_has?(:BRAZALFUERZA) if move == :ROCKSMASH
      gem_on?(move) && !(move == :SURF && no_surf_map?)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What clears a move's obstacle as the game calls it: the gem, the bracelet, or nil for a stock move.
    def self.clearer(move)
      return PokeAccess::FieldMoves.item_name(:BRAZALFUERZA) if move == :ROCKSMASH
      GEM_NAMES[move] ? PokeAccess::I18n.t(GEM_NAMES[move]) : nil
    end

    # Whether everyone walking along is the following Pokemon, the one company its Surf lets through.
    def self.only_the_follower?
      ($PokemonGlobal.dependentEvents || []).all? { |ev| ev.nil? || ev[8] == FOLLOW_EVENTNAME }
    end

    # Whether an event is one of the trees the orange gem clears, still standing.
    def self.thorn_tree?(ev)
      (ev.name.to_s rescue "") == "Arbol" && !PokeAccess::Locator.pageless?(ev)
    end
  end
end

PokeAccess::Game.define("perseida") do
  surf_company(:dependents) { PokeAccess::PerseidaFieldMoves.only_the_follower? }
  # Its pbPushThisBoulder and pbPushThisEvent (0311_PMinigame_Fuerza) ask for no Strength, and the action key pulls.
  push_script(/pbPushThisBoulder/)
  pull_script(/pbPushThis(Event|Boulder)/)

  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    PokeAccess::PerseidaFieldMoves.handles?(args[0]) ? PokeAccess::PerseidaFieldMoves.can?(args[0]) : original.call
  end
  override("PokeAccess::FieldMoves", :name) do |_mod, original, args|
    PokeAccess::PerseidaFieldMoves.clearer(args[0]) || original.call
  end
  override("PokeAccess::Locator", :fieldmove_label) do |_mod, original, args|
    PokeAccess::PerseidaFieldMoves.thorn_tree?(args[0]) ? :loc_cut_tree : original.call
  end
end
