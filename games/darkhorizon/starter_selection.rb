module PokeAccess
  # Dark Horizon's copy of DiegoWT's Starter Selection (DiegoWTsStarterSelection), an older release edited to hand out
  # a pair: three closed Poke Balls in a row, moved between with left and right (pbChoosingScene), each opened on
  # accept to show its two Pokemon and ask about them (pbChooseBall), then a Yes and No of its own (pbConfirm). The ball
  # under the cursor by where it stands, the pair by the question the box shows with each one's types from medium,
  # and the answer under the cursor.
  module DHStarters
    # Where each ball stands, by its number.
    BALLS = { 1 => :dh_starter_ball_left, 2 => :dh_starter_ball_middle, 3 => :dh_starter_ball_right }

    # The text box's line as painted, without its centring tags.
    def self.box_text(scene)
      box = PokeAccess.sprite(scene, "textbox")
      box ? PokeAccess.clean((box.text rescue "").to_s) : ""
    end

    # The box's request as the balls appear ("Choose your Pokemon."), queued, with the keys while hints are said.
    def self.opened(scene)
      t = box_text(scene)
      hint = PokeAccess::I18n.t(:dh_starter_keys, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::DarkHorizon.hinted(t, hint), false) unless t.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The ball under the cursor, by where it stands and its place, when it changed; the first read queued.
    def self.moved(scene)
      sel = PokeAccess.ivar_i(scene, :@select)
      return unless BALLS[sel]
      PokeAccess::Cursor.announce(scene, :dh_starter_ball, sel, true, false) do
        t = PokeAccess::Verbosity.list_entry(PokeAccess::I18n.t(BALLS[sel]), sel, BALLS.length)
        PokeAccess::Info.set_info(:text, t, t)
        t
      end
    end

    # One of the pair as the reveal shows it, beyond the name the question gives: its name and its types from medium,
    # and from brief when it is shiny, the sprite's colours saying so.
    def self.pair_part(pk)
      return "" unless pk
      shiny = PokeAccess::Party.shiny?(pk)
      name = shiny ? "#{pk.name} #{PokeAccess::I18n.t(:pk_shiny)}" : pk.name.to_s
      PokeAccess::Verbosity.line(:pokemon_choice, [[name, shiny ? :brief : :medium],
                                                   [PokeAccess::Data.pokemon_types(pk).join("/"), :medium]])
    end

    # The opened ball's question: the box's line ("Will you choose X & Y?"), then each of the pair.
    def self.question(scene)
      parts = [box_text(scene)]
      [PokeAccess.ivar(scene, :@pokemon), PokeAccess.ivar(scene, :@pokemon2)].each { |pk| parts.push(pair_part(pk)) }
      PokeAccess.sentences(parts)
    end

    # Says the opened ball's question, queued; the info key keeps it whole.
    def self.asked(scene)
      whole = PokeAccess::Verbosity.whole { question(scene) }
      PokeAccess::Info.set_info(:text, whole, whole)
      PokeAccess.speak(question(scene), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs pbChoiceBoxes' paint, the block, and keeps the Yes and No it paints (keep_choices).
    def self.choices(scene)
      keep_choices(scene, PokeAccess::PaintCapture.sample { yield })
    end

    # Keeps the painted answers on the scene for the question's own cursor.
    def self.keep_choices(scene, rows)
      texts = rows.map { |r| PokeAccess.clean(r[0]) }.reject { |t| t.empty? }
      scene.instance_variable_set(:@access_dh_choices, texts) unless texts.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  # pbStartChoosing waits for a first key before the cursor appears on the middle ball.
  before("DiegoWTsStarterSelection", :pbStartChoosing) { |scene, _a| PokeAccess::DHStarters.opened(scene) }

  # pbAnimation runs every frame of the choosing loop.
  after("DiegoWTsStarterSelection", :pbAnimation) { |scene, _r, _a| PokeAccess::DHStarters.moved(scene) }

  # pbChoiceBoxes(0) shows the Yes and No; pbChoiceBoxes(1) hides them.
  around("DiegoWTsStarterSelection", :pbChoiceBoxes) do |scene, nxt, args|
    if args[0] == 0
      ret = nil
      PokeAccess::DHStarters.choices(scene) { ret = nxt.call }
      ret
    else
      nxt.call
    end
  end

  before("DiegoWTsStarterSelection", :pbConfirm) { |scene, _a| PokeAccess::DHStarters.asked(scene) }

  # A No puts the cursor back on the ball, said again; hook_container, as the question's loop runs inside.
  after("DiegoWTsStarterSelection", :pbChooseBall, :hook_container => true) do |scene, _r, _a|
    PokeAccess::Cursor.reset(scene, :dh_starter_ball) if PokeAccess.ivar_i(scene, :@endscene) == 0
  end

  # The question's own Yes and No, @choicesel over what pbChoiceBoxes painted.
  PokeAccess::SceneWatcher.reader("DiegoWTsStarterSelection", :pbConfirm, :dh_starter_yesno) do |scene|
    labels = PokeAccess.ivar(scene, :@access_dh_choices) || []
    sel = PokeAccess.ivar_i(scene, :@choicesel)
    (sel > 0 && labels[sel - 1]) ? [sel, labels[sel - 1]] : nil
  end
end

PokeAccess::Verbosity.define_reading(:pokemon_choice, :vb_pokemon_choice, :vbh_pokemon_choice, :pokemon)
