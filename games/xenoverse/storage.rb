module PokeAccess
  # The PC (0226_NewStorage, NewPokemonStorage, which pbPokeCenterPC opens from 78 PC events): a 4x4 box beside the
  # party's six slots under one cursor (@selIndex, 0-15 the box, 16-21 the party), a held Pokemon (@heldmon), and menus
  # of its own over it: the five actions (@s, @index), a command list (@c, @cmdid), the box to jump to (@s["qtbg"]) and
  # the marks (@m, whose cursor picture stands over the mark it toggles).
  module XenoverseStorage
    MARK_X = 348
    MARK_STEP = 22

    # Starts reading a PC that opens.
    def self.watch(scene)
      @scene, @mode, @box, @commands, @ask, @marked = scene, nil, nil, nil, nil, nil
      PokeAccess::Cursor.reset(self, :xenoverse_storage)
    end

    # Forgets the PC as it closes.
    def self.unwatch
      PokeAccess::Info.clear_text
      PokeAccess::XenoversePainted.forget
      @scene = nil
    end

    # Keeps what a command list or a number box asks, and the Pokemon whose marks are set, while each runs.
    def self.asking(kind, args)
      @commands = kind == :commands ? [args[0].to_s, args[1]] : @commands
      @ask = kind == :number ? args[0].to_s : @ask
      @marked = kind == :marks ? args[0] : @marked
    end

    # Says what the cursor of the menu in front stands on whenever it changes.
    def self.poll
      scene = @scene
      return unless scene
      mode, key, text = focus(scene)
      return if mode.nil? || key.nil?
      text = PokeAccess.sentences([heading(scene, mode), text]) if mode != @mode
      first = @mode.nil?
      @mode = mode
      PokeAccess::Cursor.announce(self, :xenoverse_storage, [mode, key], !first) do
        PokeAccess::Info.set_info(:text, text)
        text
      end
    end

    # The menu in front, the key of its cursor and the line it says.
    def self.focus(scene)
      marks = live(PokeAccess.ivar(scene, :@m), "cursor")
      return [:marks] + marks_focus(marks) if marks
      commands = live(PokeAccess.ivar(scene, :@c), "box")
      return [:commands] + commands_focus(scene) if commands && @commands
      menu = PokeAccess.ivar(scene, :@s)
      number = live(menu, "qtbg")
      if number
        n = PokeAccess::XenoversePainted.of_sprite(number).last.to_s
        return [:number, n, n]
      end
      return [:actions] + actions_focus(scene) if live(menu, "sac0")
      [:grid] + grid_focus(scene)
    end

    # The sprite under key of a menu's hash while it is shown, or nil.
    def self.live(hash, key)
      sprite = hash.is_a?(Hash) ? hash[key] : nil
      return nil if sprite.nil? || (sprite.disposed? rescue true)
      sprite
    end

    # What leads a menu's first line: the box's painted name and the bar's keys, the question, or the Pokemon.
    def self.heading(scene, mode)
      line = case mode
             when :grid then grid_heading(scene)
             when :commands then @commands[0]
             when :number then @ask
             when :actions then actions_heading(scene)
             when :marks then PokeAccess::XenoversePainted.of_sprite(PokeAccess.ivar(scene, :@m)["box"]).last
             end
      PokeAccess.clean(line.to_s)
    end

    # The box's painted name, with the lower bar's Jump and Actions after it while key hints are said.
    def self.grid_heading(scene)
      name = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "boxname")).last.to_s
      bar = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "lbo"))
      PokeAccess::XenoversePainted.with_hint(name, [[bar[0], :x, "A"], [bar[1], :y, "S"]])
    end

    # The grid's slot: the Pokemon there or empty, what the held one does there, and the slot's place.
    def self.grid_focus(scene)
      index = PokeAccess.ivar(scene, :@selIndex)
      return [nil, nil] unless index.is_a?(Integer)
      pk = slot_pokemon(scene, index)
      held = PokeAccess.ivar(scene, :@heldmon)
      box = (PokeAccess.ivar(scene, :@storage).currentBox rescue nil)
      [[box, index, pk.object_id, held.object_id], slot_line(slot_text(pk, held), index)]
    end

    # The Pokemon in a grid slot, or nil.
    def self.slot_pokemon(scene, index)
      if index <= 15
        (PokeAccess.sprite(scene, "box").currentbox[index] rescue nil)
      else
        (PokeAccess.sprite(scene, "partybox").party[index - 16] rescue nil)
      end
    end

    # A slot's Pokemon by name and level, or empty, as the held Pokemon would meet it.
    def self.slot_text(pk, held)
      return PokeAccess::I18n.t(:xenoverse_holding, :name => held.name) if held && held.equal?(pk)
      line = pk ? PokeAccess::I18n.t(:pc_slot, :name => pk.name, :level => pk.level) : nil
      return line || PokeAccess::I18n.t(:pc_empty) unless held
      line ? PokeAccess::I18n.t(:pc_swap, :name => line, :held => held.name) : PokeAccess::I18n.t(:pc_place, :held => held.name)
    end

    # A slot's line with its place: its row and column in the box, or its number in the party.
    def self.slot_line(slot, index)
      return slot + PokeAccess::I18n.t(:pc_pos, :row => index / 4 + 1, :col => index % 4 + 1) if index <= 15
      entry = PokeAccess::Verbosity.list_entry(PokeAccess::I18n.t(:pc_team), index - 15, 6)
      PokeAccess::I18n.t(:xenoverse_pc_party, :slot => slot, :entry => entry)
    end

    # The actions bar's painted Pokemon: its name and level.
    def self.actions_heading(scene)
      bar = PokeAccess::XenoversePainted.of_sprite(PokeAccess.ivar(scene, :@s)["bar"])
      bar.length < 2 ? bar[0].to_s : PokeAccess::I18n.t(:xenoverse_pc_bar, :name => bar[0], :level => bar[1])
    end

    # The action under the cursor, by the label painted on its button.
    def self.actions_focus(scene)
      index = PokeAccess.ivar(scene, :@index)
      buttons = PokeAccess.ivar(scene, :@acsel)
      return [nil, nil] unless index.is_a?(Integer) && buttons.is_a?(Array) && buttons[index]
      label = PokeAccess::XenoversePainted.of(buttons[index]).last.to_s
      [index, PokeAccess::Verbosity.list_entry(label, index + 1, buttons.length)]
    end

    # The command under the cursor of the list the scene asked for.
    def self.commands_focus(scene)
      index = PokeAccess.ivar(scene, :@cmdid)
      list = @commands[1]
      return [nil, nil] unless index.is_a?(Integer) && list.is_a?(Array) && list[index]
      [index, PokeAccess::Verbosity.list_entry(PokeAccess.clean(list[index].to_s), index + 1, list.length)]
    end

    # The mark under the marks cursor, settled on one, and whether the Pokemon has it.
    def self.marks_focus(cursor)
      x = (cursor.x rescue nil)
      return [nil, nil] unless x.is_a?(Numeric) && (x.to_i - MARK_X) % MARK_STEP == 0
      id = (x.to_i - MARK_X) / MARK_STEP
      name = PokeAccess::Marking::NAMES[id]
      marks = (@marked.markings rescue 0).to_i
      return [nil, nil] unless name
      state = (marks >> id) & 1 == 1 ? :mk_on : :mk_off
      line = PokeAccess::I18n.t(:xenoverse_mark, :name => PokeAccess::I18n.t(name), :state => PokeAccess::I18n.t(state))
      [[id, marks], line]
    end
  end
end

PokeAccess::SceneWatcher.wire("NewPokemonStorage", :initialize, PokeAccess::XenoverseStorage)
PokeAccess::Game.define("xenoverse") do
  [[:showCommands, :commands], [:chooseNumber, :number], [:setMarkings, :marks]].each do |meth, kind|
    before("NewPokemonStorage", meth) { |_scene, args| PokeAccess::XenoverseStorage.asking(kind, args) }
  end
end
