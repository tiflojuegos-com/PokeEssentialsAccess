# Two screens of Ciudad Jade that reach a blind player as pixels only. The theatre's choreography sheet
# (Baileoricorios, 0285) paints four columns through drawTextEx and waits for a key; the gym's cry helper
# (Pokemonysusgritos, 0284) shows three species and marks the chosen one by colour alone, Left/Right
# cycling with no sound and C playing the cry. Both build everything in the constructor and run their loop
# from inside it, so the sheet is armed at the constructor and taken as the loop starts, and the helper is
# read from its per-frame input method.
module PokeAccess
  module ReaJade
    # The dex numbers the helper shows for each value of $game_variables[91], as its constructor lists them.
    TRIOS = { 1 => [209, 35, 742], 2 => [175, 546, 281], 3 => [703, 183, 755] }

    # The sheet's columns as one line: "Oricorio 1: Arriba, Salto, ..." per column.
    def self.sheet_text(rows)
      cols = (rows || []).map do |r|
        lines = r.to_s.split("\n").map { |l| l.strip }.reject { |l| l.empty? }
        next nil if lines.empty?
        lines.length > 1 ? "#{lines[0]}: #{lines[1..-1].join(', ')}" : lines[0]
      end
      cols.compact.join(". ")
    end

    # The species under the cursor and its position among the three, or nil off the table.
    def self.cry_text(sel, group)
      ids = TRIOS[group.to_i]
      return nil unless ids && sel.is_a?(Integer) && sel >= 1 && sel <= ids.length
      name = (PokeAccess::Data.species_name(ids[sel - 1]) rescue nil)
      name = "Pokémon #{sel}" if name.nil? || name.to_s.empty?
      "#{name}, #{sel} de #{ids.length}"
    end
  end
end

PokeAccess::Game.define("realidea") do
  before("Baileoricorios", :initialize, :optional => true) { |_s, _a| PokeAccess::PaintCapture.arm(:rea_oricorios) }
  before("Baileoricorios", :actu, :optional => true) do |_s, _a|
    rows = PokeAccess::PaintCapture.take(:rea_oricorios, :dtex)
    PokeAccess.speak_clean(PokeAccess::ReaJade.sheet_text(rows), true)
  end

  before("Pokemonysusgritos", :initialize, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :rea_cry) }
  after("Pokemonysusgritos", :input, :optional => true) do |scene, _r, _a|
    sel = PokeAccess.ivar_i(scene, :@seleccion)
    t = PokeAccess::ReaJade.cry_text(sel, ($game_variables[91] rescue nil))
    PokeAccess::Cursor.announce(scene, :rea_cry, sel, true) { t } if t
  end
end
