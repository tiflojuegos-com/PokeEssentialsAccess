module PokeAccess
  # The PC of the engine Reborn, Rejuvenation and Desolation share: the grab button with Ctrl held (or Deselect in a
  # marked slot's menu) marks and unmarks box slots for a multiselection, the scene's @aMultiSelectedMons of [box,
  # index] pairs, painted as an overlay on each marked Pokemon; Move multiselection and Mass Release act on them.
  module StorageRV
    # The marked slots, or nil where the PC keeps none.
    def self.marked(scene)
      m = PokeAccess.ivar(scene, :@aMultiSelectedMons)
      m.is_a?(Array) ? m : nil
    end

    # The word a box slot's line adds while the slot is marked, or nil.
    def self.mark_word(scene, index)
      m = marked(scene)
      box = (PokeAccess.ivar(scene, :@storage).currentBox rescue nil)
      (m && m.include?([box, index])) ? PokeAccess::I18n.t(:rv_pc_marked) : nil
    end

    # Says whether the slot the grab button toggled is marked now.
    def self.toggled(scene, selected)
      on = marked(scene).include?([selected[0], selected[1]])
      PokeAccess.speak(PokeAccess::I18n.t(on ? :rv_pc_marked : :rv_pc_unmarked), true)
    end

    # Hooks the grab, which marks or unmarks instead of taking the Pokemon when the multiselection changes.
    def self.bind
      PokeAccess::Hooks.around_hook("PokemonStorageScreen", :pbHold, :optional => true) do |screen, nxt, args|
        scene = PokeAccess.ivar(screen, :@scene)
        before = (PokeAccess::StorageRV.marked(scene) || []).dup
        r = nxt.call
        after = PokeAccess::StorageRV.marked(scene)
        PokeAccess::StorageRV.toggled(scene, args[0]) if after && after != before && args[0].is_a?(Array)
        r
      end
    end
  end
end

PokeAccess::StorageRV.bind if PokeAccess::DataRV.engine?

# A marked slot's line says so; a PC that keeps no multiselection marks nothing.
PokeAccess::Hooks.override(PokeAccess::Party, :slot_marks, :tag => "rv_common") do |_mod, original, args|
  word = PokeAccess::StorageRV.mark_word(args[0], args[1])
  word ? original.call + [word] : original.call
end
