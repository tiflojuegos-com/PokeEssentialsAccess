# Soulstones 2's chapters (games/soulstones2/chapters.rb): the trainer card's numbered badge icons, one per completed
# chapter, and the info key's trainer line say chapters where the stock readers say badges.
class Ss2ChaptersGdTest < PokeAccessTest
  # The card's badge icons, numbered 1 to 18: one per chapter completed, as the load and save screens count them.
  ICONS = "Graphics/Pictures/Trainer Card/icon_badges"

  # The card's badge line and the trainer line's badges part as the profile file makes them, from one evaluation whose
  # changes (both readers, the overrides listing, the profile name) are taken back at once; with_chapters puts these
  # two in place for a test.
  CHAPTER_READERS = begin
    card = PokeAccess::TrainerCard
    stock = [card.method(:badge_line), PokeAccess::Info::TRAINER_PARTS[:badges]]
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    begin
      path = File.join(Harness::ROOT, "games", "soulstones2", "chapters.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      [card.method(:badge_line), PokeAccess::Info::TRAINER_PARTS[:badges]]
    ensure
      card.define_singleton_method(:badge_line, stock[0])
      PokeAccess::Info::TRAINER_PARTS[:badges] = stock[1]
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
    end
  end

  test "says the card's badge icons as the chapters they number" do
    with_chapters { read_front }
    assert_equal [["Name Tester. #{PokeAccess::I18n.t(:ss2_chapters, :n => 2)}", false]], SpeakCapture.log
  end

  test "the stock card says the same icons as badges" do
    read_front
    assert_equal [["Name Tester. #{PokeAccess::I18n.t(:tr_badges, :n => 2)}", false]], SpeakCapture.log
  end

  test "puts the chapters where the badges stood in the info key's trainer line" do
    stock = PokeAccess::Info.trainer_info
    badges = PokeAccess::I18n.t(:tr_badges, :n => 3)
    assert_includes stock, badges, "the stock line counts the player's three badges"
    with_chapters do
      assert_equal stock.sub(badges, PokeAccess::I18n.t(:ss2_chapters, :n => 3)), PokeAccess::Info.trainer_info
    end
  end

  test "leaves the chapters out of the trainer line for a player whose count it cannot tell" do
    with_chapters { assert_nil PokeAccess::Info.trainer_part(:badges, Object.new) }
  end

  private

  # Reads the card's front as it paints the name row and two chapter icons, on a card not read before.
  def read_front
    PokeAccess::TrainerCard.read_face(Object.new, true) do
      pbDrawTextPositions(nil, [["Name", 34, 70], ["Tester", 302, 70]])
      pbDrawImagePositions(nil, [[ICONS, 31, 292, 0, 0, 32, 32], [ICONS, 81, 292, 32, 0, 32, 32]])
    end
  end

  # Runs the block with Soulstones 2's badge line and badges part in place of the ones there, put back after.
  def with_chapters
    card = PokeAccess::TrainerCard
    line, part = CHAPTER_READERS
    held = [card.method(:badge_line), PokeAccess::Info::TRAINER_PARTS[:badges]]
    card.define_singleton_method(:badge_line, line)
    PokeAccess::Info::TRAINER_PARTS[:badges] = part
    yield
  ensure
    if held
      card.define_singleton_method(:badge_line, held[0])
      PokeAccess::Info::TRAINER_PARTS[:badges] = held[1]
    end
  end
end
