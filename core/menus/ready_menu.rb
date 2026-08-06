module PokeAccess
  # Ready Menu (registered key-items quick selector, PokemonReadyMenu_Scene): its buttons are sprites, and
  # the focus lives in a hidden Window_CommandPokemon ("cmdwindow") that the scene rebuilds and re-indexes
  # every frame.
  #
  # Read that window, not the @index it is mirrored into. Five of the six games that ship this screen split
  # it into TWO lists -- field moves on one side, registered items on the other -- and their @index is
  # [moveCursor, itemCursor, side], an Array. The old reader compared idx >= 0, which an Array does not
  # answer, so it raised NoMethodError on the first frame and the rescue swallowed it. Only z218 kept the
  # flat integer. The hidden window always carries whichever list has focus, so both shapes need no special
  # case here.
  #
  # What that silence cost was NOT the item names: the window is a Window_CommandPokemon, which is born
  # active, and the generic command reader gates on active rather than on visible, so it was already saying
  # them. What was missing is the re-read when focus crosses to the other list, which is why the side is in
  # the dedup key. The window is claimed so the two readers do not both speak the same row.
  module ReadyMenu
    def self.poll(scene)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "cmdwindow"))
      return unless win
      txt = PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s)
      return if txt.empty?
      PokeAccess::Cursor.announce(scene, :ready_last, [side(scene), txt], true) { txt }
    rescue StandardError
      nil
    end

    # Which of the two lists has focus, or nil on the single-list shape. Part of the dedup key so crossing to
    # the other side speaks again even when both lists happen to show the same name at the same position.
    def self.side(scene)
      idx = PokeAccess.ivar(scene, :@index)
      idx.is_a?(Array) ? idx[2] : nil
    end
  end
end

# pbUpdate runs each frame and re-syncs the hidden window; read the focus on change.
PokeAccess::Hooks.after_hook("PokemonReadyMenu_Scene", :pbUpdate) do |scene, _r, _a|
  PokeAccess::ReadyMenu.poll(scene)
end
