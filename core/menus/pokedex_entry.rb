module PokeAccess
  # The browsable Pokedex entry scene draws everything as graphics, so nothing reaches the generic
  # readers. This file covers the gen-6 split scenes (PokemonPokedexScene info, PokedexFormScene forms,
  # PokemonNestMapScene area); the modern single-scene PokemonPokedexInfo_Scene is read by
  # PokedexInfoV21 (core/battle/v21). Each hook below no-ops on the other engine (the class is undefined).
  module DexEntry
    # --- gen-6: PokemonPokedexScene (info), PokedexFormScene (forms), PokemonNestMapScene (area) ---

    # Info page + species navigation: reads the dummy pokemon the scene just configured.
    def self.gen6_info(scene)
      pk = PokeAccess.ivar(scene, :@dummypokemon)
      return unless pk
      sp = (pk.species rescue nil)
      nm = (PokeAccess::Data.species_name(sp) || sp.to_s)
      parts = [nm, PokeAccess::I18n.t(:dex_category, :cat => (pk.kind rescue ""))]
      if ($Trainer && $Trainer.owned[sp] rescue false)
        parts.push(PokeAccess::I18n.t(:dex_height, :h => PokeAccess::Pokedex.fmt_float((pk.height rescue 0) / 10.0)))
        parts.push(PokeAccess::I18n.t(:dex_weight, :w => PokeAccess::Pokedex.fmt_float((pk.weight rescue 0) / 10.0)))
        e = (pk.dexEntry rescue nil)
        parts.push(PokeAccess.clean(e)) if e && !e.to_s.empty?
      end
      PokeAccess.speak(PokeAccess::Util.join_parts(parts), true)
    rescue StandardError
      nil
    end

    # The screen paints the SPECIES name above the form line, and the list loop rebuilds this scene per
    # species -- so without the species a player walking the dex from here never learns which entry each
    # "Forma: Macho" belongs to.
    def self.choosing_form!(v); @choosing_form = v; end

    def self.gen6_form(scene)
      return if @choosing_form
      g = PokeAccess.ivar(scene, :@gender); f = PokeAccess.ivar(scene, :@form)
      av = (scene.instance_variable_get(:@available) rescue [])
      hit = (av.find { |i| i[1] == g && i[2] == f } rescue nil)
      return unless hit
      sp = PokeAccess.ivar(scene, :@species)
      nm = (PBSpecies.getName(sp) rescue nil) if sp
      t = PokeAccess::Util.join_parts([nm, PokeAccess::I18n.t(:dex_form, :form => hit[0])])
      PokeAccess.speak(t, true) unless t.empty?
    rescue StandardError
      nil
    end

    # Read by CAPTURE during pbStartScene: the bottom bar paints map name, location, the nest species line
    # and -- when the region holds none -- its no-nests label, all through pbDrawTextPositions, so the
    # captured rows say the right words in every per-language build. Each setter repaints the whole bar,
    # so rows repeat and uniq keeps one copy in first-paint order. Composing off the ivars is the fallback
    # for a copy that painted nothing.
    def self.gen6_area(scene, rows)
      t = rows.is_a?(Array) ? rows.uniq.join(", ") : ""
      if t.strip.empty?
        mb = PokeAccess.sprite(scene, "mapbottom")
        return unless mb
        loc = (mb.maplocation rescue nil)
        det = (mb.instance_variable_get(:@mapdetails) rescue nil)
        t = PokeAccess::Util.join_parts([loc, det])
      end
      PokeAccess.speak_clean(t, true) unless t.strip.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonPokedexScene", :pbChangeToDexEntry) { |s, _r, _a| PokeAccess::DexEntry.gen6_info(s) }
PokeAccess::Hooks.after_hook("PokedexFormScene", :pbRefresh) { |s, _r, _a| PokeAccess::DexEntry.gen6_form(s) }

# The form chooser's command window is a LOCAL, read by the generic hook; while it is up the page reader
# stands down so each form is voiced once.
PokeAccess::Hooks.around_hook("PokedexFormScene", :pbChooseForm, :optional => true) do |_s, nxt, _a|
  PokeAccess::DexEntry.choosing_form!(true)
  begin
    nxt.call
  ensure
    PokeAccess::DexEntry.choosing_form!(false)
  end
end
PokeAccess::Hooks.before_hook("PokemonNestMapScene", :pbStartScene) do |_s, _a|
  PokeAccess::PaintCapture.arm(:nest_area)
end
PokeAccess::Hooks.after_hook("PokemonNestMapScene", :pbStartScene) do |s, _r, _a|
  PokeAccess::DexEntry.gen6_area(s, PokeAccess::PaintCapture.take(:nest_area))
end
