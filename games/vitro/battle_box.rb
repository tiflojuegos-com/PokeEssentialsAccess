# Vitro's battle box (0101_PokeBattle_SceneDatabox): a boss's, battler 1 under NO_CAPTURES_SWITCH, draws no sex sign and no
# level; and some marks are no file it draws through pbDrawImagePositions: the boss's own box, the colour of a shiny's name and
# the Shadow row of its status strip. Its lives are dead code (the "if false" of its initialize).
module PokeAccess
  module VitroBattleBox
    NAME_SHINY = "vitro_name_shiny"
    STATUS_SHADOW = "vitro_status_shadow"
    BOSS_BOX = "vitro_boss_box"

    # Whether the battler is the boss whose box leaves out its sex and level.
    def self.boss?(b)
      $game_switches[NO_CAPTURES_SWITCH] && b.index == 1 ? true : false
    end

    # A box's icons with those its marks stand for that it paints some other way, as Battle.marks_of reads them; it runs
    # inside the box's refresh, which an error of its own must not reach.
    def self.with_painted(box, icons)
      b = PokeAccess.ivar(box, :@battler)
      icons + [boss?(b) ? BOSS_BOX : nil, b.isShiny? ? NAME_SHINY : nil, b.isShadow? ? STATUS_SHADOW : nil].compact
    rescue StandardError => e
      PokeAccess.swallowed(e)
      icons
    end
  end
end

PokeAccess::Battle.icon_mark(/\Avitro_boss_box\z/, :ss2_adv_boss)
PokeAccess::Battle.icon_mark(/\Avitro_name_shiny\z/, :pk_shiny)
PokeAccess::Battle.icon_mark(/\Avitro_status_shadow\z/, :perseida_mark_shadow)

PokeAccess::Game.define("vitro") do
  override("PokeAccess::Battle", :shown_sex) do |_mod, original, args|
    PokeAccess::VitroBattleBox.boss?(args[0]) ? "" : original.call
  end
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    PokeAccess::VitroBattleBox.boss?(args[0]) ? nil : original.call
  end
  override("PokeAccess::Battle", :note_marks) do |_mod, original, args|
    args[1] = PokeAccess::VitroBattleBox.with_painted(args[0], args[1])
    original.call
  end
end
