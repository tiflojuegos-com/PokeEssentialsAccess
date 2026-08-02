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
      PokeAccess.speak(parts.compact.join(". "), true)
    rescue StandardError
      nil
    end

    def self.gen6_form(scene)
      g = PokeAccess.ivar(scene, :@gender); f = PokeAccess.ivar(scene, :@form)
      av = (scene.instance_variable_get(:@available) rescue [])
      hit = (av.find { |i| i[1] == g && i[2] == f } rescue nil)
      PokeAccess.speak(PokeAccess::I18n.t(:dex_form, :form => hit[0]), true) if hit
    rescue StandardError
      nil
    end

    def self.gen6_area(scene)
      mb = PokeAccess.sprite(scene, "mapbottom")
      return unless mb
      loc = (mb.maplocation rescue nil); det = (mb.mapdetails rescue nil)
      t = [loc, det].compact.reject { |s| s.to_s.empty? }.join(". ")
      PokeAccess.speak(t, true) unless t.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonPokedexScene", :pbChangeToDexEntry) { |s, _r, _a| PokeAccess::DexEntry.gen6_info(s) }
PokeAccess::Hooks.after_hook("PokedexFormScene", :pbRefresh) { |s, _r, _a| PokeAccess::DexEntry.gen6_form(s) }
PokeAccess::Hooks.after_hook("PokemonNestMapScene", :pbStartScene) { |s, _r, _a| PokeAccess::DexEntry.gen6_area(s) }
