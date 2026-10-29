module PokeAccess
  # Dark Horizon's copy of the Instant Messages plugin, its P*DA, edited to the game (the rival's name, its own
  # notification and backgrounds): the list of conversations (InstantMessagesMenu_Scene, its Window_IM_Menu rows) and
  # a conversation (InstantMessages_Scene), whose bubbles all show at once, every chat of the game being instant.
  module DHMessages
    # The name a conversation or contact is shown by: the game swaps its rival's placeholder for the rival's name.
    def self.shown_name(name)
      n = name.to_s
      (n == "RIVAL" && $game_variables) ? $game_variables[32].to_s : n
    end

    # A list row: the conversation's title, what its icons say (an unread message, new or important, and the pin)
    # and its place in the list; the info key keeps it.
    def self.list_row(win, i)
      convs = PokeAccess.ivar(win, :@conversations)
      return nil unless convs.is_a?(Array) && convs[i].is_a?(Array)
      grp = convs[i][1]
      parts = [shown_name(grp.title)]
      parts.push(PokeAccess::I18n.t(grp.has_important ? :dh_im_important : :dh_im_new)) if grp.has_unread
      parts.push(PokeAccess::I18n.t(:dh_im_pinned)) if grp.pinned
      row = PokeAccess::Verbosity.list_entry(parts.join(", "), i + 1, convs.length)
      PokeAccess::Info.set_info(:text, row, row)
      row
    end

    # The list's title as the game paints it (the plugin's MESSAGE_LIST_TITLE), queued ahead of the first row, which
    # the list says while it fades in, with the list's keys while hints are said.
    def self.list_opening
      title = PokeAccess.const_at("InstantMessagesSettings::MESSAGE_LIST_TITLE").to_s
      hint = PokeAccess::I18n.t(:dh_im_list_keys, :open => PokeAccess::KeyHints.key(:c, "C"),
                                :pin => PokeAccess::KeyHints.key(:a, "Z"), :sort => PokeAccess::KeyHints.key(:z, "D"))
      PokeAccess.speak(PokeAccess::DarkHorizon.hinted(title, hint), false) unless title.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # An empty list's notice ("You have no messages."), the painted line under the title, said once the list is up.
    def self.list_empty(scene, rows)
      win = PokeAccess.sprite(scene, "itemlist")
      return unless win && PokeAccess.ivar_i(win, :@item_max) == 0
      title = PokeAccess.const_at("InstantMessagesSettings::MESSAGE_LIST_TITLE").to_s
      t = PokeAccess.sentences((rows || []).reject { |r| r.to_s == title })
      PokeAccess.speak(t, false) unless t.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A pin turned on or off with the action key: the conversation and its new state, cutting in; the row under the
    # cursor, which the sort that follows may change, is then said again.
    def self.pin_toggled(grp)
      key = grp.pinned ? :dh_im_pin_on : :dh_im_pin_off
      PokeAccess.speak(PokeAccess::I18n.t(key, :title => shown_name(grp.title)), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the list's row again on its next update, after a sort or coming back from a conversation.
    def self.reread_list(scene)
      win = PokeAccess.sprite(scene, "itemlist")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win
    end

    # The bubbles a conversation shows, in the order they stand, as [sprite key, contact id, message type]: the read
    # ones, then the unread ones.
    def self.bubbles(scene)
      out = []
      (PokeAccess.ivar(scene, :@old_texts) || []).each_with_index { |m, i| out.push(["oldtext#{i}", m[0], m[1]]) }
      (PokeAccess.ivar(scene, :@texts) || []).each_with_index { |m, i| out.push(["text#{i}", m[0], m[1]]) }
      out.select do |key, _id, _type|
        s = PokeAccess.sprite(scene, key)
        s && (s.visible rescue false)
      end
    end

    # Who wrote a bubble: the player (0), a contact of the conversation (a positive id), nobody for the system's.
    def self.speaker(scene, id)
      return nil if id.nil? || id < 0
      return ($player.name rescue nil) if id == 0
      m = (PokeAccess.ivar(scene, :@members)[id] rescue nil)
      m ? shown_name(m.name) : nil
    end

    # A bubble as said: its text (a picture, briefly), led by who wrote it when the conversation has several writers.
    def self.bubble_line(scene, bubble)
      key, id, type = bubble
      t = type == :Picture ? PokeAccess::I18n.t(:dh_im_picture) : PokeAccess.clean((PokeAccess.sprite(scene, key).text rescue ""))
      who = PokeAccess.ivar(scene, :@access_dh_im_named) ? speaker(scene, id) : nil
      who ? "#{who}: #{t}" : t
    end

    # The bubble at the top of the view: the first one at least half below the screen's top cover.
    def self.top_bubble(scene)
      top = PokeAccess.ivar_i(scene, :@top_margin)
      bubbles(scene).find do |key, _id, _type|
        s = PokeAccess.sprite(scene, key)
        (s.y + s.height / 2) >= top
      end
    end

    # A conversation as it opens: its title as painted, then every bubble in order, the unread ones after the divider
    # the game paints over them, queued, with the keys while hints are said; the info key keeps it all.
    def self.chat_opened(scene, rows)
      list = bubbles(scene)
      writers = list.map { |_key, id, _type| id }.reject { |id| id.nil? || id < 0 }.uniq
      scene.instance_variable_set(:@access_dh_im_named, writers.length > 1)
      parts = [(rows || []).first]
      divider = PokeAccess.sprite(scene, "unreaddivider")
      read_seen = false
      list.each do |b|
        unread = b[0].start_with?("text")
        parts.push(divider.text) if divider && unread && read_seen
        read_seen = !unread
        parts.push(bubble_line(scene, b))
      end
      t = PokeAccess.sentences(parts.compact.map { |p| PokeAccess.clean(p.to_s) })
      PokeAccess::Info.set_info(:text, t, t)
      hint = PokeAccess::I18n.t(:dh_im_chat_keys, :key => PokeAccess::KeyHints.key(:b, "X"))
      PokeAccess.speak(PokeAccess::DarkHorizon.hinted(t, hint), false) unless t.empty?
      top = top_bubble(scene)
      PokeAccess::Cursor.store(scene, :dh_im_top, top[0]) if top
      scene.instance_variable_set(:@access_dh_im_ready, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # After a scroll, the bubble now at the top of the view, cutting in, when it is another one.
    def self.scrolled(scene)
      return unless PokeAccess.ivar(scene, :@access_dh_im_ready)
      top = top_bubble(scene)
      PokeAccess::Cursor.announce(scene, :dh_im_top, top[0], true) { bubble_line(scene, top) } if top
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  screen_reader("Window_IM_Menu") { |win, i| PokeAccess::DHMessages.list_row(win, i) }

  around("InstantMessagesMenu_Scene", :pbStartScene) do |scene, nxt, _a|
    PokeAccess::DHMessages.list_opening
    PokeAccess::PaintCapture.arm(:dh_im_list)
    ret = nil
    begin
      ret = nxt.call
    ensure
      rows = PokeAccess::PaintCapture.take(:dh_im_list, :positions)
    end
    PokeAccess::DHMessages.list_empty(scene, rows)
    ret
  end

  after("IMGroup", :toggle_pin) { |grp, _r, _a| PokeAccess::DHMessages.pin_toggled(grp) }
  after("InstantMessagesMenu_Scene", :pbSortConversations) { |scene, _r, _a| PokeAccess::DHMessages.reread_list(scene) }

  # pbStartScene builds the conversation and returns before pbScene's loop; its title and the unread divider are the
  # pbDrawTextPositions rows it paints.
  around("InstantMessages_Scene", :pbStartScene) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:dh_im_chat)
    ret = nil
    begin
      ret = nxt.call
    ensure
      rows = PokeAccess::PaintCapture.take(:dh_im_chat, :positions)
    end
    PokeAccess::DHMessages.chat_opened(scene, rows)
    ret
  end

  after("InstantMessages_Scene", :pbMoveUp) { |scene, _r, _a| PokeAccess::DHMessages.scrolled(scene) }
  after("InstantMessages_Scene", :pbMoveDown) { |scene, _r, _a| PokeAccess::DHMessages.scrolled(scene) }

  # Leaving a conversation drops it from the info key and the bubble last said, and the list it was opened from says
  # its row again.
  before("InstantMessages_Scene", :pbEndScene) do |scene, _a|
    PokeAccess::Info.clear_text
    PokeAccess::Cursor.reset(scene, :dh_im_top)
    old = PokeAccess.ivar(scene, :@old_scene)
    PokeAccess::DHMessages.reread_list(old) if old
  end
end
