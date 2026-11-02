# Core's lines said in Edas' own words: its bike is the Blood Medallion's vampire, which floats over water and is what
# starts a way by water while the medallion is in the bag; its lens is the Dark Gem's power; and its quest detail paints
# neither who gave the quest nor where (0133_PScreen_QuestInterface).
module PokeAccess
  module EdasWords
    WORDS = { :loc_dismount_here => :edas_unfloat_here, :loc_dismount_route => :edas_unfloat_route,
              :loc_dismount_spot => :edas_unfloat_spot, :fs_lens_on => :edas_lens_on, :fs_lens_off => :edas_lens_off,
              :qu_detail => :edas_quest_detail }
    FLOAT_WORDS = { :surf_ahead => :edas_float_ahead, :loc_surf_here => :edas_float_here,
                    :loc_surf_toward => :edas_float_toward, :loc_surf_company => :edas_float_company }

    # The key a core line is said with here, or nil for a line the game leaves as it is. Without the medallion, or on a map
    # where the action key does nothing, what takes to the water is a Pokemon's Surf, from the party, and its lines stand.
    def self.key_for(key)
      return WORDS[key] if WORDS[key]
      return nil unless FLOAT_WORDS[key] && PokeAccess::FieldMoves.bag_has?(:BICYCLE)
      PokeAccess::EdasFieldMoves.no_surf_map? ? nil : FLOAT_WORDS[key]
    end
  end
end

PokeAccess::Game.define("edas") do
  override("PokeAccess::I18n", :t) do |_mod, original, args|
    key = PokeAccess::EdasWords.key_for(args[0])
    key ? PokeAccess::I18n.t(key, args[1]) : original.call
  end
end
