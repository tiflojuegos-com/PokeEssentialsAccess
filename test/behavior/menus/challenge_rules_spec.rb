# The challenge / randomizer rule editor. Three copies of the window class were compared line by line and
# are identical; they differ only in the label the game PAINTS beside each rule ("ACTIVADO"/"DESACTIVADO"
# in one, "ON"/"OFF" in another). The reader takes the state from the NUMBER and speaks it through the
# mod's own i18n, so both come out in the player's language rather than the game's.
require File.expand_path("../../../plugins/challenge_rules", File.dirname(__FILE__))

class FakeRuleWindow
  def initialize(cmds, keys = nil); @commands = cmds; @text_key = keys; end
end

Suite.define("challenge rules: the toggle is spoken, from either shape of the command list") do
  cr = PokeAccess::ChallengeRules
  on  = PokeAccess::I18n.t(:val_on)
  off = PokeAccess::I18n.t(:val_off)

  # Before the window's setter splits them, an entry is still the [name, toggle] pair it was built from.
  paired = FakeRuleWindow.new([["Nuzlocke", 1], ["Nivel máximo", 0], ["Confirmar", nil]])
  eq "an enabled rule", cr.text(paired, 0), "Nuzlocke, #{on}"
  eq "a disabled one", cr.text(paired, 1), "Nivel máximo, #{off}"
  eq "and the trailing option has no state to speak", cr.text(paired, 2), "Confirmar"

  # After it, the names are in @commands and the toggles in @text_key -- same values, two arrays.
  split = FakeRuleWindow.new(["Nuzlocke", "Nivel máximo", "Confirmar"], [1, 0, nil])
  eq "the split shape reads the same", cr.text(split, 0), "Nuzlocke, #{on}"
  eq "for the disabled rule too", cr.text(split, 1), "Nivel máximo, #{off}"
  eq "and the trailing option stays plain", cr.text(split, 2), "Confirmar"

  eq "an index past the list says nothing", cr.text(split, 9), nil
end
