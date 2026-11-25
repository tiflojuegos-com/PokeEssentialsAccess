class InfiniteFusionTypeExpertsGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    class GameData::Type
      ExpertType = Struct.new(:name, :pseudo_type)
      def self.try_get(id)
        case id
        when :POISON then ExpertType.new("Poison", false)
        when :DARK   then ExpertType.new("Localized Dark", false)
        when :FIRE   then ExpertType.new("", false)
        when :QMARKS then ExpertType.new("Unknown", true)
        end
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    ExpertEvent = Struct.new(:name)
    locator = PokeAccess::Locator
    probe(:experts) do
      [:en, :pl].map do |language|
        PokeAccess::Config.language = language
        %w[TYPE_EXPERT_POISON TYPE_EXPERT_DARK].map { |id| locator.ruled_name(ExpertEvent.new(id)) }
      end
    end
    probe(:unrelated) do
      ["TYPE_EXPERT_UNKNOWN", "TYPE_EXPERT_FIRE", "TYPE_EXPERT_QMARKS", "TYPE_EXPERT_POISON_EXTRA",
       "Trainer", "Poison-type expert"].map { |id| locator.ruled_name(ExpertEvent.new(id)) }
    end
  RUBY

  profile "infinitefusion", WORLD, PLAY, "gamedata"

  test "Type Expert names use the type's displayed name" do
    assert_equal [["Poison-type expert", "Localized Dark-type expert"],
                  ["Ekspert od Pokémonów typu Poison", "Ekspert od Pokémonów typu Localized Dark"]], played(:experts)
  end

  test "other events and absent or pseudo types keep their usual naming" do
    assert_equal [nil, nil, nil, nil, nil, nil], played(:unrelated)
  end
end
