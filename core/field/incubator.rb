module PokeAccess
  # Egg incubator (the Hatcher plugin): a grid of slots, drawn only as graphics. Reads the focused slot
  # when it changes -- empty, or an egg with a progress hint (species hidden, as on screen).
  module Incubator
    # The spoken description of the focused incubator slot, or nil.
    def self.text(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return nil if idx.nil?
      eggs = ($PokemonGlobal.eggs rescue nil)
      egg = eggs ? eggs[idx] : nil
      n = idx + 1
      return PokeAccess::I18n.t(:hatch_slot_empty, :n => n) unless egg
      PokeAccess::I18n.t(:hatch_slot_egg, :n => n, :state => hatch_state(egg))
    rescue StandardError
      nil
    end

    # The hatch-progress hint from the egg's remaining steps. Works on both engines (modern
    # steps_to_hatch, gen-6 eggsteps).
    def self.hatch_state(egg)
      s = (egg.steps_to_hatch rescue nil)
      s = (egg.eggsteps rescue nil) if s.nil?
      s = s.to_i
      return PokeAccess::I18n.t(:hatch_soon) if s < 1275
      return PokeAccess::I18n.t(:hatch_close) if s < 2550
      return PokeAccess::I18n.t(:hatch_notclose) if s < 10200
      PokeAccess::I18n.t(:hatch_far)
    end

    # Reads the focused slot when it changes, deduped by slot index across both hooked methods.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return if idx == scene.instance_variable_get(:@access_hatch_idx)
      scene.instance_variable_set(:@access_hatch_idx, idx)
      t = text(scene)
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    end
  end
end

# refresh runs on every cursor move, which covers navigating the grid. update does NOT: it is the screen's
# blocking loop, so an after-hook on it spoke once the player had already closed the incubator. Bound before
# it instead, which is the one moment the screen is built and nothing has been said yet -- the opening read
# the loop never produces on its own, because it only calls refresh when a key is pressed.
PokeAccess::Hooks.after_hook("Hatcher", :refresh) { |scene, _result, _args| PokeAccess::Incubator.announce(scene) }
PokeAccess::Hooks.before_hook("Hatcher", :update) { |scene, _args| PokeAccess::Incubator.announce(scene) }
