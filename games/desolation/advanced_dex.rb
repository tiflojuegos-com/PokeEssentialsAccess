# FL's Advanced Pokedex in the version Desolation ships (Scripts/Pokemon Desolation/Advanced Pokedex.rb, the fourth
# page of an entry once switch 912 is on): pages of painted info and move lists, turned with the confirm and back
# keys. The entry opens with its name, types and first page; each turn says the new page.
module PokeAccess
  module DesolationAdvancedDex
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
      head.push(PokeAccess::I18n.t(:pdx_type, :t => PokeAccess::Util.types_phrase(names[0], names[1]))) unless names.empty?
      PokeAccess.sentences(head.push(PokeAccess.ivar(scene, :@access_page) || PokeAccess::I18n.t(:pdx_not_caught)))
    end
  end
end

PokeAccess::Game.define("desolation") do
  around("AdvancedPokedexScene", :displayPage) do |scene, nxt, _a|
    r = nil
    pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
    t = PokeAccess::DesolationAdvancedDex.page_text(scene, pairs.map { |p| p[0] })
    if scene.instance_variable_get(:@access_started)
      PokeAccess.speak(t, true)
    else
      scene.instance_variable_set(:@access_page, t)
    end
    r
  end

  after("AdvancedPokedexScene", :pbStartScene, :hook_container => true) do |scene, _r, _a|
    PokeAccess.speak(PokeAccess::DesolationAdvancedDex.opening(scene), true)
    scene.instance_variable_set(:@access_started, true)
  end
end
