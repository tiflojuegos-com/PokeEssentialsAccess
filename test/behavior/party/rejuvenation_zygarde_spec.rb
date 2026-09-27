# Rejuvenation's Zygarde page of the summary (games/rejuvenation/zygarde.rb): the page read as painted with the cores
# and types its icons show, and the allocation's selector read as it moves and as a change redraws the page. The
# profile file is loaded once.
module RejuvZygardeSpec
  Form = Struct.new(:investment)
  Form.send(:define_method, :checkFlag?) { |flag| flag == :CoreInvestment ? investment : nil }
  Mon = Struct.new(:name, :customForm, :type1, :type2)
  TYPES = { :getTypeName => lambda { |t| { :DRAGON => "Dragon", :GROUND => "Ground" }[t].to_s } }
  LABELS = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]
  STAT_Y = [76, 108, 140, 172, 204, 236]

  class Selector
    attr_accessor :index, :visible
    def initialize; @index = 0; @visible = false; end
  end

  def self.load_profile
    return if @loaded
    load File.expand_path("../../../games/rejuvenation/zygarde.rb", File.dirname(__FILE__))
    @loaded = true
  end

  # The page's rows: its title, each stat's label and value (right-justified with figure spaces, ten per core), the
  # type, ability and core effect rows, the cores left of five and the hint of the mode it is in.
  def self.paint(pokemon, allocation)
    inv = pokemon.customForm.checkFlag?(:CoreInvestment)
    rows = [["ZYGARDE CORES", 26, 16], ["Zygarde", 46, 62], ["50", 46, 92], ["Cores:", 16, 320],
            [(5 - inv.inject(0) { |a, b| a + b }).to_s, 130, 320]]
    LABELS.each_with_index do |label, i|
      rows.push([label, 240, STAT_Y[i]], [(54 + 10 * inv[i]).to_s.rjust(3, [0x2007].pack("U")), 452, STAT_Y[i]])
    end
    rows.push(["Type", 226, 284], ["Ability", 226, 316], ["Aura Break", 432, 316], ["Core Effect", 226, 348],
              ["+ 10", 432, 348], [allocation ? "Back:  X" : "Assign Cores:  C", 8, 350])
    rows.map { |t, x, y| [t, x, y, 0] }
  end
end

class PokemonSummaryScene
  def drawZygardePage(pokemon, allocation = false)
    return if pokemon.customForm.nil?
    pbDrawTextPositions(nil, RejuvZygardeSpec.paint(pokemon, allocation))
    :drawn
  end
end

Suite.define("rejuvenation zygarde: the page and its core allocation are read as painted") do
  RejuvZygardeSpec.load_profile
  t = PokeAccess::I18n
  cores = lambda { |n| t.t(:rj_zyg_cores, :n => n) }
  GameFunctions.with(RejuvZygardeSpec::TYPES) do
    pk = RejuvZygardeSpec::Mon.new("Zygarde", RejuvZygardeSpec::Form.new([1, 2, 0, 0, 0, 0]), :DRAGON, :GROUND)
    s = PokemonSummaryScene.new(pk)
    sel = RejuvZygardeSpec::Selector.new
    s.instance_variable_set(:@sprites, { "statsel" => sel })
    SpeakCapture.clear
    eq "the page still draws", s.drawZygardePage(pk), :drawn
    stats = ["HP 64, #{cores.call(1)}", "Attack 74, #{cores.call(2)}", "Defense 54, #{cores.call(0)}",
             "Sp. Atk 54, #{cores.call(0)}", "Sp. Def 54, #{cores.call(0)}", "Speed 54, #{cores.call(0)}"]
    page = ["ZYGARDE CORES"] + stats + ["Type Dragon, Ground", "Ability Aura Break", "Core Effect + 10", "Cores: 2",
                                        PokeAccess::KeyHints.gate_sentences("Assign Cores: C")]
    eq "the title, each stat with its cores, the types its icons show, the ability, the effect and the cores left",
       SpeakCapture.lines, [PokeAccess.sentences(page)]

    sel.visible = true
    SpeakCapture.clear
    s.drawZygardePage(pk, true)
    eq "C opens the allocation on its first row, with the cores left and the hint that closes it", SpeakCapture.log,
       [[PokeAccess.sentences([stats[0], "Cores: 2", PokeAccess::KeyHints.gate_sentences("Back: X")]), true]]
    SpeakCapture.clear
    sel.index = 1
    s.pbUpdate
    eq "down says the next row, cutting in", SpeakCapture.log, [[stats[1], true]]
    SpeakCapture.clear
    s.pbUpdate
    silent "once"
    pk.customForm.investment[1] = 3
    s.drawZygardePage(pk, true)
    eq "a core added redraws the page: the row as it now stands and the cores left", SpeakCapture.lines,
       [PokeAccess.sentences(["Attack 84, #{cores.call(3)}", "Cores: 1"])]
    SpeakCapture.clear
    s.pbUpdate
    silent "and the frame after does not repeat it"
    sel.index = 6
    s.pbUpdate
    eq "the type row names its types", SpeakCapture.lines, ["Type Dragon, Ground"]
    SpeakCapture.clear
    sel.index = 7
    s.pbUpdate
    eq "and the ability row its ability", SpeakCapture.lines, ["Ability Aura Break"]

    sel.visible = false
    SpeakCapture.clear
    s.drawZygardePage(pk)
    spoke "leaving reads the page as it now stands", /Attack 84, #{Regexp.escape(cores.call(3))}/
    SpeakCapture.clear
    sel.index = 2
    s.pbUpdate
    silent "and the selector, hidden, says nothing"
    s.drawZygardePage(RejuvZygardeSpec::Mon.new("Pikachu", nil, :ELECTRIC, nil))
    silent "a Pokemon with no cores, reached on this page, paints nothing and is not read"
  end
end
