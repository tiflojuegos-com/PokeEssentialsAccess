# The save panel of the engine Reborn and Rejuvenation share (games/rv_common/save_panel_rv.rb): its Pokedex field,
# painted "owned/seen", said with what each count counts, the play time it paints next left whole; the rest of the
# panel as core reads it.
Harness.load_common("rv_common")

class RvSavePanelTest < PokeAccessTest
  # The panel Rejuvenation 14 builds (Save.rb:17-44), colour tags and all.
  PANEL = "<ac><c3=00FF00,008000>Grand Dream City</c3></ac><br>Player<r><c3=0000FF,000080>Ana</c3><br>" \
          "Badges<r><c3=0000FF,000080>3</c3><br>Pokédex<r><c3=0000FF,000080>12/30</c3><br>" \
          "Time<r><c3=0000FF,000080>05h 12m</c3><br>"

  test "the Pokedex counts say which is owned and which seen, the play time after them left whole" do
    was = PokeAccess::Config.language
    [:es, :en, :fr, :de, :pl, :pt].each do |lang|
      PokeAccess::Config.language = lang
      said = bound { PokeAccess::SavePanel.say(panel(PANEL)) }
      counts = PokeAccess::I18n.t(:rv_dex_counts, :owned => "12", :seen => "30")
      assert_equal 1, said.length, lang.inspect
      assert_match(/Pokédex, #{Regexp.escape(counts)}, Time, 05h 12m\z/, said[0][0], lang.inspect)
      assert_equal false, said[0][1]
    end
  ensure
    PokeAccess::Config.language = was
  end

  test "a panel with no Pokedex field is read as core reads it" do
    plain = "Player<r>Ana<br>Badges<r>3<br>"
    core = said_by { PokeAccess::SavePanel.say(panel(plain)) }
    assert_equal core, bound { PokeAccess::SavePanel.say(panel(plain)) }
  end

  private

  def panel(text)
    World.stub_scene(:@sprites => { "locwindow" => Struct.new(:text).new(text) })
  end

  def said_by
    SpeakCapture.clear
    yield
    SpeakCapture.log.dup
  end

  # What the block says with rv_common's reading bound over core's, core's put back after.
  def bound(&blk)
    meta = PokeAccess::SavePanel.singleton_class
    core = meta.instance_method(:say)
    PokeAccess::SaveRV.bind
    said_by(&blk)
  ensure
    meta.send(:define_method, :say, core)
  end
end
