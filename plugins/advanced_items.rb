module PokeAccess
  # Field-move / registered-item selection (Advanced Items - Field Moves plugin,
  # SelectMoveMenu_Scene). A custom button menu: @commands is a list of [id, name, mode, idx]
  # scrolled by @index with no command window, so it is otherwise mute. refresh_buttons runs on
  # each cursor move and pbShowCommands wraps the loop, so the focused option's name is read on
  # open and on navigation, deduped. The name is already a display string (the move/item name).
  module FieldMovesV21
    # Speaks the focused option when it changes (deduped per scene via Cursor; pbShowCommands resets the
    # slot so reopening on the same option still reads).
    #
    # Deduped by INDEX and read with the party member's name, because this menu is usually "which Pokemon
    # should use Surf?" -- every row carries the SAME move name. Deduping on that name meant the first row
    # spoke and every other row was swallowed as a repeat, and even the row that did speak never said whose
    # it was, which is the only thing being chosen here.
    def self.read(scene)
      cmds = PokeAccess.ivar(scene, :@commands)
      idx  = PokeAccess.ivar(scene, :@index)
      return unless cmds.is_a?(Array) && idx && cmds[idx]
      name = (cmds[idx][1] rescue nil).to_s
      return if name.empty?
      who = holder_name(cmds[idx])
      PokeAccess::Cursor.announce(scene, :advanced_items, idx) { who ? "#{name}, #{who}" : name }
    rescue StandardError
      nil
    end

    # The party member a row belongs to. Field 2 is the party slot: the plugin's own button builds its icon
    # with $player.party[command[2]], even though the comment beside the field misnames it as the mode.
    def self.holder_name(cmd)
      i = (cmd[2] rescue nil)
      return nil unless i.is_a?(Integer)
      party = (PokeAccess::Engine.player.party rescue nil)
      pk = (party.is_a?(Array) ? party[i] : nil)
      n = (pk.name rescue nil)
      (n && !n.to_s.empty?) ? n : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.before_hook("SelectMoveMenu_Scene", :pbShowCommands, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :advanced_items)
  PokeAccess::FieldMovesV21.read(scene)
end

PokeAccess::Hooks.after_hook("SelectMoveMenu_Scene", :refresh_buttons, :optional => true) do |scene, _r, _a|
  PokeAccess::FieldMovesV21.read(scene)
end
