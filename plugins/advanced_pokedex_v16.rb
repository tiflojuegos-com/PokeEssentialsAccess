# FL's Advanced Pokedex in its v16 version (AdvancedPokedexScene, the entry's fourth page in Essentials BES and
# Desolation, a screen of its own in Pokemon Z): pages of painted info and move lists, turned with the confirm and back
# keys. The entry opens with its name, its types and its first page; each turn says the new page, read as displayPage
# painted it.
module PokeAccess
  module AdvancedPokedexV16
    # One page as displayPage painted it, in paint order (each column top to bottom), after its place among the pages.
    def self.page_text(scene, painted)
      total = PokeAccess.ivar(scene, :@totalPages).to_i
      out = []
      if total > 0 && PokeAccess::Verbosity.keep?(:positions, :medium)
        out.push(PokeAccess::I18n.t(:adv_dex_page, :n => PokeAccess.ivar(scene, :@page), :m => total))
      end
      PokeAccess.sentences(out.concat(painted.map { |t| PokeAccess.clean(t) }))
    end

    # The entry as it opens: the species, its types and the first page, or that it is not caught.
    def self.opening(scene)
      types = [PokeAccess.ivar(scene, :@type1), PokeAccess.ivar(scene, :@type2)].compact.uniq
      names = types.map { |t| PokeAccess::Data.type_name(t) }.compact
      head = [PokeAccess::Data.species_name(PokeAccess.ivar(scene, :@species))]
      unless names.empty?
        head.push(PokeAccess::I18n.t(:pdx_type, :t => PokeAccess::Util.types_phrase(names[0], names[1])))
      end
      PokeAccess.sentences(head.push(PokeAccess.ivar(scene, :@access_page) || PokeAccess::I18n.t(:pdx_not_caught)))
    end
  end
end

PokeAccess::Hooks.on_paint("AdvancedPokedexScene", :displayPage, :optional => true) do |scene, pairs, _a|
  t = PokeAccess::AdvancedPokedexV16.page_text(scene, pairs.map { |p| p[0] })
  if scene.instance_variable_get(:@access_started)
    PokeAccess::Info.set_info(:text, t)
    PokeAccess.speak(t, true)
  else
    scene.instance_variable_set(:@access_page, t)
  end
end

PokeAccess::Hooks.after_hook("AdvancedPokedexScene", :pbStartScene, :optional => true,
                             :hook_container => true) do |scene, _r, _a|
  opening = PokeAccess::AdvancedPokedexV16.opening(scene)
  PokeAccess::Info.set_info(:text, opening)
  PokeAccess.speak(opening, true)
  scene.instance_variable_set(:@access_started, true)
end

PokeAccess::Hooks.clear_info_on("AdvancedPokedexScene", :pbEndScene)
