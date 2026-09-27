# The HGSS Dex List (Eternal Emerald): each square says owned, only seen or unknown, shiny where the number is gold,
# and the number it paints (one lower in an offset dex).
Suite.define("hgss dex list: a square says owned or only seen, gold for shiny, and the number it paints") do
  hd = PokeAccess::HGSSDexList
  had_player = $player
  had_const = defined?(PokedexListSprite) ? true : false
  begin
    Object.const_set(:PokedexListSprite, Class.new) unless had_const
    PokedexListSprite.const_set(:USE_GOLD_NUMBER_FOR_SHINY, true) unless PokedexListSprite.const_defined?(:USE_GOLD_NUMBER_FOR_SHINY)
    dex = Object.new
    def dex.last_form_seen(sp); sp == 1 ? [0, 0, true] : [0, 0, false]; end
    player = Object.new
    player.instance_variable_set(:@dex, dex)
    def player.pokedex; @dex; end
    def player.seen?(sp); sp != 3; end
    def player.owned?(sp); sp == 1; end
    $player = player
    spr = Struct.new(:dexlist, :index).new([{ :species => 1, :number => 1 }, { :species => 2, :number => 5, :shift => true },
                                            { :species => 3, :number => 9 }], 0)
    caught = PokeAccess::I18n.t(:dex_caught)
    eq "an owned species last seen shiny: the ball and the gold number", hd.text(spr),
       [PokeAccess::I18n.t(:dexlist_entry, :num => 1, :name => PBSpecies.getName(1)), caught,
        PokeAccess::I18n.t(:pk_shiny)].join(", ")
    spr.index = 1
    eq "one only seen, with the number the square paints (one lower in an offset dex)", hd.text(spr),
       [PokeAccess::I18n.t(:dexlist_entry, :num => 4, :name => PBSpecies.getName(2)), PokeAccess::I18n.t(:dex_seen)].join(", ")
    spr.index = 2
    eq "and one never seen stays a silhouette", hd.text(spr), PokeAccess::I18n.t(:dexlist_unknown, :num => 9)
    eq "which the info key says too", PokeAccess::Info.info_text, PokeAccess::I18n.t(:dexlist_unknown, :num => 9)

    spr.index = 0
    head = PokeAccess::I18n.t(:dexlist_entry, :num => 1, :name => PBSpecies.getName(1))
    rows = vb_levels { hd.text(spr) }
    eq "brief: the number and the name", rows[0], head
    eq "medium: and whether it is caught", rows[1], [head, caught].join(", ")
    PokeAccess::Config.verbosity = :brief
    hd.text(spr)
    PokeAccess::Config.verbosity = :full
    eq "the info key keeps the gold number's shiny mark", PokeAccess::Info.info_text, rows[2]
  ensure
    $player = had_player
    Object.send(:remove_const, :PokedexListSprite) unless had_const
  end
end
