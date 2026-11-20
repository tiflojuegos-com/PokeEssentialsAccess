module PokeAccess
  # A visible wild Pokemon noticing the player (OverworldPokemonEvent#update_state to :NOTICED_PLAYER): the game shows it
  # by an animation over the Pokemon, with a sound, picked by how it behaves on noticing (curious, angry, excited, else
  # surprised), and then by how it moves. Said queued: who saw the player, its reaction and where it is. One with no
  # behaviour on noticing plays no animation and says nothing. A Pokemon running away (flee: with a repel, a fleeing
  # behaviour or, in the Safari, the player too close) is said queued after it, with its cry and the flee sound.
  # The same calls run in the overworld Safari (safari.rb), where the notice icon (OverworldNoticeIcon) stays over the
  # Pokemon while it watches and no ball catches it; there, going back to roaming takes the icon down, said queued too
  # (preventive: no map of 1.3.2 reaches the Safari). A message freezes every visible Pokemon (pause_movement, :PAUSED,
  # set without update_state), which takes the icons down as the message shows: said by nothing, the message speaking.
  module IF2WildNotice
    REACTIONS = { :curious => :if2_wild_seen_curious, :aggressive => :if2_wild_seen_angry,
                  :semi_aggressive => :if2_wild_seen_angry, :excited => :if2_wild_seen_excited }

    # Says ev noticing the player, by the reaction its behaviour animates.
    def self.noticed(ev)
      behavior = PokeAccess.ivar(ev, :@behavior_noticed)
      return if behavior.nil?
      name = PokeAccess::IF2Overworld.wild_name(ev)
      return if name.nil? || name.to_s.empty?
      dir = PokeAccess::Locator.dir_phrase(ev.x - $game_player.x, ev.y - $game_player.y)
      key = REACTIONS[behavior] || :if2_wild_seen_surprised
      PokeAccess.speak(PokeAccess::I18n.t(key, :name => name, :dir => dir), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says ev's state change after update_state: in the Safari, a watcher going back to roaming.
    def self.changed(ev, was, now)
      return unless was == :NOTICED_PLAYER && now == :ROAMING && PokeAccess::IF2Safari.on?
      say(:if2_wild_unseen, ev)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says ev running away, when flee left it fleeing (a shiny one never does).
    def self.fled(ev, was)
      say(:if2_wild_flees, ev) if was != :FLEEING && PokeAccess.ivar(ev, :@current_state) == :FLEEING
    end

    def self.say(key, ev)
      name = PokeAccess::IF2Overworld.wild_name(ev)
      PokeAccess.speak(PokeAccess::I18n.t(key, :name => name), false) if name && !name.to_s.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The notice is said before the state changes, as a fleeing behaviour flees inside update_state.
PokeAccess::Game.define("infinitefusion_hoenn") do
  around("OverworldPokemonEvent", :update_state, :optional => true) do |ev, nxt, a|
    was = PokeAccess.ivar(ev, :@current_state)
    PokeAccess::IF2WildNotice.noticed(ev) if a[0] == :NOTICED_PLAYER
    ret = nxt.call
    PokeAccess::IF2WildNotice.changed(ev, was, a[0])
    ret
  end
  around("OverworldPokemonEvent", :flee, :optional => true) do |ev, nxt, _a|
    was = PokeAccess.ivar(ev, :@current_state)
    ret = nxt.call
    PokeAccess::IF2WildNotice.fled(ev, was)
    ret
  end
end
