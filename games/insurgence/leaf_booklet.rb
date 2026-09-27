module PokeAccess
  # Insurgence's Leaf Booklet (Scene_Leaf), Delta Snorlax's season forms: five textless leaves over an off-screen list
  # that still holds the Notebook's captions. The list is claimed and each focus said as its leaf: the form's name
  # and whether it is on show, unlocked or a silhouette.
  module InsurgenceLeaf
    # Delta Snorlax's form names as the Pokedex has them, or [] where they cannot be read.
    def self.form_names
      sp = (PBSpecies.const_get(:DELTASNORLAX) rescue nil)
      raw = sp ? (pbGetMessage(MessageTypes::FormNames, sp) rescue nil) : nil
      raw.to_s.split(",").map { |n| n.strip }
    end

    # The i18n key of the state a leaf is painted in.
    def self.state_key(i)
      return :ins_leaf_current if ($game_variables[5] rescue nil) == i
      open = ($game_variables[171][i] rescue false)
      open ? :ins_leaf_open : :ins_leaf_locked
    end

    # A leaf's line: its form and its state.
    def self.row(i)
      PokeAccess::Util.join_parts([form_names[i], PokeAccess::I18n.t(state_key(i))], ", ")
    end

    # Says the focused leaf when the focus moves, the first time queued.
    def self.update(scene)
      win = PokeAccess.sprite(scene, "command_window")
      return unless win
      i = win.index
      PokeAccess::Cursor.announce(scene, :ins_leaf, i, true, false) { row(i) }
    end
  end
end

# The list is claimed before the frame's window update reads it.
PokeAccess::Game.define("insurgence") do
  before("Scene_Leaf", :update) { |s, _a| PokeAccess.dedicate(PokeAccess.sprite(s, "command_window")) }
  after("Scene_Leaf", :update) { |s, _r, _a| PokeAccess::InsurgenceLeaf.update(s) }
end
