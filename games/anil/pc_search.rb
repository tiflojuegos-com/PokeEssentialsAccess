# Anil's PC search jumps to the chosen box and fades every Pokemon that does not match: after the jump, the box's
# name and the ones left bright, with their row and column, are said.
module PokeAccess
  module AnilPCSearch
    def self.start(scene)
      @scene = scene
      @jumped = false
    end

    def self.stop
      @scene = nil
    end

    def self.jumped
      @jumped = true if @scene
    end

    # From the frame poller: the frames of the fade run pbWait, so they pass here.
    def self.poll
      return if @scene.nil? || !@jumped
      @jumped = false
      storage = PokeAccess.ivar(@scene, :@storage)
      box = PokeAccess.sprite(@scene, "box")
      return unless storage && box
      cur = storage.currentBox
      bright = []
      storage.maxPokemon(cur).times do |i|
        pk = storage[cur, i]
        bright.push([i, pk]) if pk && box.getPokemon(i).opacity >= 255
      end
      PokeAccess.speak(hits_text((storage[cur].name rescue nil), bright), false) unless bright.empty?
    rescue StandardError
      nil
    end

    # The box, then each match with its row and column.
    def self.hits_text(box_name, hits)
      cols = PokeAccess::Party.box_columns
      list = hits.map { |i, pk| "#{pk.name}#{PokeAccess::I18n.t(:pc_pos, :row => i / cols + 1, :col => i % cols + 1)}" }
      line = PokeAccess::I18n.t(:anil_search_hits, :list => list.join("; "))
      box_name.to_s.empty? ? line : "#{PokeAccess.clean(box_name.to_s)}. #{line}"
    end
  end
end

PokeAccess::Game.define("anil_pc_search") do
  around("PokemonStorageScene", :pbSearch, :optional => true) do |scene, nxt, _a|
    PokeAccess::AnilPCSearch.start(scene)
    begin
      nxt.call
    ensure
      PokeAccess::AnilPCSearch.stop
    end
  end
  around("PokemonStorageScene", :pbJumpToBox, :optional => true) do |_scene, nxt, _a|
    ret = nxt.call
    PokeAccess::AnilPCSearch.jumped
    ret
  end
  poll_each_frame { PokeAccess::AnilPCSearch.poll }
end
