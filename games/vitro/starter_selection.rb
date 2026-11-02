# Vitro's copy of DiegoWT's Starter Selection (DiegoWTsStarterSelection, 0301_Starter Intro), an older release than Dark Horizon's,
# with one Pokemon a ball: three closed Poke Balls in a row, moved between with left and right (pbChoosingScene), each opened on
# accept to ask about its Pokemon (pbChooseBall), then a Yes and No of its own (pbConfirm). The ball under the cursor by where it
# stands, the question as the box shows it, and the answer under the cursor.
module PokeAccess
  module VitroStarters
    # Where each ball stands, by its number.
    BALLS = { 1 => :dh_starter_ball_left, 2 => :dh_starter_ball_middle, 3 => :dh_starter_ball_right }

    # The text box's line as painted, without its centring tags.
    def self.box_text(scene)
      box = PokeAccess.sprite(scene, "textbox")
      box ? PokeAccess.clean((box.text rescue "").to_s) : ""
    end

    # The box's request as the balls appear, queued, with the keys while hints are said.
    def self.opened(scene)
      hint = PokeAccess::I18n.t(:dh_starter_keys, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(box_text(scene), hint), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The ball under the cursor, by where it stands and its place, when it changed; the first read queued.
    def self.moved(scene)
      sel = PokeAccess.ivar(scene, :@select)
      return unless BALLS[sel]
      PokeAccess::Cursor.announce(scene, :vitro_starter_ball, sel, true, false) do
        t = PokeAccess::Verbosity.list_entry(PokeAccess::I18n.t(BALLS[sel]), sel, BALLS.length)
        PokeAccess::Info.set_info(:text, t, t)
        t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The opened ball's question as the box shows it, queued, and kept for the info key with the Pokemon's own shine, which only
    # its colours show.
    def self.asked(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      text = box_text(scene)
      text = PokeAccess.sentences([text, PokeAccess::I18n.t(:pk_shiny)]) if pk && PokeAccess::Party.shiny?(pk)
      PokeAccess::Info.set_info(:text, text, text)
      PokeAccess.speak(text, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The answers pbChoiceBoxes painted, kept on the scene for the question's own cursor.
    def self.keep_choices(scene, rows)
      texts = rows.map { |r| PokeAccess.clean(r[0]) }.reject { |t| t.empty? }
      scene.instance_variable_set(:@access_starter_choices, texts) unless texts.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  # pbStartChoosing waits for a first key before the cursor appears on the middle ball.
  before("DiegoWTsStarterSelection", :pbStartChoosing, :optional => true) do |scene, _a|
    PokeAccess::VitroStarters.opened(scene)
  end

  # pbAnimation runs every frame of the choosing loop.
  after("DiegoWTsStarterSelection", :pbAnimation, :optional => true) do |scene, _r, _a|
    PokeAccess::VitroStarters.moved(scene)
  end

  # pbChoiceBoxes(0) shows the Yes and No; pbChoiceBoxes(1) hides them.
  around("DiegoWTsStarterSelection", :pbChoiceBoxes, :optional => true) do |scene, nxt, args|
    ret = nil
    if args[0] == 0
      PokeAccess::VitroStarters.keep_choices(scene, PokeAccess::PaintCapture.sample { ret = nxt.call })
    else
      ret = nxt.call
    end
    ret
  end

  before("DiegoWTsStarterSelection", :pbConfirm, :optional => true) { |scene, _a| PokeAccess::VitroStarters.asked(scene) }

  # A No puts the cursor back on the ball, said again; hook_container, as the question's loop runs inside.
  after("DiegoWTsStarterSelection", :pbChooseBall, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::Cursor.reset(scene, :vitro_starter_ball) if PokeAccess.ivar(scene, :@endscene) == 0
  end

  clear_info_on("DiegoWTsStarterSelection", :pbCloseScene)

  # The question's own Yes and No, @choicesel over what pbChoiceBoxes painted.
  PokeAccess::SceneWatcher.reader("DiegoWTsStarterSelection", :pbConfirm, :vitro_starter_yesno, :optional => true) do |scene|
    labels = PokeAccess.ivar(scene, :@access_starter_choices) || []
    sel = PokeAccess.ivar_i(scene, :@choicesel)
    sel > 0 && labels[sel - 1] ? [sel, labels[sel - 1]] : nil
  end
end
