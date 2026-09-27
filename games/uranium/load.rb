module PokeAccess
  # Uranium's load screen, whose saves are PokemonSaveFile objects: the continue panel from its paint with the team and
  # the rule icons, the other-saves list by each slot's newest file, and the normal/autosave chooser in full. The
  # title before it is Luka's GenCustomStyle alone, whose prompt is said here (plugins/luka_title probes GenOneStyle).
  module UraniumLoad
    # Brackets a panel's refresh: a panel holding a save keeps what it painted, minus its title (the focused command).
    def self.capture(panel)
      return yield unless PokeAccess.ivar(panel, :@savefile)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      title = PokeAccess.clean(PokeAccess.ivar(panel, :@title).to_s)
      lines = PokeAccess::LoadPanel.lines_of(pairs.reject { |p| PokeAccess.clean(p[0].to_s) == title })
      panel.instance_variable_set(:@access_ura_lines, lines) unless lines.empty?
      ret
    end

    # The opening read: the continue panel's lines, the saved team and the rule icons; nil without a save.
    def self.summary(scene)
      sprites = PokeAccess.ivar(scene, :@sprites)
      return nil unless sprites.is_a?(Hash)
      panel = sprites.values.find { |s| PokeAccess.ivar(s, :@access_ura_lines) }
      return nil unless panel
      save = PokeAccess.ivar(panel, :@savefile)
      parts = PokeAccess.ivar(panel, :@access_ura_lines).dup
      parts.push(PokeAccess::LoadPanel.team((save.trainer rescue nil)))
      parts.concat(modes(save))
      parts.compact.join(". ")
    rescue StandardError
      nil
    end

    # The rules a save was started with, as words for the icon (panel) or the colour (list) that shows them.
    def self.modes(save)
      m = []
      m.push(PokeAccess::I18n.t(:ura_nuzlocke)) if (save.nuzlocke rescue false)
      m.push(PokeAccess::I18n.t(:ura_randomizer)) if (save.randomizer rescue false)
      m
    end

    # An other-saves row: the title its slot's newest file paints, then that file's rules; nil past the list.
    def self.slot_text(slots, idx)
      return nil unless slots.is_a?(Array) && idx && slots[idx]
      save = slots[idx].newer
      ([save.title.to_s] + modes(save)).join(", ")
    rescue StandardError
      nil
    end

    # Says the other-saves row the cursor lands on: the first one after a redraw queued, later moves interrupting.
    def self.slot_focus(scene, slots, idx)
      PokeAccess::Cursor.announce(scene, :ura_slot, idx, true, false) { slot_text(slots, idx) }
    end

    # The normal/autosave chooser's focused side. rows as painted: slot name, the two labels, the two save times, the
    # two play times and, when the times differ, "Newer" over the side slot.autonewer? names.
    def self.sub_text(rows, index, slot)
      side = index.to_i == 0 ? 0 : 1
      parts = side == 0 ? ["#{rows[0]}. #{rows[1]}", rows[3], rows[5]] : [rows[2], rows[4], rows[6]]
      newer = ((slot.autonewer? ? 1 : 0) rescue nil)
      parts.push(rows[7]) if rows[7] && newer == side
      parts.compact.join(", ")
    end

    # Stands in for the core chooser reader, whose five rows leave out the play times and "Newer".
    def self.auto_sub(scene, index, slot)
      rows = PokeAccess::PaintCapture.take(:ls_autosub)
      if rows.is_a?(Array) && rows.length >= 7
        scene.instance_variable_set(:@access_autosub_rows, rows)
        PokeAccess::Cursor.reset(scene, :ls_autosub)
      end
      r = PokeAccess.ivar(scene, :@access_autosub_rows)
      return unless r.is_a?(Array) && r.length >= 7
      PokeAccess::Cursor.announce(scene, :ls_autosub, [slot, index], true, false) { sub_text(r, index, slot) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("uranium") do
  after("GenCustomStyle", :initialize) { |_s, _r, _a| PokeAccess.speak(PokeAccess::TitleScreen.prompt, true) }
  around("PokemonLoadPanel", :refresh) { |panel, nxt, _a| PokeAccess::UraniumLoad.capture(panel) { nxt.call } }
  read_on_open("PokemonLoadScene", :pbStartScene2, :hook_container => true) { |scene| PokeAccess::UraniumLoad.summary(scene) }
  before("PokemonLoadScene", :pbDrawSaveCommands) { |scene, _a| PokeAccess::Cursor.reset(scene, :ura_slot) }
  after("PokemonLoadScene", :pbDrawSaveCommands, :hook_container => true) do |scene, _r, args|
    PokeAccess::UraniumLoad.slot_focus(scene, args[0], args[1] || 0)
  end
  after("PokemonLoadScene", :pbMoveSaveSel) do |scene, _r, args|
    PokeAccess::UraniumLoad.slot_focus(scene, PokeAccess.ivar(scene, :@savefiles), args[0])
  end
  override("PokeAccess::LoadScreen", :auto_sub) do |_mod, _original, args|
    PokeAccess::UraniumLoad.auto_sub(args[0], args[1], args[2])
  end
end
