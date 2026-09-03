module PokeAccess
  # Slot narration shared by the two incubator plugins in the wild (KYU's Hatcher, and the Incubadora
  # of opalo and Z): a grid of egg slots drawn only as graphics, read as empty or as an egg with a
  # progress hint (species hidden, as on screen). The hooks live with each plugin.
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

    # Reads the focused slot when it changes: the cursor moving, or an egg going into or out of the slot the
    # cursor is already on. That second case is why the contents are in the key -- adding and removing both
    # end in a redraw without touching @index, so an index-only key left the change unspoken.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return if idx.nil?
      egg = ($PokemonGlobal.eggs[idx] rescue nil)
      PokeAccess::Cursor.announce(scene, :hatch, [idx, egg ? egg.object_id : nil], true) { text(scene) }
    end
  end
end
