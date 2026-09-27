# Rejuvenation's Game Boy Color trainer card (games/rejuvenation/trainer_card_gbc.rb): the front, the Virtual League
# team under the arrow and the summary's three pages, read from the data each face paints. The profile file is loaded
# once, over this stand-in of the scene.
module RejuvCardSpec
  Move = Struct.new(:move, :pp, :maxpp)
  Mon = Struct.new(:species, :name, :level, :hp, :totalhp, :item, :gender, :dexnum, :type1, :type2, :exp, :growthrate,
                   :moves, :attack, :defense, :spatk, :spdef, :speed, :publicID)
  Trainer = Struct.new(:id, :money)
  Trainer.send(:define_method, :publicID) { |id| id % 65536 }
  FUNCS = { :getMonName => lambda { |s| s.to_s.capitalize }, :getTypeName => lambda { |ty| ty.to_s.capitalize },
            :getItemName => lambda { |i| i.to_s.capitalize }, :getMoveName => lambda { |m| m.to_s.capitalize } }
  MALE = "\xE2\x99\x82"

  def self.load_profile
    return if @loaded
    load File.expand_path("../../../games/rejuvenation/trainer_card_gbc.rb", File.dirname(__FILE__))
    @loaded = true
  end

  def self.team
    [Mon.new(:PIKACHU, "Sparky", 20, 50, 55, :LIGHTBALL, :M, 25, :ELECTRIC, nil, 8000, :medium,
             [Move.new(:THUNDERSHOCK, 30, 30), Move.new(:GROWL, 40, 40)], 40, 30, 45, 40, 60, 345),
     Mon.new(:TOTODILE, "Toto", 18, 60, 60, nil, :F, 158, :WATER, nil, 5832, :medium, [Move.new(:SCRATCH, 35, 35)],
             38, 44, 30, 35, 33, 54321)]
  end
end

# The card's faces as the game draws them: two badge icons on the front, CANCEL and the title on the back, whose
# arrow starts on the first member; the summary's page and member changes redraw its header.
class PokemonTrainerCardSceneGBC
  def initialize(team)
    @trainerParty = team; @name = "Ethan"; @playerGender = RejuvCardSpec::MALE; @index = 0; @summaryPage = 0
  end

  def pbDrawTrainerCardFront
    pbDrawImagePositions(nil, [["Graphics/Pictures/Trainer Card/johto//badges", 130, 222, 0, 0, 32, 32],
                               ["Graphics/Pictures/Trainer Card/johto//badges", 194, 222, 32, 0, 32, 32]])
  end

  def pbDrawTrainerCardBack
    pbDrawTextPositions(nil, [["CANCEL", 114, 260, :left], ["VIRTUAL LEAGUE", 256, 296, :center]])
    @index = 0
    changeIndexParty(0)
  end

  def changeIndexParty(increment)
    loop do
      @index += increment
      @index = 0 if @index > 6
      @index = 6 if @index < 0
      break if @index == 6 || @trainerParty[@index]
    end
  end

  def openSummary(i, page); @index = i; @summaryPage = page; drawSummaryHeader; end
  def drawSummaryHeader; nil; end
end

Suite.define("rejuvenation: the GBC trainer card's front, its Virtual League team and the summary's pages") do
  RejuvCardSpec.load_profile
  t = PokeAccess::I18n
  had_trainer = $Trainer
  had_switches = $game_switches
  made = !Object.const_defined?(:PBExp)
  Object.const_set(:PBExp, Module.new { def self.startExperience(level, _rate); level ** 3; end }) if made
  GameFunctions.with(RejuvCardSpec::FUNCS) do
    begin
      $Trainer = RejuvCardSpec::Trainer.new(65536 + 777, 3000)
      $game_switches = {}
      card = PokemonTrainerCardSceneGBC.new(RejuvCardSpec.team)
      SpeakCapture.clear
      card.pbDrawTrainerCardFront
      front = [t.t(:tc_name, :name => "Ethan"), t.t(:tc_id, :id => "00777"), t.t(:tc_money, :n => 3000)]
      eq "the front on opening: name, ID, money and the badges it drew, queued", SpeakCapture.log,
         [[PokeAccess.sentences(front + [t.t(:tr_badges, :n => 2)]), false]]

      SpeakCapture.clear
      card.pbDrawTrainerCardBack
      pika = "#{t.t(:pty_member, :name => 'PIKACHU', :sex => '', :level => 20, :hp => 50, :tot => 55)}, #{t.t(:pty_item)}"
      eq "turned: the title, then the member under the arrow, cutting in", SpeakCapture.log,
         [[PokeAccess.sentences(["VIRTUAL LEAGUE", pika]), true]]
      SpeakCapture.clear
      card.changeIndexParty(1)
      eq "down: the next member", SpeakCapture.lines,
         [t.t(:pty_member, :name => "TOTODILE", :sex => "", :level => 18, :hp => 60, :tot => 60)]
      SpeakCapture.clear
      card.changeIndexParty(1)
      eq "past the team, CANCEL as painted", SpeakCapture.lines, ["CANCEL"]

      SpeakCapture.clear
      card.openSummary(0, 0)
      head = [t.t(:pty_head, :name => "Sparky", :sex => " #{RejuvCardSpec::MALE}", :level => 20),
              t.t(:sum_species, :s => "PIKACHU"), t.t(:sum_dex, :n => 25)]
      info = [t.t(:dbk_hp, :hp => 50, :tot => 55), t.t(:sum_type, :t => "ELECTRIC"), t.t(:sum_exp, :n => 8000),
              t.t(:sum_exp_next, :n => 21 ** 3 - 8000)]
      eq "C on a member: its header and the info page", SpeakCapture.lines, [PokeAccess.sentences(head + info)]
      SpeakCapture.clear
      card.openSummary(0, 1)
      moves = "THUNDERSHOCK, #{t.t(:mv_pp, :pp => 30, :tot => 30)}, GROWL, #{t.t(:mv_pp, :pp => 40, :tot => 40)}"
      eq "right: the moves page alone, the member being the same", SpeakCapture.lines,
         [PokeAccess.sentences([t.t(:sum_item, :i => "LIGHTBALL"), t.t(:sm_moves, :list => moves)])]
      SpeakCapture.clear
      card.openSummary(0, 2)
      stats = "#{t.t(:st_atk)} 40, #{t.t(:st_def)} 30, #{t.t(:rj_gsc_special)} 45, #{t.t(:st_speed)} 60"
      eq "the stats page: the one special, the ID as painted, with no leading zeros, and the trainer", SpeakCapture.lines,
         [PokeAccess.sentences([stats, t.t(:sum_id, :id => "345"), t.t(:sum_ot, :name => "Ethan #{RejuvCardSpec::MALE}")])]
      SpeakCapture.clear
      card.openSummary(1, 2)
      spoke "another member brings its header back", /Toto/

      $game_switches = { :NotPlayerCharacter => true }
      SpeakCapture.clear
      card.pbDrawTrainerCardFront
      eq "someone else's card: the money unknown and no badges, cutting in once turned back", SpeakCapture.log,
         [[PokeAccess.sentences(front[0, 2] + [t.t(:tc_money, :n => t.t(:dex_unknown))]), true]]
    ensure
      $Trainer = had_trainer
      $game_switches = had_switches
      Object.send(:remove_const, :PBExp) if made
    end
  end
end
