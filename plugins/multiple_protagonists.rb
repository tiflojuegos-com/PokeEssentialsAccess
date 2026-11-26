# NettoHikari's Multiple Protagonists: pbSwitchCharacter swaps the player for another protagonist, which only the sprite
# shows. Says the one now in play, queued behind the event's text, and nothing when the swap changes nothing. The key is
# $Trainer.metaID in 1.x (Essentials v16) and $player.character_ID in 4.x and 5.x.
module PokeAccess
  module MultipleProtagonists
    # The protagonist in play: its key and its name.
    def self.current
      pl = PokeAccess::Engine.player
      return [nil, ""] unless pl
      key = pl.respond_to?(:character_ID) ? pl.character_ID : (pl.metaID rescue nil)
      [key, (pl.name rescue nil).to_s]
    end

    # Says the protagonist in play when it is not the one `was` names.
    def self.switched(was)
      key, name = current
      return if key == was || name.empty?
      PokeAccess.speak(PokeAccess::I18n.t(:protagonist_now_playing, :name => name), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbSwitchCharacter", "plugin_multiple_protagonists", :around) do |_args, nxt|
  was = PokeAccess::MultipleProtagonists.current[0]
  ret = nxt.call
  PokeAccess::MultipleProtagonists.switched(was)
  ret
end
