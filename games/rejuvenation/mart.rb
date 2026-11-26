module PokeAccess
  # Rejuvenation's shops: a shop that takes shards paints the four counts the player holds in the money window as bare
  # numbers, each in its shard's colour (Mart.rb:826-841), said here with the shard each counts.
  module RejuvMart
    SHARDS = [[:ShardRed, :REDSHARD], [:ShardBlue, :BLUESHARD], [:ShardGreen, :GREENSHARD], [:ShardYellow, :YELLOWSHARD]]

    # The colour tags the game paints a shard's count in, with dark and light window skins.
    def self.tags(colour)
      [(ColorTags[colour] rescue nil), (LightColorTags[colour] rescue nil)].compact.uniq
    end

    # The money window's text with each shard's count after the shard's name.
    def self.shards(raw)
      t = raw.to_s
      SHARDS.each do |colour, item|
        name = PokeAccess::Data.item_name(item)
        next if name.nil? || name.to_s.empty?
        tags(colour).each { |tag| t = t.gsub(/#{Regexp.escape(tag)}(\d+)<\/c3>/) { " #{name} #{$1}, " } }
      end
      t
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  override("PokeAccess::InfoWindow", :raw_text) do |_mod, original, args|
    args[0].to_s == "moneywindow" ? PokeAccess::RejuvMart.shards(original.call) : original.call
  end
end
