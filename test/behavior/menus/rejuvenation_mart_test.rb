# Rejuvenation's shops (games/rejuvenation/mart.rb): the money window of a shop that takes shards paints the four
# counts held as bare numbers, each in its shard's colour; each is said after its shard's name, with either window skin.
class RejuvenationMartTest < PokeAccessTest
  # The game's colour tags for the shards, with dark and light window skins (DrawText.rb:1205-1206).
  DARK = { :ShardRed => "<c3=BF4D4D,4D1E26>", :ShardBlue => "<c3=4D99BF,1E364D>", :ShardGreen => "<c3=4DBF4D,1E4D1E>",
           :ShardYellow => "<c3=BFBF4D,4D4D1E>" }
  LIGHT = { :ShardRed => "<c3=BA3654,E8B6B1>", :ShardBlue => "<c3=6849CD,BDC1EA>", :ShardGreen => "<c3=36BA54,B1E8B6>",
            :ShardYellow => "<c3=BAAA36,E8E0B1>" }

  class << self
    # The profile's raw_text, kept aside by load_profile.
    attr_reader :raw_text
  end

  # Evaluates the profile file once, as boot does; its raw_text is kept aside and core's put back.
  def self.load_profile
    meta = PokeAccess::InfoWindow.singleton_class
    core = meta.instance_method(:raw_text)
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "mart.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @raw_text = meta.instance_method(:raw_text)
  ensure
    meta.send(:define_method, :raw_text, core)
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "each shard's count is said after the shard's name, with either window skin" do
    names = [:REDSHARD, :BLUESHARD, :GREENSHARD, :YELLOWSHARD].map { |s| PokeAccess::Data.item_name(s) }
    want = "Shards:, #{names[0]} 12, #{names[1]} 3, #{names[2]} 0, #{names[3]} 5"
    [DARK, LIGHT].each do |tags|
      text = "Shards:<br><r>#{tags[:ShardRed]}12</c3>    #{tags[:ShardBlue]}3</c3>    " \
             "#{tags[:ShardGreen]}0</c3>    #{tags[:ShardYellow]}5</c3>"
      assert_equal [[want, false]], said(text), tags.equal?(DARK) ? "dark" : "light"
    end
  end

  test "a money window with no shards is said as painted" do
    assert_equal [["Money:, $3,000", false]], said("Money:<br><r>$3,000")
  end

  private

  # What the shop's money window says with this text, under the game's colour tags and the profile's raw_text.
  def said(text)
    meta = PokeAccess::InfoWindow.singleton_class
    core = meta.instance_method(:raw_text)
    meta.send(:define_method, :raw_text, self.class.raw_text)
    Object.const_set(:ColorTags, DARK)
    Object.const_set(:LightColorTags, LIGHT)
    SpeakCapture.clear
    scene = World.stub_scene(:@sprites => { "moneywindow" => Struct.new(:text).new(text) })
    PokeAccess::InfoWindow.say(scene, "moneywindow", :mart_money, false)
    SpeakCapture.log.dup
  ensure
    meta.send(:define_method, :raw_text, core)
    [:ColorTags, :LightColorTags].each { |c| Object.send(:remove_const, c) if Object.const_defined?(c) }
  end
end
