# What stands on Vitro's maps, which core would say by the event's editor name or file under people, each checked on the maps.
# A Torbellino, on the water, is one page with nothing to run and no script or event clears it: a wall three tiles wide
# (sizeC, which the passability probe asks the engine). An Agujero is a walk-on transfer to the floor below, which core would
# call an exit. A Holed boulder shows where a boulder fell from above (rock_holes.rb). A torch with glowswitch(A) in its name is
# lit by common event 31, which turns its self switch A on through pbUseEmber (0318_MO Mejoradas), and nothing but its light
# depends on it (0338_Dark Maps). A CaveMon is a dust cloud that fights when touched, turned into a Pokemon as the scene starts
# (wild_map.rb). A Poke 0 or Poke 1, in the Day Care and its yard, wears the sprite of the Pokemon left there (pbDaycareGraphic in
# 0360_Poke Ranch, with each event's slot as the map's script calls it). The rest wear names the scripts read to draw them: aspas
# (0035_Spriteset_Map) says nothing, so they go by their sprite, and the lights and decoration, with nothing to run, stay out of
# the list.
module PokeAccess
  module VitroMapObjects
    # What an event is, by its name less the editor's flags.
    NAMES = { "Torbellino" => :vitro_whirlpool, "Holed boulder" => :vitro_fallen_rock, "Camera" => :vitro_camera,
              "CaveMon" => :vitro_dust_cloud }
    # The Day Care's slot each of its Pokemon events shows.
    DAY_CARE = { "Poke 1" => 0, "Poke 0" => 1 }
    # The sprites of what only stands there.
    OBJECT_SPRITES = /\A(?:Torbellino|Antorcha Madera|Fuego Vela|Turbina|Cartel giratorio|Pilar|Tuberia|Peluches|Armario|barril|CaveMon)/
    # The editor names of lights and decoration.
    DECOR = /\A(?:RegularLight|Deco|Healing balls|Ojos|Wall (?:left|middle|right))\z/
    # The dark maps' metadata (MetadataDarkMap, 0071_MiscData): the Dark Cave's two, Morty's gym and the Whirl Islands' three.
    DARK_MAPS = [29, 32, 35, 98, 100, 101]

    # An event's name less the editor's flags.
    def self.own(ev)
      ev.name.to_s.sub(/\/.*$/, "")
    end

    # A torch by its state, when its name ties its light to self switch A.
    def self.torch(ev)
      return PokeAccess::I18n.t(:vitro_torch) unless ev.name.to_s =~ /glowswitch\(A\)/i
      lit = $game_self_switches[[$game_map.map_id, ev.id, "A"]]
      PokeAccess::I18n.t(lit ? :vitro_torch_lit : :vitro_torch_unlit)
    end

    # The species of the Pokemon a Day Care event shows, or nil.
    def self.day_care(ev)
      slot = DAY_CARE[own(ev)]
      pokemon = slot && $PokemonGlobal.daycare[slot][0]
      pokemon ? PokeAccess::Data.species_name(pokemon.species) : nil
    end

    # What core would not say of an event, or nil to leave it to core.
    def self.name(ev)
      return PokeAccess::Locator.taken_to(ev, PokeAccess::I18n.t(:vitro_hole)) if own(ev) == "Agujero"
      sprite = ev.character_name.to_s
      return torch(ev) if sprite == "Antorcha Madera"
      return PokeAccess::I18n.t(:vitro_doll) if sprite =~ /\APeluches/
      key = NAMES[own(ev)]
      key ? PokeAccess::I18n.t(key) : day_care(ev)
    end

    # True for a light or decoration with nothing to run.
    def self.decor?(ev)
      own(ev) =~ DECOR && !PokeAccess::Locator.has_commands?(ev) ? true : false
    end
  end
end

PokeAccess::Game.define("vitro") do
  event_name { |ev| PokeAccess::VitroMapObjects.name(ev) }
  event_category(:objects) { |ev| ev.character_name.to_s =~ PokeAccess::VitroMapObjects::OBJECT_SPRITES }
  event_hidden { |ev| PokeAccess::VitroMapObjects.decor?(ev) }
  override("PokeAccess::Locator", :placeholder_name?) do |_mod, original, args|
    args[0].to_s =~ /\A(?:aspas|noShadowBoulder)\z/ ? true : original.call
  end
  mechanic(:state, PokeAccess::VitroMapObjects::DARK_MAPS) { arrival_hint :vitro_dark_area }
end
