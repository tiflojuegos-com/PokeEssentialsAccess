# Sevii's trainer card (games/sevii/chapters.rb) paints its badge count as text and, in the badge slots, one emblem
# per completed chapter of the story: the emblems are said as the chapters completed, never as badges.
class SeviiChaptersTest < PokeAccessTest
  # The card's emblems: the top row of badges.png, drawn once per completed chapter.
  EMBLEMS = "Graphics/Pictures/badges"

  # The card's badge line as the profile file makes it, from one evaluation whose changes (the reader, the overrides
  # listing, the profile list) are taken back at once; with_chapters puts it in place for a test.
  CHAPTER_LINE = begin
    card = PokeAccess::TrainerCard
    stock = card.method(:badge_line)
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    begin
      path = File.join(Harness::ROOT, "games", "sevii", "chapters.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      card.method(:badge_line)
    ensure
      card.define_singleton_method(:badge_line, stock)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
    end
  end

  test "says the badge count as painted, then the emblems as the chapters completed" do
    with_chapters { read_front }
    assert_equal [["Badges 16. #{PokeAccess::I18n.t(:ss2_chapters, :n => 2)}", false]], SpeakCapture.log
  end

  test "the stock card says the same emblems as badges" do
    read_front
    assert_equal [["Badges 16. #{PokeAccess::I18n.t(:tr_badges, :n => 2)}", false]], SpeakCapture.log
  end

  private

  # Reads the card's front as it paints its badge count and two chapter emblems, on a card not read before.
  def read_front
    PokeAccess::TrainerCard.read_face(Object.new, true) do
      pbDrawTextPositions(nil, [["Badges", 332, 256], ["16", 468, 256]])
      pbDrawImagePositions(nil, [[EMBLEMS, 72, 310, 0, 0, 32, 32], [EMBLEMS, 120, 310, 32, 0, 32, 32]])
    end
  end

  # Runs the block with Sevii's badge line in place of the one there, put back after.
  def with_chapters
    card = PokeAccess::TrainerCard
    held = card.method(:badge_line)
    card.define_singleton_method(:badge_line, CHAPTER_LINE)
    yield
  ensure
    card.define_singleton_method(:badge_line, held) if held
  end
end
