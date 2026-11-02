# Perseida's battle box (0267_NewBattle_UI): a boss's, battler 1 under NO_CAPTURES_SWITCH, draws no sex sign; the three
# beasts paint "Nv. ???" until their stories reveal them; the sign icon marks an awakened star power; and some marks are no
# file it draws through pbDrawImagePositions: the boss's own box, the colour of a shiny or magnific name and the Shadow row
# of its status strip.
module PokeAccess
  module PerseidaBattleBox
    # The beasts whose level the box hides, each with the variable that shows it from REVEALED on (0150_PScreen_RoamingMap).
    BEASTS = [[:ENTEI, "VARENTEI"], [:SUICUNE, "VARSUICUNE"], [:RAIKOU, "VARRAIKOU"]]
    REVEALED = 5
    NAME_SHINY = "perseida_name_shiny"
    NAME_MAGNIFIC = "perseida_name_magnific"
    STATUS_SHADOW = "perseida_status_shadow"
    BOSS_BOX = "perseida_boss_box"

    # Whether the battler is the boss whose box leaves out its sex and level.
    def self.boss?(b)
      ($game_switches[NO_CAPTURES_SWITCH] rescue false) && (b.index rescue nil) == 1 ? true : false
    end

    # Whether the box paints "Nv. ???" for the battler.
    def self.hidden_level?(b)
      species = (b.pokemon.species rescue nil)
      return false if species.nil? || boss?(b)
      BEASTS.any? do |name, var|
        (isConst?(species, PBSpecies, name) rescue false) && $game_variables[PokeAccess.const_at(var)].to_i < REVEALED
      end
    end

    # A box's icons with those its marks stand for that it paints some other way, as Battle.marks_of reads them.
    def self.with_painted(box, icons)
      b = PokeAccess.ivar(box, :@battler)
      (icons || []) + [boss?(b) ? BOSS_BOX : nil, name_colour(b), (b.isShadow? rescue false) ? STATUS_SHADOW : nil].compact
    end

    # The mark of the colour the box paints the battler's name in, the shiny's first.
    def self.name_colour(b)
      return NAME_SHINY if (b.isShiny? rescue false)
      (b.isMagnific? rescue false) ? NAME_MAGNIFIC : nil
    end
  end
end

PokeAccess::Battle.icon_mark(/\AbattleSignBox\z/i, :perseida_blessed)
PokeAccess::Battle.icon_mark(/\Aperseida_name_shiny\z/, :pk_shiny)
PokeAccess::Battle.icon_mark(/\Aperseida_name_magnific\z/, :perseida_magnific)
PokeAccess::Battle.icon_mark(/\Aperseida_status_shadow\z/, :perseida_mark_shadow)
PokeAccess::Battle.icon_mark(/\Aperseida_boss_box\z/, :ss2_adv_boss)

PokeAccess::Game.define("perseida") do
  override("PokeAccess::Battle", :shown_sex) do |_mod, original, args|
    PokeAccess::PerseidaBattleBox.boss?(args[0]) ? "" : original.call
  end
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    PokeAccess::PerseidaBattleBox.hidden_level?(args[0]) ? PokeAccess::I18n.t(:bt_level_unknown) : original.call
  end
  override("PokeAccess::Battle", :note_marks) do |_mod, original, args|
    args[1] = PokeAccess::PerseidaBattleBox.with_painted(args[0], args[1])
    original.call
  end
end
