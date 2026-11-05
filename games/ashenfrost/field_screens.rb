# What Ashen Frost adds to stock screens and the map: the region map's sheets (009_UI_RegionMap.rb, one group of regions on
# several maps, swapped with JUMPUP and JUMPDOWN), the bag's sorting (007_UI_Bag.rb) and the protagonist it switches to
# (Multiple Protagonists, pbSwitchCharacter), which only its sprite shows.
module PokeAccess
  module AshenField
    # The sheet the map swapped to, by the name its bottom bar paints, behind the square its swap said.
    def self.sheet_swapped(scene)
      name = PokeAccess.clean(PokeAccess.ivar(PokeAccess.sprite(scene, "mapbottom"), :@mapname).to_s)
      PokeAccess.speak(name, false) unless name.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The keys that swap the map's sheets, once as it opens, where this group of regions has more than one.
    def self.sheet_hint(scene)
      return unless PokeAccess.sprite(scene, "switcher") && PokeAccess::Verbosity.hints?
      PokeAccess.speak(PokeAccess::I18n.t(:ashen_map_sheets, :up => PokeAccess::KeyHints.key(:x, "A"),
                                                             :down => PokeAccess::KeyHints.key(:y, "S")), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The key that sorts the bag, once as it opens: the screen paints F, and its button, AUX2, is on W.
    def self.bag_hint
      return unless PokeAccess::Verbosity.hints?
      PokeAccess.speak(PokeAccess::I18n.t(:ashen_bag_sort, :key => PokeAccess::KeyHints.key(:r, "W")), false)
    end

    # The protagonist the game has just switched to, queued behind what its event says; a call on the one in play does nothing.
    def self.switched(was)
      return if ($player.character_ID rescue nil) == was
      name = ($player.name rescue nil).to_s
      PokeAccess.speak(PokeAccess::I18n.t(:ashen_now_playing, :name => name), false) unless name.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  # The swap asks for the square under the cursor again, whose reader says it only if it counts as new; a container so.
  before("PokemonRegionMap_Scene", :swap_maps) { |scene, _args| PokeAccess::Cursor.reset(scene, :region_map) }
  after("PokemonRegionMap_Scene", :swap_maps, :hook_container => true) do |scene, _ret, _args|
    PokeAccess::AshenField.sheet_swapped(scene)
  end
  after("PokemonRegionMap_Scene", :pbStartScene, :hook_container => true) do |scene, _ret, _args|
    PokeAccess::AshenField.sheet_hint(scene)
  end

  # Its quest journal (003_Quest_UI.rb) paints nothing where the plugin paints a hidden reward.
  override("PokeAccess::QuestUI", :other_lines) do |_mod, original, _args|
    hidden = PokeAccess::I18n.t(:quest_reward, :what => PokeAccess::I18n.t(:quest_hidden))
    original.call.reject { |line| line == hidden }
  end

  after("PokemonBag_Scene", :pbStartScene, :hook_container => true) { |_scene, _ret, _args| PokeAccess::AshenField.bag_hint }
  after("PokemonBag", :sort_pocket_alphabetically) do |_bag, _ret, _args|
    PokeAccess.speak(PokeAccess::I18n.t(:ashen_bag_sorted), true)
  end

  # The pause menu's Controls opens mkxp-z's own window (System.show_settings), which only a mouse can use.
  PokeAccess::Hooks.wrap_singleton("System", :show_settings, "ashen_controls", :before) do |_args, _r|
    PokeAccess.speak(PokeAccess::I18n.t(:ashen_controls_window), true)
  end

  kernel("pbSwitchCharacter", :around) do |_args, nxt|
    was = ($player.character_ID rescue nil)
    ret = nxt.call
    PokeAccess::AshenField.switched(was)
    ret
  end
end
