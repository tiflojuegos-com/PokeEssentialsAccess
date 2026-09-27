module PokeAccess
  # Infinite Fusion's speech bubbles (its edition of Carmaniac's plugin): pbCallBub sets the next message window to
  # float over (1) or point with an arrow at (2) an event, which is all that tells who says a line when it is not
  # the event being talked to. Such a line is led by where that event stands from the player, and by the player's own
  # tag for it when there is one.
  module IFSpeechBubbles
    # The event the running map interpreter belongs to, or nil when none runs.
    def self.running_event_id
      interp = pbMapInterpreter
      (interp && interp.running?) ? PokeAccess.ivar(interp, :@event_id) : nil
    rescue StandardError
      nil
    end

    # Who a bubble on this event marks: the player's tag for it, if any, and where it stands from the player. The
    # event's own name is left out: an editor's name can give a puzzle away (Berry Forest's impostor is "fake kid").
    def self.speaker(ev)
      where = PokeAccess::Locator.dir_phrase(ev.x - $game_player.x, ev.y - $game_player.y)
      tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
      (tag.nil? || tag.to_s.empty?) ? where : "#{tag}, #{where}"
    end

    # As a message window opens under a bubble on an event other than the running one, has its line led by it.
    def self.opened
      kind = $PokemonTemp.speechbubble_bubble
      id = $PokemonTemp.speechbubble_talking
      return unless (kind == 1 || kind == 2) && id.is_a?(Integer) && id > 0 && id != running_event_id
      ev = $game_map.events[id]
      PokeAccess.before_next_line(speaker(ev)) if ev
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  kernel("pbCreateMessageWindow", :after) { |_a, _r| PokeAccess::IFSpeechBubbles.opened }
  kernel("pbDisposeMessageWindow", :after) { |_a, _r| PokeAccess.before_next_line(nil) }
end
