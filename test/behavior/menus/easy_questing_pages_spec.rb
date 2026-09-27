# Marin's quest log (plugins/easy_questing.rb): a quest's detail has two pages, its description and where it was
# received, and a marker over the two page boxes shows which is up; each page is said with its place. A copy that
# turned the second page off (Infinite Fusion) keeps the marker hidden, and no page is said.
module EasyQuestingPagesSpec
  Quest = Struct.new(:name, :desc, :location, :npc, :time, :completed)

  # The page marker sprite, at the opacity the copy leaves it.
  Pager = Struct.new(:opacity) do
    def disposed?; false; end
  end

  # A quest log on a quest's detail, at the given page, its marker at the given opacity.
  def self.log(page, opacity)
    q = Quest.new("Lost Egg", "Find the egg.", "Route 1", "Bill", nil, false)
    World.stub_scene(:@scene => 2, :@mode => 0, :@ongoing => [q], :@completed => [], :@sel_two => 0, :@page => page,
                     :@sprites => { "pager" => Pager.new(opacity) })
  end
end

Suite.define("easy questing: a quest's detail page says which of its two it is, as its marker shows") do
  qs = PokeAccess::Quests
  mark = lambda { |n| PokeAccess::I18n.t(:adv_dex_page, :n => n, :m => 2) }
  SpeakCapture.clear
  qs.announce(EasyQuestingPagesSpec.log(0, 255))
  truthy "the description is page 1 of 2", SpeakCapture.last.to_s.end_with?(", #{mark.call(1)}")
  qs.announce(EasyQuestingPagesSpec.log(1, 255))
  truthy "where it was received, page 2 of 2", SpeakCapture.last.to_s.end_with?(", #{mark.call(2)}")

  qs.announce(EasyQuestingPagesSpec.log(0, 0))
  falsy "a copy whose marker stays hidden, with no second page, says no page",
        SpeakCapture.last.to_s.include?(mark.call(1))

  PokeAccess::Config.verbosity = :brief
  qs.announce(EasyQuestingPagesSpec.log(1, 255))
  falsy "brief leaves the page out, a page being a position", SpeakCapture.last.to_s.include?(mark.call(2))
  PokeAccess::Config.verbosity = :full
end
