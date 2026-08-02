# Fusion mode in the storage boxes (PokemonStorageScene#setFusing, 016_UI/017_UI_PokemonStorage.rb:1593, and
# the box arrow's own setFusing at :214). Picking the splicers inside the PC puts the box cursor into a mode
# where the next Pokemon you choose becomes the head or the body -- but the only feedback is that the cursor
# sprite swaps to a splicer icon, so a blind player cannot tell the box is armed and would fuse by accident.
# Announce entering and leaving the mode; the box navigation itself is already read by the core storage
# reader, and the Fuse/Unfuse/Reverse/Nickname commands go through pbShowCommands, which is covered too.
module PokeAccess
  module IFStorageFusion
    # Voices the fusion mode when it toggles. The flag arrives as the method's argument, which is more
    # reliable than the scene ivar (the arrow and the scene keep separate copies).
    def self.toggle(scene, on)
      state = on ? true : false
      return if PokeAccess.ivar(scene, :@pa_fusing) == state
      scene.instance_variable_set(:@pa_fusing, state)
      PokeAccess.speak(PokeAccess::I18n.t(state ? :if_fuse_on : :if_fuse_off), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("PokemonStorageScene", :setFusing) { |s, _r, args| PokeAccess::IFStorageFusion.toggle(s, args[0]) }
end
