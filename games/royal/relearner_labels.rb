# Royal's relearner paints a machine row's :TM and :HM tags as "MT" and "MO" through _INTL; said the same way.
PokeAccess::Game.define("royal_relearner_labels") do
  override("PokeAccess::UIV21", :entry_label) do |_mod, original, args|
    tag = args[0][1]
    if tag == :TM
      (_INTL("MT") rescue "MT")
    elsif tag == :HM
      (_INTL("MO") rescue "MO")
    else
      original.call
    end
  end
end
