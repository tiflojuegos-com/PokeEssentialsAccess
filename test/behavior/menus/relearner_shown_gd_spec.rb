# The modern relearner's rows as painted: a move's power and type for the Pokemon (SHOW_MODIFIED_MOVE_PROPERTIES),
# and Royal's translated machine symbols ("MT", "MO").
Suite.define("relearner (modern): the move as the screen shows it for the Pokemon") do
  mv = GameData::Move
  mv.send(:define_method, :display_power) { |_pk| 102 }
  mv.send(:define_method, :display_type) { |_pk| :DARK }
  begin
    pk = Poke.build(:name => "Pika")
    shown = PokeAccess::UIV21.move_from_entry([:RETURN, "Nv. 12"], pk).to_s
    plain = PokeAccess::UIV21.move_from_entry([:RETURN, "Nv. 12"]).to_s
    truthy "the power it has for this Pokemon", shown.include?("102") && !plain.include?("102")
    truthy "and the type", shown.include?("TypeDARK") && !plain.include?("TypeDARK")
  ensure
    mv.send(:remove_method, :display_power)
    mv.send(:remove_method, :display_type)
  end
end

Suite.define("royal: a machine row is said as it paints it") do
  meta = (class << PokeAccess::UIV21; self; end)
  meta.send(:alias_method, :royal_spec_entry_label, :entry_label)
  load File.expand_path("../../../games/royal/relearner_labels.rb", File.dirname(__FILE__))
  begin
    truthy "the TM row as MT", PokeAccess::UIV21.move_from_entry([:TACKLE, :TM]).to_s.start_with?("MT. ")
    truthy "a level row as it is", PokeAccess::UIV21.move_from_entry([:TACKLE, "Nv. 5"]).to_s.start_with?("Nv. 5. ")
  ensure
    meta.send(:alias_method, :entry_label, :royal_spec_entry_label)
    meta.send(:remove_method, :royal_spec_entry_label)
  end
end
