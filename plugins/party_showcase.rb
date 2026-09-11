# Tectonic's Party Showcase (PokemonPartyShowcase_Scene): the whole team on one page, painted straight onto
# an overlay with no cursor or window, so it is read as painted and said once per state. The constructor is
# the opening paint AND the screen's whole loop: it returns only when the player closes the page, so the
# opening read comes from the frame poll while it runs, and updateShowcaseInfo repaints on every toggle.
module PokeAccess
  module PartyShowcase
    def self.hold(scene); @scene = scene; end

    # Forgets the screen and drops a capture nobody took (a page closed before its first frame).
    def self.release
      @scene = nil
      PokeAccess::PaintCapture.take(:showcase)
    end

    # Speaks the page as painted, once per state.
    def self.say(scene)
      t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:showcase))
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :showcase, t.to_s)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end

    # The opening page, on the first frame of the constructor's loop: reading it after the constructor
    # returned recited the whole team over the menu the player had just come back to.
    def self.poll
      say(@scene) if @scene
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonPartyShowcase_Scene", :initialize, :optional => true) do |scene, nxt, _a|
  PokeAccess::PaintCapture.arm(:showcase)
  PokeAccess::PartyShowcase.hold(scene)
  begin
    nxt.call
  ensure
    PokeAccess::PartyShowcase.release
  end
end

PokeAccess::Keys.on_frame { PokeAccess::PartyShowcase.poll }

PokeAccess::Hooks.around_hook("PokemonPartyShowcase_Scene", :updateShowcaseInfo, :optional => true) do |scene, nxt, _a|
  PokeAccess::PaintCapture.arm(:showcase)
  begin
    nxt.call
  ensure
    PokeAccess::PartyShowcase.say(scene)
  end
end
