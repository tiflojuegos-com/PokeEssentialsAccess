# La Base de Sky's bag extras (anil, royal), as a bag decorator: a machine's number and move name from the mart
# adapter (getDisplayNameMachineName/Number), and the favourite mark (PokemonBag#favourite?); and the key hints the
# bag paints once as it opens ("Z: Ordenar", "D: Buscar").
module PokeAccess
  module SkyBag
    # "TM01 Focus Punch" for a machine, nil for anything else (the vanilla name stands): as in the fork, a plain item,
    # for which both helpers answer its name, is no machine.
    def self.name(ad, itemid)
      return nil unless ad && ad.respond_to?(:getDisplayNameMachineName)
      mn = (ad.getDisplayNameMachineName(itemid) rescue nil).to_s
      num = (ad.getDisplayNameMachineNumber(itemid) rescue nil).to_s
      return nil if mn.empty? || num.empty? || num == mn
      "#{num} #{mn}"
    end

    def self.marks(bag, itemid)
      (bag.respond_to?(:favourite?) && bag.favourite?(itemid)) ? [:mb_favourite] : []
    rescue StandardError
      []
    end

    # A painted key hint of the bag: a key letter (or letters joined by /), a colon and what it does.
    HINT = /\A[A-Z](?:\/[A-Z])*\s?:\s*\S/

    # Says the key hints among the rows the bag painted while opening, queued, with the keys the player uses now;
    # nothing while key hints are left out.
    def self.opening_hints(pairs)
      return unless PokeAccess::Verbosity.hints?
      rows = (pairs || []).map { |r| PokeAccess.clean(r[0].to_s) }.select { |t| t =~ HINT }
      return if rows.empty?
      PokeAccess.speak(PokeAccess.sentences(rows.map { |t| PokeAccess::KeyHints.localize(t) }), false, :menu)
    end
  end
end

PokeAccess::Menus.bag_decorators.push(PokeAccess::SkyBag) unless PokeAccess::Menus.bag_decorators.include?(PokeAccess::SkyBag)

PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbStartScene, :optional => true) do |_scene, nxt, _a|
  ret = nil
  pairs = PokeAccess::PaintCapture.sample { ret = nxt.call }
  PokeAccess::SkyBag.opening_hints(pairs)
  ret
end
