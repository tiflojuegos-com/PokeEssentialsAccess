module PokeAccess
  # Infinite Fusion's speech bubbles (its edition of Carmaniac's plugin): a line pbCallBub hangs over or points at an
  # event other than the one talked to is led by where it stands from the player, and by the player's tag for it if any.
  module IFSpeechBubbles
    # The event the running map interpreter belongs to, or nil when none runs.
    def self.running_event_id
      interp = pbMapInterpreter
      (interp && interp.running?) ? PokeAccess.ivar(interp, :@event_id) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Who a bubble on this event marks: the player's tag for it, if any, and where it stands from the player, said as a
    # place so as not to sound like a route. The event's own name is left out: an editor's name can give a puzzle away
    # (Berry Forest's impostor is "fake kid").
    def self.speaker(ev)
      where = place(ev.x - $game_player.x, ev.y - $game_player.y)
      tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
      return PokeAccess::I18n.t(:if_bubble_from, :where => where) if tag.nil? || tag.to_s.empty?
      PokeAccess::I18n.t(:if_bubble_tag_from, :tag => tag, :where => where)
    end

    # How far (dx, dy) tiles lie from the player: "5 to the right and 1 up".
    def self.place(dx, dy)
      text = PokeAccess::Routes::Text
      parts = []
      parts.push(PokeAccess::I18n.t(text::MOVED_KEYS[dx < 0 ? 4 : 6], :n => dx.abs)) if dx != 0
      parts.push(PokeAccess::I18n.t(text::MOVED_KEYS[dy < 0 ? 8 : 2], :n => dy.abs)) if dy != 0
      parts.empty? ? PokeAccess::I18n.t(:loc_here) : text.and_list(parts)
    end

    # As a message window opens under a bubble on an event other than the running one, has its line led by it.
    def self.opened
      kind = $PokemonTemp.speechbubble_bubble
      id = $PokemonTemp.speechbubble_talking
      return unless (kind == 1 || kind == 2) && id.is_a?(Integer) && id > 0 && id != running_event_id
      ev = $game_map.events[id]
      PokeAccess.before_next_line(speaker(ev)) if ev
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  kernel("pbCreateMessageWindow", :after) { |_a, _r| PokeAccess::IFSpeechBubbles.opened }
  kernel("pbDisposeMessageWindow", :after) { |_a, _r| PokeAccess.before_next_line(nil) }
end
