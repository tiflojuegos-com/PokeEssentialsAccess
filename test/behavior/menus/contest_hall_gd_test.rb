# bo4p5687's Pokemon Contests Script (plugins/contest_hall.rb): the judge's lines from the plugin's own message box,
# the move menu's data, the running order, the heart meters, the applause, the audience's votes, the oblivious marks
# and the results' bars, which the stage shows only as pictures.

# The contest's move data as SetContestMoves reads it from its text file: one array per field, a move per index.
module SetContestMoves
  MOVES = { :id => [:TACKLE, :GROWL, :EMBER], :name => ["Tackle", "Growl", "Ember"],
            :type => ["Tough", "Cute", "Beauty"], :heart => [4, 1, 2], :jam => [0, 3, 1],
            :description => ["A basic appeal.", "Badly startles the Pokemon in front.", "A hot appeal."] }
  def self.r_move; MOVES; end
end

# The stage, down to what the reader hooks: each method changes the state its real one changes (the hearts, the
# applause, the marks, the bars) and paints what it paints. The harness loaded the plugin before this class existed,
# so its hooks on the class are evaluated again over this one.
module ContestHall
  class Show
    attr_accessor :vote_lit, :marked, :results

    def choose_move
      @selection = 0
      :menu
    end

    def set_name_move; :named; end
    def pbDrawText; :drawn; end

    def display_positive_hearts
      bump(@currentpoke, @currenthearts)
    end

    def decrease_hearts(target, _position, _selfjam = nil)
      bump(target, -1)
    end

    def crowd(_move = nil)
      @applause += 1
      @currentpoke = @pkmn2
      @currenthearts = 1
      display_positive_hearts
    end

    def show_heart_vote(_poke, _map); @vote_lit; end

    def oblivious_graphic
      @sprites["oblivioustwo"] = :mark if @marked
      :marks
    end

    # The results: four labels on the text strip, the bars grown to their preliminary lengths between the second and
    # the third, and to their final ones before the winner's.
    def result_scene
      strip = @sprites["textbitmap"].bitmap
      pbDrawTextPositions(strip, [["Announcing the results!", 170, 309, 0, nil, nil]])
      pbDrawTextPositions(strip, [["The preliminary results!", 170, 309, 0, nil, nil]])
      @results[0].each_with_index { |len, i| @sprites["color #{i}"].x = -93 + len }
      pbDrawTextPositions(strip, [["Round 2 results!", 170, 309, 0, nil, nil]])
      @results[1].each_with_index { |len, i| @sprites["color #{i}"].x = -93 + len }
      pbDrawTextPositions(Object.new, [["Elsewhere", 0, 0, 0, nil, nil]])
      pbDrawTextPositions(strip, [["Pikachu is the winner!", 170, 309, 0, nil, nil]])
      :over
    end

    def bump(pkmn, n)
      i = [@pkmn1, @pkmn2, @pkmn3, @pkmn4].index(pkmn)
      iv = :"@pkmn#{i + 1}hearts"
      instance_variable_set(iv, instance_variable_get(iv).to_i + n)
    end
  end
end
show_path = File.join(Harness::ROOT, "plugins", "contest_hall.rb")
show_source = Harness.source(show_path)
show_source.scan(/^PokeAccess::Hooks\.(?:after|around)_hook\("ContestHall::Show".*?^end\r?\n/m) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, show_path, show_source[0, hook.begin(0)].count("\n") + 1)
end

