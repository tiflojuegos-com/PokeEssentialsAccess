# Anil's online play (the Cable Club): both teams of the preview read once as the card is drawn, the countdown's hint
# once, and the label over the room's code field. Gamedata pass; games/anil/cableclub.rb is loaded once over the
# stubbed scenes.
class AnilTeamPreviewStub
  def initialize; @sprites = { "timer" => Struct.new(:text).new("") }; end
  def pbDrawTeamPreviewText(_l, _r, _lp, _rp); :drawn; end
  def update; end
  def tick(text); @sprites["timer"].text = text; update; end
end

# The Cable Club scene's writers, each blocking in the game; the text field returns what was typed.
class AnilCableClubStub
  def pbShowCommands(_helptext, _commands, _cmd_if_cancel = 0); 0; end
  def pbDisplay(_text); :displayed; end
  def pbDisplayDots(_text); :dots; end
  def pbEnterText(_helptext, _starttext, _passwordbox, _maxlength, _regex_check = nil); "12345678"; end
end

module AnilCableClubSpec
  # Runs the block with both scenes stubbed under their names, the profile file loaded once over them.
  def self.with_stubs
    saved = {}
    { :TeamPreview_Scene => AnilTeamPreviewStub, :CableClub_Scene => AnilCableClubStub }.each do |name, stub|
      saved[name] = Object.const_defined?(name) ? Object.const_get(name) : nil
      Object.send(:remove_const, name) if saved[name]
      Object.const_set(name, stub)
    end
    unless $pa_anil_cableclub_loaded
      load File.expand_path("../../../games/anil/cableclub.rb", File.dirname(__FILE__))
      $pa_anil_cableclub_loaded = true
    end
    yield
  ensure
    saved.each do |name, was|
      Object.send(:remove_const, name) if Object.const_defined?(name)
      Object.const_set(name, was) if was
    end
  end
end

Suite.define("anil cable club: the team preview reads both teams, and the countdown's hint once") do
  t = PokeAccess::I18n
  mon = Struct.new(:name, :gender, :item, :mail)
  mon.send(:define_method, :hasItem?) { !item.nil? }
  AnilCableClubSpec.with_stubs do
    scene = TeamPreview_Scene.new
    SpeakCapture.clear
    ret = scene.pbDrawTeamPreviewText("Rojo", "Azul", [mon.new("Pikachu", 0, :LIGHTBALL), mon.new("Magnemite", 2)],
                                      [mon.new("Eevee", 1, :GRASSMAIL, :letter)])
    eq "the card keeps its own return", ret, :drawn
    eq "each trainer's team, the painted signs kept and none for a genderless one, the held-item icon as " \
       "holding one without naming it -- a letter's own for mail -- queued", SpeakCapture.log,
       [[[t.t(:cc_preview_team, :trainer => "Rojo",
              :team => "#{t.t(:cc_preview_holds, :name => "Pikachu \xE2\x99\x82")}, Magnemite"),
          t.t(:cc_preview_team, :trainer => "Azul", :team => t.t(:cc_preview_mail, :name => "Eevee \xE2\x99\x80"))].join(". "), false]]

    SpeakCapture.clear
    scene.tick("<ac>00:30 (pulsa X para salir ya)")
    eq "the countdown's first second says the hint", SpeakCapture.lines, ["00:30 (pulsa X para salir ya)"]
    SpeakCapture.clear
    scene.tick("<ac>00:29 (pulsa X para salir ya)")
    silent "and the seconds after it say nothing"

    PokeAccess::Config.verbosity = :brief
    PokeAccess::Cursor.reset(scene, :cc_timer)
    SpeakCapture.clear
    scene.tick("<ac>00:28 (pulsa X para salir ya)")
    eq "brief: the time, without the key that leaves", SpeakCapture.lines, ["00:28"]
    PokeAccess::Config.verbosity = :full
  end
end

# The code room: the scene writes the field's label on its own message box, never through pbMessage, then blocks in
# the field.
Suite.define("anil cable club: the label over the room's code field is said as the field opens") do
  AnilCableClubSpec.with_stubs do
    SpeakCapture.clear
    ret = CableClub_Scene.new.pbEnterText("Código de la sala:", "", false, 8, /[0-9]/)
    eq "the field keeps its own return", ret, "12345678"
    eq "its label, queued", SpeakCapture.log, [["Código de la sala:", false]]
  end
end
