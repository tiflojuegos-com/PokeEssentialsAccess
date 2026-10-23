# Independent Hidden Power Type: the memo page ends with the Pokemon's own Hidden Power type, as its icon shows it.
class HiddenPowerTypeGdTest < PokeAccessTest
  T = PokeAccess::I18n
  MEMO = ["Naturaleza firme.", "Conocido en Ruta 1."].freeze

  test "ends the memo page with the Pokemon's own Hidden Power type, after what the page paints" do
    assert_equal "#{T.t(:sm_memo)}. #{MEMO.join(' ')} #{T.t(:sm_hidden_power, :t => 'TypeFIRE')}",
                 PokeAccess::SummaryGameData.memo_page_text(typed(:FIRE), MEMO)
  end

  test "adds nothing for a Pokemon with no Hidden Power type of its own, or one it cannot read" do
    unread = Poke.build(:name => "Chispa")
    def unread.hptype; raise "no type"; end
    { "no hptype" => Poke.build(:name => "Chispa"), "a nil one" => typed(nil), "one that raises" => unread }.each do |what, pk|
      assert_equal "#{T.t(:sm_memo)}. #{MEMO.join(' ')}", PokeAccess::SummaryGameData.memo_page_text(pk, MEMO), what
    end
  end

  private

  # Chispa answering hptype with type.
  def typed(type)
    pk = Poke.build(:name => "Chispa")
    pk.define_singleton_method(:hptype) { type }
    pk
  end
end
