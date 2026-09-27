module PokeAccess
  # Egg-slot reader shared by the two incubator plugins (KYU's Hatcher, the Incubadora of opalo and Z); each
  # plugin's hooks arm the capture before a redraw and announce after.
  module Incubator
    # Starts collecting what the screen writes on its next redraw.
    def self.arm
      PokeAccess::PaintCapture.arm(:hatch_state)
    end

    # The focused incubator slot at the incubators reading's level: the slot and, for an egg, the steps it has left,
    # and in full how close it is; the info key and Ctrl+T say it whole until the screen is disposed.
    # param painted the sentence the screen wrote beside the grid, or nil for a copy that writes none
    def self.text(scene, painted = nil)
      idx = PokeAccess.ivar(scene, :@index)
      return nil if idx.nil?
      eggs = ($PokemonGlobal.eggs rescue nil)
      egg = eggs ? eggs[idx] : nil
      n = idx + 1
      unless egg
        free = PokeAccess::I18n.t(:hatch_slot_empty, :n => n)
        PokeAccess::Info.set_info(:text, free, free)
        return free
      end
      left = PokeAccess::I18n.t(:hatch_steps, :n => steps(egg))
      said = PokeAccess.clean(painted.to_s)
      whole = PokeAccess::I18n.t(:hatch_slot_egg, :n => n, :state => "#{left}. #{said.empty? ? hatch_state(egg) : said}")
      PokeAccess::Info.set_info(:text, whole, whole)
      return whole if PokeAccess::Verbosity.keep?(:incubator, :full)
      PokeAccess::I18n.t(:hatch_slot_egg, :n => n, :state => left)
    rescue StandardError
      nil
    end

    # The steps an egg has left (modern steps_to_hatch, gen-6 eggsteps).
    def self.steps(egg)
      s = (egg.steps_to_hatch rescue nil)
      s = (egg.eggsteps rescue nil) if s.nil?
      s.to_i
    end

    # The hatch-progress hint by the bands the screens use, for a copy that writes no sentence of its own.
    def self.hatch_state(egg)
      s = steps(egg)
      return PokeAccess::I18n.t(:hatch_soon) if s < 1275
      return PokeAccess::I18n.t(:hatch_close) if s < 2550
      return PokeAccess::I18n.t(:hatch_notclose) if s < 10200
      PokeAccess::I18n.t(:hatch_far)
    end

    # What the screen shows above the grid, said before the first slot; nil unless a profile overrides it.
    def self.header(_scene)
      nil
    end

    # Reads the focused slot when the cursor moves or an egg goes into or out of it (hence the egg in the key); the
    # first read of a screen is queued and carries the header, moves interrupt.
    def self.announce(scene)
      painted = (PokeAccess::PaintCapture.take(:hatch_state, :formatted) || []).join(" ")
      idx = PokeAccess.ivar(scene, :@index)
      return if idx.nil?
      egg = ($PokemonGlobal.eggs[idx] rescue nil)
      first = PokeAccess::Cursor.pending?(scene, :hatch)
      PokeAccess::Cursor.announce(scene, :hatch, [idx, egg ? egg.object_id : nil], true, false) do
        t = text(scene, painted)
        head = first ? header(scene) : nil
        head && t ? "#{head}. #{t}" : t
      end
    end
  end
end
