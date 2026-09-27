# Realidea's Hall of Fame PC viewer card, as painted: species and sex sign, level, nickname, original trainer, moves.
# The profile loads once here; its hooks bind to nothing in this pass.
load File.expand_path("../../../plugins/hall_of_fame_bw_gen6.rb", File.dirname(__FILE__)) unless defined?(PokeAccess::HallOfFameBWGen6)

Suite.define("gen-6 BW hall of fame: the PC viewer's card is read as it is painted") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Chispa", :species => 25, :level => 30, :gender => 0, :moves => [1, 2])
  def pk.ot; "Ash"; end
  def pk.moves; [Struct.new(:id).new(1), Struct.new(:id).new(2), Struct.new(:id).new(0)]; end
  species = PBSpecies.getName(25)
  eq "the species with its sign, the level, the nickname, the trainer and the moves",
     PokeAccess::HallOfFameBWGen6.pc_card(pk),
     ["#{species} \xE2\x99\x82", t.t(:hofbw_level, :n => 30), t.t(:hof_nickname, :name => "Chispa"),
      t.t(:hofbw_ot, :name => "Ash"), t.t(:sm_moves, :list => "#{PBMoves.getName(1)}, #{PBMoves.getName(2)}")].join(", ")

  plain = Poke.build(:name => species, :species => 25, :level => 5, :gender => 2)
  def plain.ot; ""; end
  def plain.moves; []; end
  eq "no nickname said twice, no sign where none is drawn", PokeAccess::HallOfFameBWGen6.pc_card(plain),
     [species, t.t(:hofbw_level, :n => 5)].join(", ")

  rows = vb_levels { PokeAccess::HallOfFameBWGen6.pc_card(pk) }
  eq "brief: the species and the nickname", rows[0], [species, t.t(:hof_nickname, :name => "Chispa")].join(", ")
  eq "medium: and the level", rows[1],
     [species, t.t(:hofbw_level, :n => 30), t.t(:hof_nickname, :name => "Chispa")].join(", ")
  PokeAccess::Config.verbosity = :brief
  PokeAccess::HallOfFameBWGen6.pc_card(pk)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole card", PokeAccess::Info.info_text, rows[2]
end

# The Hall of Fame's saved runs, as the record line counts them.
class Gen6HofGlobal
  attr_accessor :hallOfFame
  def initialize(n); @hallOfFame = Array.new(n) { [] }; end
end

# Input.trigger? answering true for the accept key while a block runs.
module Gen6HofKeys
  @on = false
  def self.on?; @on; end

  def self.accept
    class << Input
      alias_method :pa_hofk_orig_trigger?, :trigger?
      def trigger?(k); (k == Input::C && Gen6HofKeys.on?) || pa_hofk_orig_trigger?(k); end
    end
    @on = true
    yield
  ensure
    @on = false
    class << Input
      alias_method :trigger?, :pa_hofk_orig_trigger?
    end
  end
end

Suite.define("gen-6 BW hall of fame: the PC's record line, and the accept key clicks the front entrant") do
  hof = PokeAccess::HallOfFameBWGen6
  t = PokeAccess::I18n
  saved = $PokemonGlobal
  begin
    $PokemonGlobal = Gen6HofGlobal.new(3)
    scene = Object.new
    scene.instance_variable_set(:@hallIndex, 0)
    scene.instance_variable_set(:@positions, [[256, 250, 1], [100, 200, 0]])
    scene.instance_variable_set(:@selectedrecord, false)
    paint = lambda do |n|
      pbDrawTextPositions(nil, [["HALL DE LA FAMA No.", 16, 0, 0], [format("%03d", n), 192, 0, 0], ["#{n}/3", 118, 344, 2]])
    end
    scene.instance_variable_set(:@hallEntry, [Struct.new(:name).new("Orchynx")])
    record = "HALL DE LA FAMA No. 001. 1/3. #{t.t(:hofbw_team, :list => 'Orchynx')}"
    eq "the first record, as painted with its team, carries the keys", hof.pc_record(scene) { paint.call(1) },
       "#{record}. #{t.t(:hofbw_pc_keys)}"
    scene.instance_variable_set(:@hallIndex, 2)
    eq "and the next ones only the record", hof.pc_record(scene) { paint.call(3) },
       "HALL DE LA FAMA No. 003. 3/3. #{t.t(:hofbw_team, :list => 'Orchynx')}"

    hof.watch(scene)
    falsy "without the key nothing is clicked", hof.pick?([208, 202, 96, 96])
    Gen6HofKeys.accept do
      truthy "the accept key clicks the front entrant", hof.pick?([208, 202, 96, 96])
      falsy "and only that one", hof.pick?([52, 152, 96, 96])
      scene.instance_variable_set(:@selectedrecord, true)
      falsy "nor once a record is picked", hof.pick?([208, 202, 96, 96])
    end
    hof.unwatch
    Gen6HofKeys.accept { falsy "outside the viewer's loop the mouse is left alone", hof.pick?([208, 202, 96, 96]) }
  ensure
    hof.unwatch
    $PokemonGlobal = saved
  end
end

Suite.define("gen-6 BW hall of fame: the entry's closing card is said once it shows, with its key") do
  hof = PokeAccess::HallOfFameBWGen6
  scene = Object.new
  hof.closing_card(scene)
  silent "nothing before the card is painted"
  scene.instance_variable_set(:@access_hof_card, ["¡Felicidades!", "Ayoub", "ID No. 12345", "12:34"])
  hof.closing_card(scene)
  hof.closing_card(scene)
  eq "the card as painted and the key that ends the scene, once, queued", SpeakCapture.log,
     [["¡Felicidades!, Ayoub, ID No. 12345, 12:34. #{PokeAccess::I18n.t(:hofbw_card_key)}", false]]
end
