# Reminiscencia's status sheet, which opens on an egg too: its header paints the name, never the species inside.
# Only its module is evaluated: its wiring would set the shared summary to single-page for every other suite.
remi_summary_path = File.expand_path("../../../games/reminiscencia/summary_extra.rb", File.dirname(__FILE__))
eval(File.read(remi_summary_path).split("PokeAccess::Summary.single_page = true").first, TOPLEVEL_BINDING, remi_summary_path)

Suite.define("reminiscencia summary: an egg's sheet does not say the species inside it") do
  egg = Poke.build(:name => "Huevo", :species => 25, :level => 1)
  def egg.egg?; true; end
  def egg.isEgg?; true; end
  scene = Object.new
  line = PokeAccess::RemiSummary.estado(scene, egg)
  truthy "the name the header paints", line.start_with?("Huevo")
  falsy "and not the species", line.include?(PBSpecies.getName(25))
  mon = Poke.build(:name => "Chispa", :species => 25, :level => 12)
  line = PokeAccess::RemiSummary.estado(scene, mon)
  truthy "a hatched Pokemon still names its species", line.include?(PBSpecies.getName(25))
  truthy "the sheet's headings are the language's own words", line.include?("#{PokeAccess::I18n.t(:rem_sum_stats)}. ")
  falsy "and its sentences close once each", line.include?("..")
  mv = Struct.new(:id, :pp, :totalpp)
  one = Poke.build(:name => "Chispa", :species => 25, :level => 12, :moves => [mv.new(33, 35, 35), mv.new(0, 0, 0)])
  eq "an empty move slot says so in the language's words", PokeAccess::RemiSummary.focused_move(one, 1),
     PokeAccess::I18n.t(:rem_sum_no_move)
end

# The sheet works Hidden Power's type and power out of the IVs (pbHiddenPower), where the move's own data says
# Normal and a variable power; the reader says what the sheet works out.
Suite.define("reminiscencia summary: Hidden Power as the sheet works it out") do
  t = PokeAccess::I18n
  hp = Struct.new(:id, :pp, :totalpp).new(333, 15, 15)
  tackle = Struct.new(:id, :pp, :totalpp).new(33, 35, 35)
  mon = Poke.build(:name => "Chispa", :species => 25, :level => 12, :moves => [tackle, hp])
  saved = Object.instance_method(:pbHiddenPower)
  Object.send(:define_method, :pbHiddenPower) { |_iv| [7, 70] }
  begin
    line = PokeAccess::RemiSummary.moves_text(mon)
    truthy "the list gives Hidden Power the type pbHiddenPower answers, not the move data's",
           line.include?("#{PBMoves.getName(333)}. #{t.t(:mv_type, :t => PBTypes.getName(7))}")
    detail = PokeAccess::RemiSummary.focused_move(mon, 1).to_s
    truthy "and the focused detail its power", detail.include?(t.t(:mv_power, :p => PokeAccess::MoveInfo.power_phrase(70)))
  ensure
    Object.send(:define_method, :pbHiddenPower, saved)
  end
end

# The sheet paints no level anywhere (its textpos has none), a star beside a shiny one's name, and the stats its
# nature raises and lowers as the colours of their labels.
Suite.define("reminiscencia summary: the head as painted, the shiny star and the nature's colours") do
  scene = Object.new
  mon = Poke.build(:name => "Chispa", :species => 25, :level => 77, :nature => 1, :shiny => true)
  sex = PokeAccess::Party.sign_phrase(mon)
  line = PokeAccess::RemiSummary.estado(scene, mon)
  truthy "name, sex and species, nothing between them", line.start_with?("Chispa#{sex}, #{PBSpecies.getName(25)}")
  falsy "and no level anywhere", line.include?("77")
  truthy "the star the sheet paints", line.include?(PokeAccess::Party.shiny_word(mon))
  eff = PokeAccess::Summary.nature_effect_line(mon)
  truthy "the stats its nature raises and lowers", !eff.nil? && line.include?(eff)
  plain = PokeAccess::RemiSummary.estado(scene, Poke.build(:name => "Chispa", :species => 25, :nature => 0))
  falsy "no star on a plain one", plain.include?(PokeAccess::Party.shiny_word(mon))
end

# The sheet paints a key beside each move (1 to 4), T beside the ability, the arrows and X in its footer; said after
# the sheet while key hints are said, as the player has those keys now.
Suite.define("reminiscencia summary: the keys the sheet paints, as bound now") do
  scene = Object.new
  mon = Poke.build(:name => "Chispa", :species => 25)
  keys = PokeAccess::RemiSummary.keys_line
  truthy "the four moves' keys lead", keys.start_with?("1, 2, 3, 4: ")
  truthy "said at the end of the sheet", PokeAccess::RemiSummary.estado(scene, mon).end_with?(keys)
  PokeAccess::Config.verbosity = :brief
  falsy "not while hints are left out", PokeAccess::RemiSummary.estado(scene, mon).include?(keys)
  PokeAccess::Config.verbosity = :full
  PokeAccess::Config.rebinds = { :key_1 => 0x39, :fast_travel => 0x37 }
  moved = PokeAccess::RemiSummary.keys_line
  truthy "a moved move key is said where it is", moved.start_with?("9, 2, 3, 4: ")
  truthy "and the ability's", moved.include?(PokeAccess::I18n.t(:rem_sum_keys, :moves => "9, 2, 3, 4", :ability => "7",
                                                                 :back => PokeAccess::KeyHints.key(:b, "X")))
end