class ContestHallGdTest < PokeAccessTest
  Move = Struct.new(:id, :name)
  Entrant = Struct.new(:name, :moves) do
    def numMoves; moves.length; end
  end
  Sprite = Struct.new(:x, :bitmap)
  Show = ContestHall::Show

  test "each round's menu opens with the round, the painted prompt and the first move, queued" do
    stage = show
    stage.choose_move
    tackle = PokeAccess.sentences(["Tackle, 1 de 3", t(:if2_ct_category, :t => t(:cnd_tough)), t(:if2_ct_appeal, :n => 4),
                                   t(:if2_ct_jam, :n => 0), "A basic appeal."])
    assert_equal [[t(:sv_ct_round, :n => 2, :tot => 5), false], ["Please select a move.", false], [tackle, false]],
                 SpeakCapture.log
  end

  test "moving the cursor says the move with its data at the move reading's level, its repeat marked" do
    stage = show(:@pkmn1lastmove => "Growl")
    stage.choose_move
    SpeakCapture.clear
    stage.instance_variable_set(:@selection, 1)
    rows = vb_levels do
      PokeAccess::Cursor.reset(stage, :chall_move)
      stage.set_name_move
      SpeakCapture.log.pop[0]
    end
    growl = ["Growl, 2 de 3", t(:if2_ct_repeat)]
    cute = t(:if2_ct_category, :t => t(:cnd_cute))
    assert_equal [PokeAccess.sentences(["Growl", t(:if2_ct_repeat)]), PokeAccess.sentences(growl + [cute]),
                  PokeAccess.sentences(growl + [cute, t(:if2_ct_appeal, :n => 1), t(:if2_ct_jam, :n => 3),
                                                "Badly startles the Pokemon in front."])], rows,
                 "brief leaves the place out, as positions are said from medium"
  end

  test "the info key keeps the whole move and the round's standing" do
    stage = show
    PokeAccess::Config.verbosity = :brief
    stage.choose_move
    order = PokeAccess.sentences([t(:if2_ct_order, :list => "Eevee, Pikachu, Ditto, Onix"), t(:sv_ct_place, :n => 2)])
    whole = PokeAccess.sentences(["Tackle", t(:if2_ct_category, :t => t(:cnd_tough)), t(:if2_ct_appeal, :n => 4),
                                  t(:if2_ct_jam, :n => 0), "A basic appeal."])
    assert_equal PokeAccess.sentences([whole, t(:sv_ct_round, :n => 2, :tot => 5), order]), PokeAccess::Info.info_text
    assert_equal whole, PokeAccess::Info.row_text, "Ctrl+T repeats the move alone"
  ensure
    PokeAccess::Config.verbosity = :full
  end

  test "the side panel's running order is said when a repaint changes it, and not after the fifth round" do
    stage = show
    stage.pbDrawText
    stage.pbDrawText
    stage.instance_variable_set(:@round, 6)
    stage.instance_variable_set(:@pokeorder, stage.instance_variable_get(:@pokeorder).reverse)
    stage.pbDrawText
    order = PokeAccess.sentences([t(:if2_ct_order, :list => "Eevee, Pikachu, Ditto, Onix"), t(:sv_ct_place, :n => 2)])
    assert_equal [[order, false]], SpeakCapture.log
  end

  test "a heart meter's change is said with the total it shows; a change that moves nothing is not" do
    stage = show(:@currenthearts => 2)
    stage.instance_variable_set(:@currentpoke, stage.instance_variable_get(:@pkmn1))
    stage.display_positive_hearts
    stage.decrease_hearts(stage.instance_variable_get(:@pkmn1), 2)
    stage.instance_variable_set(:@currenthearts, 0)
    stage.display_positive_hearts
    assert_equal [[t(:if2_ct_hearts, :name => "Pikachu", :n => 2), false],
                  [t(:if2_ct_hearts, :name => "Pikachu", :n => 1), false]], SpeakCapture.log
  end

  test "the crowd's turn says the heart it brings and the applause meter after it, once" do
    stage = show
    stage.crowd
    assert_equal [[t(:if2_ct_hearts, :name => "Eevee", :n => 1), false],
                  [t(:if2_ct_applause, :n => 2, :max => 5), false]], SpeakCapture.log
  end

  test "the audience's hearts for an introduced contestant: a count, all the heart events, or none" do
    stage = show
    eevee = stage.instance_variable_get(:@pkmn2)
    [3, [1, 2, 3, 4, 5, 6], nil].each do |lit|
      stage.vote_lit = lit
      stage.show_heart_vote(eevee, 690)
    end
    assert_equal [3, 6, 0].map { |n| [t(:if2_ct_crowd, :name => "Eevee", :n => n), false] }, SpeakCapture.log
  end

  test "an oblivious mark that appears is said by the contestant in its place; one already up is not" do
    stage = show
    stage.marked = true
    stage.oblivious_graphic
    stage.oblivious_graphic
    assert_equal [[t(:sv_ct_oblivious, :name => "Pikachu"), false]], SpeakCapture.log
  end

  test "the results say each label as painted, after the bars that grew since the last, as shares of the best" do
    stage = show
    stage.results = [[130, 26, 0, 260], [260, 52, 0, 195]]
    assert_equal :over, stage.result_scene
    bars = lambda do |ns|
      %w[Pikachu Eevee Ditto Onix].zip(ns).map { |nm, n| t(:chall_bar, :name => nm, :n => n) }.join(", ")
    end
    assert_equal ["Announcing the results!", "The preliminary results!", bars.call([50, 10, 0, 100]),
                  "Round 2 results!", bars.call([100, 20, 0, 75]), "Pikachu is the winner!"], SpeakCapture.lines
  end

  test "the judge's lines from the contest's message box are said as dialogue, their codes cleaned away" do
    PokeAccess::ContestShow.message("\\l[3]Judge: \\c[1]Alright Pikachu, let's see what you can do!")
    PokeAccess::ContestShow.message(nil)
    assert_equal [["Judge: Alright Pikachu, let's see what you can do!", false]], SpeakCapture.log
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A stage in its second round: Pikachu (the player's, Tackle, Growl and Ember) second of four, the applause at one.
  def show(ivars = {})
    moves = [Move.new(:TACKLE, "Tackle"), Move.new(:GROWL, "Growl"), Move.new(:EMBER, "Ember")]
    pk = [Entrant.new("Pikachu", moves), Entrant.new("Eevee", moves), Entrant.new("Ditto", moves),
          Entrant.new("Onix", moves)]
    stage = Show.new
    sprites = { "textbitmap" => Sprite.new(0, Object.new) }
    4.times { |i| sprites["color #{i}"] = Sprite.new(-93) }
    { :@pkmn1 => pk[0], :@pkmn2 => pk[1], :@pkmn3 => pk[2], :@pkmn4 => pk[3], :@round => 2, :@applause => 1,
      :@pokeorder => [pk[1], pk[0], pk[2], pk[3]], :@sprites => sprites }.merge(ivars).each do |k, v|
      stage.instance_variable_set(k, v)
    end
    stage
  end
end
