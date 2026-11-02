# Edas' field moves (0105_PField_HiddenMoves): its Kernel.pbCut takes any of five moves, and its Kernel.pbSurf never
# surfs: facing water, the action key turns the player into a vampire who floats over it, the bike's mode with the
# Blood Medallion (BICYCLE) in the bag, which asks for no badge and no move. It refuses on NO_SURF_MAPS (0228_Finales)
# and while anyone walks along as a dependent event. Surfing itself stays for a Pokemon that knows it, from the party.
module PokeAccess
  module EdasFieldMoves
    CUT_MOVES = [:CUT, :SLASH, :LEAFBLADE, :NIGHTSLASH, :CUCHILLADAASTRAL]

    @floating = false

    # Whether a party Pokemon knows a move that cuts, by the finder Kernel.pbCut asks; nil when it cannot be asked.
    def self.knows_cut?
      return nil unless Kernel.respond_to?(:pbCheckMove)
      CUT_MOVES.any? { |move| Kernel.pbCheckMove(move) } ? true : false
    end

    # True on the maps whose water the action key does nothing on.
    def self.no_surf_map?
      maps = PokeAccess.const_at("NO_SURF_MAPS")
      maps.is_a?(Array) && maps.include?(($game_map.map_id rescue nil))
    end

    # True while the player floats as a vampire: the water ahead is no longer anything to start on.
    def self.floating?
      ($PokemonGlobal.bicycle rescue false) ? true : false
    end

    # Says the form the player is left in as the bike's mode changes, whatever changes it (the action key, the
    # medallion, a map with no bike, a gem's flight): nothing else tells floating from walking but the sprite and the music.
    def self.poll
      now = floating?
      return if now == @floating
      @floating = now
      PokeAccess.speak(PokeAccess::I18n.t(now ? :edas_vampire_on : :edas_vampire_off), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("edas") do
  field_move_item(:SURF, :BICYCLE)
  surf_company(:dependents)

  override("PokeAccess::FieldMoves", :knows?) do |_mod, original, args|
    args[0] == :CUT ? PokeAccess::EdasFieldMoves.knows_cut? : original.call
  end
  override("PokeAccess::FieldMoves", :item_ready?) do |_mod, original, args|
    args[0] == :SURF && PokeAccess::EdasFieldMoves.no_surf_map? ? false : original.call
  end
  override("PokeAccess::Surfaces", :water_ahead_kind) do |_mod, original, _args|
    PokeAccess::EdasFieldMoves.floating? ? nil : original.call
  end
  poll_each_frame { PokeAccess::EdasFieldMoves.poll }
end
