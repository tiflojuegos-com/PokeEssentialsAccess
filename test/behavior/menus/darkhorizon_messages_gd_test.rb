# Dark Horizon's P*DA (games/darkhorizon/instant_messages.rb): the list of conversations says its title ahead of its
# first row, each row by its title, what its icons mark and its place, a pin as it toggles, and an empty list's
# notice; a conversation opens with its title and every bubble, unread ones after the divider, and a scroll says the
# bubble come to the top.

# The plugin's settings the list reads its title from.
module InstantMessagesSettings
  MESSAGE_LIST_TITLE = "Messages"
end

# A conversation as the list holds it: its title, unread and important marks and its pin, toggled by toggle_pin.
class IMGroup
  attr_accessor :title, :has_unread, :has_important

  def initialize(title, unread = false, important = false, pinned = false)
    @title = title
    @has_unread = unread
    @has_important = important
    @pinned = pinned
  end

  def toggle_pin(val = nil)
    @pinned = val unless val.nil?
    @pinned = !@pinned
  end

  def pinned; @pinned ? true : false; end
end

# The list window: [id, group] pairs and @item_max as its refresh sets it.
class Window_IM_Menu < Window_DrawableCommand
  attr_accessor :item_max

  def initialize(conversations)
    super([])
    @conversations = conversations
    @item_max = conversations.length
  end
end

# The list scene: pbStartScene paints the title (and an empty list's notice) and fades the list in, which reads its row.
class InstantMessagesMenu_Scene
  attr_accessor :sprites

  def initialize(conversations); @conversations = conversations; end

  def pbStartScene
    @sprites = { "itemlist" => Window_IM_Menu.new(@conversations) }
    rows = [["Messages", 256, 6]]
    rows.push(["You have no messages.", 256, 180]) if @conversations.empty?
    pbDrawTextPositions(nil, rows)
    @sprites["itemlist"].update
    :started
  end

  def pbSortConversations; :sorted; end
end

# A bubble window: its text and where it stands; a contact; the divider over the unread bubbles.
class DhBubble
  attr_accessor :text, :y, :height, :visible
  def initialize(text, y); @text = text; @y = y; @height = 40; @visible = true; end
end
DhContact = Struct.new(:name)
class DhDivider
  attr_reader :text
  def initialize(text); @text = text; end
end

# A conversation: pbStartScene stacks the read bubbles, the divider and the unread ones under the top cover, paints the
# title and the divider's word, and scrolls to the top; pbMoveUp and pbMoveDown scroll by 32 pixels.
class InstantMessages_Scene
  TOP = 40

  def initialize(title, members, read, unread, old_scene = nil)
    @title = title; @members = members; @read = read; @unread = unread; @old_scene = old_scene
  end

  def pbStartScene
    @sprites = {}
    @top_margin = TOP
    @old_texts = @read.map { |id, text| [id, :Text, text] }
    @texts = @unread.map { |id, text| [id, :Text, text] }
    y = TOP
    @read.each_with_index { |(_id, text), i| @sprites["oldtext#{i}"] = DhBubble.new(text, y); y += 40 }
    painted = [[@title, 256, 4]]
    if !@read.empty? && !@unread.empty?
      @sprites["unreaddivider"] = DhDivider.new("Unread")
      painted.push(["Unread", 256, y])
      y += 20
    end
    @unread.each_with_index { |(_id, text), i| @sprites["text#{i}"] = DhBubble.new(text, y); y += 40 }
    pbDrawTextPositions(nil, painted)
    pbMoveDown(true)
    :built
  end

  def pbMoveUp(large = false); scroll(-(large ? 160 : 32)); end
  def pbMoveDown(large = false); scroll(large ? 160 : 32); end
  def pbEndScene; :ended; end

  def scroll(by)
    first = @sprites["oldtext0"] || @sprites["text0"]
    by = [by, TOP - first.y].min if by > 0
    @sprites.each_value { |s| s.y += by if s.is_a?(DhBubble) }
    :scrolled
  end
end

# The profile's shared helpers (constants.rb's module), loaded once and without the profile's settings.
unless defined?(PokeAccess::DarkHorizon)
  constants = File.join(Harness::ROOT, "games", "darkhorizon", "constants.rb")
  src = Harness.source(constants)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, constants, src[0, src.index(part)].count("\n") + 1)
end

instant_messages = File.join(Harness::ROOT, "games", "darkhorizon", "instant_messages.rb")
eval(Harness.source(instant_messages), TOPLEVEL_BINDING, instant_messages)

