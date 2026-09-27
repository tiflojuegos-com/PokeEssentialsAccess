# Fusion mode in the storage boxes (PokemonStorageScene#setFusing): the splicers arm the box cursor so the next
# Pokemon chosen is fused, shown only by the cursor sprite, so entering and leaving the mode are said.
module PokeAccess
  module IFStorageFusion
    # Says the fusion mode when it toggles, from setFusing's argument (the arrow and the scene keep separate
    # flags); a mode never switched on counts as off.
    def self.toggle(scene, on)
      state = on ? true : false
      return if (PokeAccess.ivar(scene, :@pa_fusing) ? true : false) == state
      scene.instance_variable_set(:@pa_fusing, state)
      PokeAccess.speak(PokeAccess::I18n.t(state ? :if_fuse_on : :if_fuse_off), true)
    rescue StandardError
      nil
    end

    # Whether a slot's Pokemon is already a fusion, which the mode refuses to fuse or swap ("already fused") and
    # whose combined icon it hides: its dex number past NB_POKEMON, the game's own test.
    def self.fused?(pk)
      return false if pk.nil?
      dexNum(pk.species) > ::NB_POKEMON
    rescue StandardError
      false
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  after("PokemonStorageScene", :setFusing) { |s, _r, args| PokeAccess::IFStorageFusion.toggle(s, args[0]) }

  # With the splicers armed, the Pokemon under the cursor is the one the held one fuses with, not swaps with,
  # unless it is a fusion already, which the mode will not take.
  override("PokeAccess::Party", :held_key) do |_mod, original, args|
    if (PokeAccess.ivar(args[0], :@screen).fusionMode rescue false)
      PokeAccess::IFStorageFusion.fused?(args[1]) ? :if_pc_fused : :if_pc_fuse
    else
      original.call
    end
  end
end
