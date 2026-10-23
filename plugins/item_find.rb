module PokeAccess
  # Item-received popup (Boonzeet's "Item Find" plugin): the name and description as its title and description
  # windows show them (the copies word a machine differently), read by the frame poll while pbShow blocks.
  module ItemFind
    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; PokeAccess::Cursor.reset(nil, :item_find); end

    # The name and description the popup paints, once per popup.
    def self.poll
      s = @scene
      return unless s
      name = (PokeAccess.sprite(s, "titlewindow").text rescue nil)
      desc = (PokeAccess.sprite(s, "descwindow").text rescue nil)
      parts = [name, desc].reject { |x| x.nil? || x.to_s.strip.empty? }
      return if parts.empty?
      PokeAccess::Cursor.announce(nil, :item_find, parts, false) { parts.join(". ") }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonItemFind_Scene", :pbShow, :optional => true) do |scene, nxt, _a|
  PokeAccess::ItemFind.watch(scene)
  begin; nxt.call; ensure; PokeAccess::ItemFind.unwatch; end
end

PokeAccess::Frame.each_pulse { PokeAccess::ItemFind.poll }
