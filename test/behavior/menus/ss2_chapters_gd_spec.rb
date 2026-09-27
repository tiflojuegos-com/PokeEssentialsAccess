# Soulstones 2's trainer card draws one numbered icon per completed chapter (icon_badges.png holds the numbers 1 to
# 18), and its load and save screens call that count "Ch. Completed". The profile's forms are put in place for the
# suite and the stock ones put back after it.
Suite.define("ss2 trainer card: the chapter icons are said as chapters, on the card and in the trainer line") do
  t = PokeAccess::I18n
  card = PokeAccess::TrainerCard
  meta = (class << card; self; end)
  meta.send(:alias_method, :ss2_spec_badge_line, :badge_line)
  part = PokeAccess::Info::TRAINER_PARTS[:badges]
  scene = Object.new
  face = lambda do
    scene.instance_variable_set(:@access_card_read, nil)
    card.read_face(scene, true) do
      pbDrawTextPositions(nil, [["Name", 34, 70], ["Tester", 302, 70]])
      pbDrawImagePositions(nil, [["Graphics/Pictures/Trainer Card/icon_badges", 31, 292, 0, 0, 32, 32],
                                 ["Graphics/Pictures/Trainer Card/icon_badges", 81, 292, 32, 0, 32, 32]])
    end
  end
  begin
    SpeakCapture.clear
    face.call
    match "the stock reader calls the icons badges", SpeakCapture.lines.join(" "),
          /#{Regexp.escape(t.t(:tr_badges, :n => 2))}/

    load File.expand_path("../../../games/soulstones2/chapters.rb", File.dirname(__FILE__))
    SpeakCapture.clear
    face.call
    line = SpeakCapture.lines.join(" ")
    match "Soulstones 2's card says them as the chapters they number", line, /#{Regexp.escape(t.t(:ss2_chapters, :n => 2))}/
    falsy "never as badges", line.include?(t.t(:tr_badges, :n => 2))
    info = PokeAccess::Info.trainer_info.to_s
    match "the info key's trainer line counts chapters too", info, /#{Regexp.escape(t.t(:ss2_chapters, :n => 3))}/
    falsy "and not badges", info.include?(t.t(:tr_badges, :n => 3))
  ensure
    meta.send(:alias_method, :badge_line, :ss2_spec_badge_line)
    meta.send(:remove_method, :ss2_spec_badge_line)
    PokeAccess::Info::TRAINER_PARTS[:badges] = part
  end
end
