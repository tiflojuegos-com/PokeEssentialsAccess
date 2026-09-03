# Realidea's Hall of Fame is the BW rework layered over the FL original: the writePokemonData/writeWelcome
# pair core hooks still exists but is never called. The living seams are moveSprite (called every frame
# of an entrant's slide, so deduped by index; -1 is the trainer's own entrance, which has no card) and
# writePokemonDataPC (the PC viewer's per-Pokemon painter).
module PokeAccess
  module RealideaHallOfFame
    # The spoken card of one hall entrant, or nil.
    def self.member_line(pk)
      return nil unless pk
      PokeAccess::I18n.t(:pc_slot, :name => pk.name, :level => pk.level)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  after("HallOfFameScene", :moveSprite, :optional => true) do |scene, _r, args|
    i = args[0]
    next unless i.is_a?(Integer) && i >= 0
    entry = PokeAccess.ivar(scene, :@hallEntry)
    PokeAccess::Cursor.announce(scene, :rea_hof_slide, i, false) do
      PokeAccess::RealideaHallOfFame.member_line((entry[i] rescue nil))
    end
  end
  after("HallOfFameScene", :writePokemonDataPC, :optional => true) do |_s, _r, args|
    t = PokeAccess::RealideaHallOfFame.member_line(args[0])
    PokeAccess.speak(t, true) if t
  end
end
