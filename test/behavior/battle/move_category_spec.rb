# The damage category -- physical, special or status -- is an icon beside the type on every screen that shows
# a move, so every move line says it as one word right after the type, gen-6 included.

Suite.define("move category: one word, right after the type, on every line") do
  line = PokeAccess::MoveInfo.line("Rayo", "Electrico", 90, 100, :cat => PokeAccess::MoveInfo.category_word(1),
                                   :pp => 15, :total_pp => 15)
  t = PokeAccess::I18n
  eq "name, type, category, then power, accuracy and pp", line,
     ["Rayo", t.t(:mv_type, :t => "Electrico"), t.t(:cat_special), t.t(:mv_power, :p => "90"),
      t.t(:mv_acc, :a => 100), t.t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
  eq "the three numbers are the three words", [0, 1, 2].map { |c| PokeAccess::MoveInfo.category_word(c) },
     [t.t(:cat_physical), t.t(:cat_special), t.t(:cat_status)]
  eq "anything else is no word at all", [nil, 3, :PHYSICAL].map { |c| PokeAccess::MoveInfo.category_word(c) },
     [nil, nil, nil]
  eq "and a move with no category to tell reads the rest without a gap",
     PokeAccess::MoveInfo.line("Rayo", "Electrico", 90, 100, :cat => PokeAccess::MoveInfo.category_word(nil)),
     ["Rayo", t.t(:mv_type, :t => "Electrico"), t.t(:mv_power, :p => "90"), t.t(:mv_acc, :a => 100)].join(". ")
end

Suite.define("move category: gen-6 finds it where each move object keeps it") do
  party_move = Struct.new(:id, :pp, :totalpp).new(4, 10, 10)
  eq "a party move has none, so the move data answers (PBMoveData)", PokeAccess::MoveInfo.category_of(party_move), 1

  battle_move = Object.new
  battle_move.instance_variable_set(:@category, 2)
  def battle_move.id; 3; end
  eq "a battle move keeps it in @category, with no reader", PokeAccess::MoveInfo.category_of(battle_move), 2

  line = PokeAccess::Info.move_info(party_move).to_s
  t = PokeAccess::I18n
  truthy "the info key says it right after the type",
         line.index("#{t.t(:mv_type, :t => PBTypes.getName(2))}. #{t.t(:cat_special)}. ")
end

Suite.define("move category: the gen-6 fight menu says it after the type") do
  mv = Object.new
  mv.instance_variable_set(:@category, 0)
  def mv.id; 7; end
  def mv.name; "Placaje"; end
  def mv.type; 0; end
  def mv.pp; 30; end
  def mv.totalpp; 35; end
  battler = Struct.new(:moves).new([mv])
  disp = Object.new
  disp.instance_variable_set(:@battler, battler)
  disp.instance_variable_set(:@index, 0)
  PokeAccess::Battle.read_fight_move(disp)
  t = PokeAccess::I18n
  match "type, then the category, then the pp", SpeakCapture.lines.join(" "),
        /\APlacaje\. #{Regexp.escape(t.t(:mv_type, :t => PBTypes.getName(0)))}\. #{t.t(:cat_physical)}\. /
end

Suite.define("move category: the gen-6 relearner line carries it") do
  line = PokeAccess::MoveInfo.by_id_via_data(5).to_s
  truthy "the relearner's detail says the category after the type",
         line.index("#{PokeAccess::I18n.t(:mv_type, :t => PBTypes.getName(0))}. #{PokeAccess::I18n.t(:cat_status)}. ")
end
