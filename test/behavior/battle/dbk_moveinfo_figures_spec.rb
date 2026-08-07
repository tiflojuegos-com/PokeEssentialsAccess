# The DBK Move Info panel exists to show the FINAL numbers: it runs the damage calculation through
# pbGetFinalModifiers, so a 90-power move with STAB is drawn as 135. Reading move.power instead was reading
# the data file over a panel whose whole purpose is that it does not match the data file.
#
# The figures are found by alignment: the panel centres the four values and left-aligns their labels. That
# survives a copy that shifts the columns and adds an outline (royal does both) and a game that translates
# "Pow", which matching the label would not.

Suite.define("dbk move info: the figures come from the panel's own draw call, not from the move data") do
  mi = PokeAccess::DBKMoveInfo
  move = Struct.new(:name, :power, :accuracy, :priority, :category).new("Lanzallamas", 90, 100, 0, 0)
  begin
    mi.capture_off
    mi.instance_variable_set(:@painted, nil)
    out = mi.figures(move).join(", ")
    truthy "with nothing captured it falls back to the move data", out.include?("90")

    mi.capture_on
    mi.note_draw([["Lanzallamas", 10, 12, :left], ["Pow", 256, 40, :left], ["135", 309, 40, :center],
                  ["Acc", 348, 40, :left], ["100", 401, 40, :center],
                  ["Pri", 442, 40, :left], ["---", 484, 40, :center],
                  ["Eff", 428, 12, :left], ["10%", 484, 12, :center]])
    out = mi.figures(move)
    truthy "the painted power wins over the base one", out.any? { |s| s.include?("135") }
    falsy "and the base one is not spoken", out.any? { |s| s =~ /\b90\b/ }
    truthy "the added-effect chance is read, which the panel labels Eff", out.any? { |s| s.include?("10%") }
    falsy "a priority of --- is omitted, as a priority of zero already was",
          out.any? { |s| s.include?("---") }

    # The panel's own placeholders map onto words the reader already had: no damage, variable power, never
    # misses. Asserting the WORD and not merely "not ---" is the point -- a reader that spoke the dashes
    # would pass a weaker check.
    mi.note_draw([["x", 0, 0, :left], ["---", 1, 1, :center], ["---", 2, 2, :center],
                  ["---", 3, 3, :center], ["---", 4, 4, :center]])
    out = mi.figures(move).join(", ")
    truthy "--- power is no damage", out.include?(PokeAccess::I18n.t(:mv_power_none))
    truthy "--- accuracy is never misses", out.include?(PokeAccess::I18n.t(:mv_acc_perfect))

    mi.note_draw([["x", 0, 0, :left], ["???", 1, 1, :center], ["100", 2, 2, :center],
                  ["---", 3, 3, :center], ["---", 4, 4, :center]])
    truthy "??? power is a variable-power move",
           mi.figures(move).join(", ").include?(PokeAccess::I18n.t(:mv_power_var))

    # A draw call that is not the panel's must not be mistaken for it.
    mi.note_draw([["algo", 0, 0, :left], ["otra cosa", 1, 1, :left]])
    truthy "a draw with no four centred values leaves the last reading alone",
           mi.figures(move).join(", ").include?(PokeAccess::I18n.t(:mv_power_var))
  ensure
    mi.capture_off
    mi.instance_variable_set(:@painted, nil)
  end
end
