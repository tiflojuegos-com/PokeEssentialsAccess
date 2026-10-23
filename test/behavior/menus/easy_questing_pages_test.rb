# Marin's quest log (plugins/easy_questing.rb): a quest's detail has two pages, its description and where it was
# received, and a marker over the page boxes shows which is up; while it shows, each page is said with its place. A
# copy that turned the second page off (Infinite Fusion) keeps the marker hidden, and no page is said. A stamp the
# second page cannot slice into a date, which it paints as ?????, is said as unknown.
class EasyQuestingPagesTest < PokeAccessTest
  Quest = Struct.new(:name, :desc, :location, :npc, :time, :completed)

  # The page marker sprite at the opacity the copy leaves it.
  Pager = Struct.new(:opacity, :disposed) do
    def disposed?; disposed ? true : false; end
  end

  # The quest every log here is open on, received at a time as Ruby 1.8.7 prints it, a stamp the second page slices.
  EGG = Quest.new("Lost Egg", "Find the egg", "Route 1", "Bill", "Sat Oct 03 10:20:00 +0200 2026", false)

  test "each detail page is said with which of the two it is while the marker shows" do
    announce(detail(0, "pager" => Pager.new(255)))
    announce(detail(1, "pager" => Pager.new(255)))
    assert_equal [["#{description_line}, #{page(1)}", true], ["#{location_line}, #{page(2)}", true]], SpeakCapture.log
  end

  test "a marker shown at any opacity, under either name, marks the page; a hidden or gone one does not" do
    { "shown" => [{ "pager" => Pager.new(255) }, true],
      "barely shown" => [{ "pager" => Pager.new(1) }, true],
      "the second marker shown" => [{ "pager2" => Pager.new(255) }, true],
      "hidden" => [{ "pager" => Pager.new(0) }, false],
      "disposed" => [{ "pager" => Pager.new(255, true) }, false],
      "absent" => [{}, false] }.each do |what, (sprites, marked)|
      SpeakCapture.clear
      announce(detail(0, sprites))
      assert_equal [marked ? "#{description_line}, #{page(1)}" : description_line], SpeakCapture.lines, what
    end
  end

  test "brief leaves the page out, a page being a position" do
    said = vb_levels do
      SpeakCapture.clear
      announce(detail(1, "pager" => Pager.new(255)))
      SpeakCapture.last
    end
    assert_equal [location_line, "#{location_line}, #{page(2)}", "#{location_line}, #{page(2)}"], said
  end

  test "a stamp the second page cannot slice is said as unknown, as the page paints ?????" do
    { "no stamp" => nil, "a word in its place, as the plugin's header suggests" => "pronto",
      "the stamp a newer Ruby prints" => "2026-10-03 10:20:00 +0200",
      "four words with no clock" => "un dia de octubre" }.each do |what, time|
      SpeakCapture.clear
      quest = EGG.dup
      quest.time = time
      announce(detail(1, { "pager" => Pager.new(255) }, quest))
      assert_equal [["#{location_line(PokeAccess::I18n.t(:pdx_unknown_short))}, #{page(2)}", true]],
                   SpeakCapture.log, what
    end
  end

  private

  # A quest log on the quest's detail (EGG's unless another is given) at the given page, with the given marker sprites.
  def detail(page, sprites, quest = EGG)
    World.stub_scene(:@scene => 2, :@mode => 0, :@ongoing => [quest], :@completed => [], :@sel_two => 0,
                     :@page => page, :@sprites => sprites)
  end

  # The log's announce, with nothing painted on record since the page loaded.
  def announce(log)
    PokeAccess::Quests.clear_paint
    PokeAccess::Quests.announce(log)
  end

  def page(n)
    PokeAccess::I18n.t(:adv_dex_page, :n => n, :m => 2)
  end

  # The first page's line: the quest, its status, its description and who gave it.
  def description_line
    PokeAccess::I18n.t(:qu_detail, :name => "Lost Egg", :status => PokeAccess::I18n.t(:qu_status_pending),
                                   :desc => "Find the egg", :npc => "Bill")
  end

  # The second page's line: where it was received, when (EGG's stamp as the page slices it, unless another is given),
  # and from whom.
  def location_line(time = "Oct 03, 10:20")
    PokeAccess::I18n.t(:qu_location, :loc => "Route 1", :when => time, :npc => "Bill")
  end
end
