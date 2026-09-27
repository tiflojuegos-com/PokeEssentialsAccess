module PokeAccess
  # Tip Cards (a fangame tutorial-card addon), which draws its cards as bitmap text: the focused card and its group,
  # their texts resolved through the game's own _INTL and cleaned. Royal's menu of the groups seen is its own.

  # The focused tip card's title and body, with its position among several (@pages when kept), or nil.
  def self.tip_card_text(scene)
    tips = PokeAccess.ivar(scene, :@tips)
    idx = PokeAccess.ivar(scene, :@index)
    tip = (tips && idx) ? tips[idx] : nil
    return nil unless tip
    info = (::Settings::TIP_CARDS_CONFIGURATION[tip] rescue nil)
    return nil unless info
    parts = []
    [:Title, :Text].each do |k|
      v = (info[k] rescue nil)
      next if v.nil? || v.to_s.empty?
      s = (_INTL(v) rescue v).to_s
      parts.push(PokeAccess::KeyHints.localize(clean(s), nil, true)) unless s.empty?
    end
    return nil if parts.empty?
    n = (idx.to_i + 1)
    tot = (PokeAccess.ivar(scene, :@pages) || (tips.is_a?(Array) ? tips.length : nil)).to_i
    (tot > 1) ? PokeAccess::Verbosity.list_entry(parts.join(". "), n, tot) : parts.join(". ")
  rescue StandardError
    nil
  end

  # Holds the grouped browser while its loop runs, so the group-list popup hook knows it runs inside that screen.
  module TipCards
    def self.group_on(s); @group = s; end
    def self.group_off; @group = nil; end
    def self.group_scene; @group; end
  end

  # The spoken title of the focused tip-card group (the grouped browser), or nil.
  def self.tip_group_title(scene)
    groups = PokeAccess.ivar(scene, :@groups)
    sec = PokeAccess.ivar(scene, :@section)
    return nil unless groups.is_a?(Array) && sec && groups[sec]
    g = (::Settings::TIP_CARDS_GROUPS[groups[sec]] rescue nil)
    t = (g && g[:Title]) ? (_INTL(g[:Title]) rescue g[:Title]).to_s : nil
    (t && !t.empty?) ? clean(t) : nil
  rescue StandardError
    nil
  end
end

# Individual tip-card screen: read the card on open and each page change. No-op where the addon is absent.
PokeAccess::Hooks.after_hook("TipCard_Scene", :pbDrawTip, :optional => true) do |scene, _r, _a|
  t = PokeAccess.tip_card_text(scene)
  PokeAccess.speak(t, true)
end

# Grouped tip-card browser: pbDrawTip runs on each group or page change; the group title leads when it changed.
PokeAccess::Hooks.after_hook("TipCardGroups_Scene", :pbDrawTip, :optional => true) do |scene, _r, _a|
  sec = PokeAccess.ivar(scene, :@section)
  parts = []
  if sec != scene.instance_variable_get(:@access_tcg_section)
    scene.instance_variable_set(:@access_tcg_section, sec)
    g = PokeAccess.tip_group_title(scene)
    parts.push(g) if g
  end
  c = PokeAccess.tip_card_text(scene)
  parts.push(c) if c && !c.to_s.empty?
  PokeAccess.speak(parts.join(". "), true) unless parts.empty?
end

# Holds the grouped browser for the group-list popup below while its loop runs.
PokeAccess::Hooks.around_hook("TipCardGroups_Scene", :pbScene, :optional => true) do |scene, nxt, _a|
  PokeAccess::TipCards.group_on(scene)
  begin
    nxt.call
  ensure
    PokeAccess::TipCards.group_off
  end
end

# The group-list popup (pbShowCommands) redraws nothing when the same group is picked, so the card is re-read as it
# closes; not wrapped where the plugin's TIP_CARDS_GROUP_LIST turns the popup off.
unless PokeAccess.const_at("TIP_CARDS_GROUP_LIST") == false
  PokeAccess::Hooks.wrap_kernel("pbShowCommands", "hook_tipcards_grouplist", :around) do |_args, nxt|
    ret = nxt.call
    scene = PokeAccess::TipCards.group_scene
    if scene
      t = PokeAccess.tip_card_text(scene)
      PokeAccess.speak(t, true)
    end
    ret
  end
end
