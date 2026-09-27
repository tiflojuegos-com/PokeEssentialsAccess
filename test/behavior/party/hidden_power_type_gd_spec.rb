# Independent Hidden Power Type: the memo page ends with the Pokemon's own Hidden Power type, as its icon shows it.

Suite.define("hidden power type: the memo page says the type its icon shows") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Chispa")
  eq "a Pokemon with no Hidden Power type of its own adds nothing", PokeAccess::SummaryGameData.memo_extras(pk), []
  def pk.hptype; :FIRE; end
  eq "one with it says its type", PokeAccess::SummaryGameData.memo_extras(pk), [t.t(:sm_hidden_power, :t => "TypeFIRE")]
  truthy "at the end of the memo page", PokeAccess::SummaryGameData.memo_page_text(pk, nil).to_s.end_with?(t.t(:sm_hidden_power, :t => "TypeFIRE"))
end