class DarkhorizonMessagesGdTest < PokeAccessTest
  # One contact's conversation, as every chat of the game.
  CODY = [nil, DhContact.new("Cody")].freeze

  test "the list's title comes ahead of its first row, with its keys, both queued" do
    InstantMessagesMenu_Scene.new([[:CODY, IMGroup.new("Cody", true)]]).pbStartScene
    assert_equal [["Messages. #{t(:dh_im_list_keys, :open => 'C', :pin => 'Z', :sort => 'D')}", false],
                  ["Cody, #{t(:dh_im_new)}, #{list_place(1, 1)}", false]], SpeakCapture.log
  end

  test "an empty list says its notice once it is up" do
    PokeAccess::Config.verbosity = :brief
    InstantMessagesMenu_Scene.new([]).pbStartScene
    assert_equal [["Messages", false], ["You have no messages.", false]], SpeakCapture.log
  end

  test "a row names the rival's placeholder by the rival's name, then its important mark and its pin" do
    $game_variables[32] = "Silver"
    win = Window_IM_Menu.new([[:A, IMGroup.new("Cody")], [:RIVAL, IMGroup.new("RIVAL", true, true, true)]])
    assert_equal "Silver, #{t(:dh_im_important)}, #{t(:dh_im_pinned)}, #{list_place(2, 2)}",
                 PokeAccess::DHMessages.list_row(win, 1)
    assert_equal "Cody, #{list_place(1, 2)}", PokeAccess::DHMessages.list_row(win, 0)
  end

  test "toggling a pin says the conversation and its new state, cutting in" do
    grp = IMGroup.new("Cody")
    grp.toggle_pin
    grp.toggle_pin
    assert_equal [[t(:dh_im_pin_on, :title => "Cody"), true], [t(:dh_im_pin_off, :title => "Cody"), true]], SpeakCapture.log
  end

  test "after a sort the row under the cursor is said again" do
    scene = InstantMessagesMenu_Scene.new([[:CODY, IMGroup.new("Cody")]])
    scene.pbStartScene
    SpeakCapture.clear
    scene.pbSortConversations
    scene.sprites["itemlist"].update
    assert_spoken_once(/\ACody/)
  end

  test "a conversation opens with its title and every bubble, the unread ones after the divider, and the keys" do
    InstantMessages_Scene.new("Conversation with Cody", CODY, [[1, "Hi."]], [[1, "Come to\nthe Colosseum!"]]).pbStartScene
    hint = t(:dh_im_chat_keys, :key => "X")
    assert_equal [["Conversation with Cody. Hi. Unread. Come to the Colosseum! #{hint}", false]], SpeakCapture.log,
                 "a bubble that ends its own sentence takes no second period before the keys"
  end

  test "with several writers each bubble is led by who wrote it, the player by name" do
    prior = $player
    $player = Struct.new(:name).new("Wes")
    members = [nil, DhContact.new("Cody"), DhContact.new("Fiona")]
    PokeAccess::Config.verbosity = :brief
    InstantMessages_Scene.new("Group", members, [], [[1, "Hi."], [2, "Hello."], [0, "Hey."]]).pbStartScene
    assert_equal [["Group. Cody: Hi. Fiona: Hello. Wes: Hey.", false]], SpeakCapture.log
  ensure
    $player = prior
  end

  test "a scroll says the bubble come to the top, cutting in, and nothing while the same one stays there" do
    chat = InstantMessages_Scene.new("Conversation with Cody", CODY, [], [[1, "One."], [1, "Two."], [1, "Three."]])
    chat.pbStartScene
    SpeakCapture.clear
    chat.pbMoveDown
    chat.pbMoveUp
    chat.pbMoveDown
    assert_equal [["Two.", true], ["One.", true]], SpeakCapture.log
  end

  test "the info key keeps the conversation, and leaving it drops it and has the list say its row again" do
    list = InstantMessagesMenu_Scene.new([[:CODY, IMGroup.new("Cody")]])
    list.pbStartScene
    chat = InstantMessages_Scene.new("Conversation with Cody", CODY, [], [[1, "One."]], list)
    chat.pbStartScene
    assert_equal "Conversation with Cody. One.", PokeAccess::Info.info_text
    SpeakCapture.clear
    chat.pbEndScene
    list.sprites["itemlist"].update
    assert_spoken_once(/\ACody/)
    refute_equal "Conversation with Cody. One.", PokeAccess::Info.info_text
  end

  test "the screens keep their own returns" do
    chat = InstantMessages_Scene.new("C", CODY, [], [[1, "One."]])
    assert_equal [:started, :built, :scrolled, :ended],
                 [InstantMessagesMenu_Scene.new([]).pbStartScene, chat.pbStartScene, chat.pbMoveUp, chat.pbEndScene]
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
