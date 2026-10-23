# Shared cases of trainer_line_test and trainer_line_gd_test (Info.trainer_info): the named parts in their order, those
# that answer, read off the player and the play time as each engine keeps them; a profile replaces, adds, reorders or
# drops parts, and a part that fails costs only its own fragment.
module TrainerLineCases
  # The GameData-era player (Player): the badges a list that badge_count counts, the Pokedex an object of counts.
  Player = Struct.new(:name, :money, :badges, :pokedex) do
    def badge_count; badges.count { |b| b == true }; end
  end
  Dex = Struct.new(:owned_count, :seen_count)
  # The gen-6 trainer (PokeBattle_Trainer): the badges a list that numbadges counts, holding the Pokedex a flag, and
  # the counts the trainer's own.
  Gen6Trainer = Struct.new(:name, :money, :badges, :pokedex, :pokedexSeen, :pokedexOwned) do
    def numbadges; badges.count { |b| b }; end
  end

  # Defines the shared cases and their helpers on base, the test class of one engine's pass.
  def self.define(base)
    base.class_eval do
      test "says name, money, badges, Pokedex and play time, in that order" do
        with_trainer(trainer) do
          assert_equal sentences("Rojo", money(1500), badges(4), dex(7, 9), playtime(2, 5)),
                       PokeAccess::Info.trainer_info
        end
      end

      test "a part with nothing to say is left out" do
        cases = { "no money" => [trainer(:money => nil), 7500, ["Rojo", badges(4), dex(7, 9), playtime(2, 5)]],
                  "no badge list" => [trainer(:badges => nil), 7500, ["Rojo", money(1500), dex(7, 9), playtime(2, 5)]],
                  "no Pokedex" => [trainer(:dex => nil), 7500, ["Rojo", money(1500), badges(4), playtime(2, 5)]],
                  "no play time" => [trainer, nil, ["Rojo", money(1500), badges(4), dex(7, 9)]] }
        cases.each do |what, (tr, secs, parts)|
          with_trainer(tr, secs) { assert_equal sentences(*parts), PokeAccess::Info.trainer_info, what }
        end
      end

      test "the badges are counted however the player keeps them, its own count before the list" do
        forms = { { :numbadges => 5 } => badges(5), { :badge_count => 6 } => badges(6),
                  { :badges => [true, false, true] } => badges(2),
                  { :numbadges => 1, :badges => [true, true, true] } => badges(1), { :name => "Rojo" } => nil }
        got = forms.map { |fields, _| [fields, PokeAccess::Info.trainer_part(:badges, keeping(fields))] }
        assert_equal forms, got.to_h
      end

      test "the play time is said in whole hours and the minutes past them" do
        { 3599 => playtime(0, 59), 3600 => playtime(1, 0) }.each do |secs, want|
          tr = trainer
          with_trainer(tr, secs) { assert_equal want, PokeAccess::Info.trainer_part(:playtime, tr), "#{secs} s" }
        end
      end

      test "the money is said through the configured money label" do
        with_parts do
          PokeAccess::Config.money_label = :rem_coins
          with_trainer(trainer) do
            assert_equal sentences("Rojo", t(:rem_coins, :n => 1500), badges(4), dex(7, 9), playtime(2, 5)),
                         PokeAccess::Info.trainer_info
          end
        end
      end

      test "a profile's part replaces the shipped one in its place, reading the player it is given" do
        with_parts do
          PokeAccess::Info.set_trainer_part(:badges) { |tr| "Cintas: #{tr.badges.count(true)}" }
          with_trainer(trainer(:badges => 6)) do
            assert_equal sentences("Rojo", money(1500), "Cintas: 6", dex(7, 9), playtime(2, 5)),
                         PokeAccess::Info.trainer_info
          end
        end
      end

      test "a profile's new part joins the end of the line" do
        with_parts do
          PokeAccess::Info.set_trainer_part(:coins) { |_tr| "Monedas: 37" }
          with_trainer(trainer) do
            assert_equal sentences("Rojo", money(1500), badges(4), dex(7, 9), playtime(2, 5), "Monedas: 37"),
                         PokeAccess::Info.trainer_info
          end
        end
      end

      test "the order alone reorders and drops parts" do
        with_parts do
          PokeAccess::Config.trainer_parts = [:playtime, :name]
          with_trainer(trainer) { assert_equal sentences(playtime(2, 5), "Rojo"), PokeAccess::Info.trainer_info }
        end
      end

      test "a part that cannot answer costs only its own fragment" do
        with_parts do
          PokeAccess::Info.set_trainer_part(:boom) { |_tr| raise "reader down" }
          PokeAccess::Info.set_trainer_part(:blank) { |_tr| "" }
          PokeAccess::Info.set_trainer_part(:none) { |_tr| nil }
          with_trainer(trainer) do
            [:boom, :blank, :none, :ghost].each do |part|
              PokeAccess::Config.trainer_parts = [:name, part, :money]
              assert_equal sentences("Rojo", money(1500)), PokeAccess::Info.trainer_info, part.to_s
            end
          end
        end
      end

      test "a line where no part answers is nil, not empty" do
        with_parts do
          PokeAccess::Info.set_trainer_part(:blank) { |_tr| "" }
          PokeAccess::Config.trainer_parts = [:blank]
          with_trainer(trainer) { assert_nil PokeAccess::Info.trainer_info }
        end
      end

      test "there is no trainer line before a game" do
        with_trainer(nil) { assert_nil PokeAccess::Info.trainer_info }
      end

      private

      def t(key, args = {}); PokeAccess::I18n.t(key, args); end

      # Rojo, with 1500 of money, four of eight badges and a Pokedex of seven owned and nine seen, as this engine
      # keeps its player, unless opts say otherwise (:badges a count, :dex [owned, seen]; nil keeps none, which on
      # gen 6 is the Pokedex not yet held, the trainer's counts there all the same).
      def trainer(opts = {})
        o = { :name => "Rojo", :money => 1500, :badges => 4, :dex => [7, 9] }.merge(opts)
        list = o[:badges] && Array.new(8) { |i| i < o[:badges] }
        if ENGINE == :gamedata
          TrainerLineCases::Player.new(o[:name], o[:money], list, o[:dex] && TrainerLineCases::Dex.new(*o[:dex]))
        else
          owned, seen = o[:dex] || [7, 9]
          TrainerLineCases::Gen6Trainer.new(o[:name], o[:money], list, !o[:dex].nil?, seen, owned)
        end
      end

      # A player object that answers only the given fields, each with its value.
      def keeping(fields)
        Struct.new(*fields.keys).new(*fields.values)
      end

      # The shipped parts' fragments, as the mod's language words them.
      def money(n); t(:tr_money, :n => n); end
      def badges(n); t(:tr_badges, :n => n); end
      def dex(owned, seen); t(:tr_pokedex, :owned => owned, :seen => seen); end
      def playtime(h, m); t(:tr_playtime, :h => h, :m => m); end

      # The line the parts make, one sentence each.
      def sentences(*parts); parts.join(". "); end

      # Runs the block with tr as the engine's player and seconds of play time counted where the engine counts them
      # (nil: not counted): on the stats in the GameData era, in the frames played on gen 6, which keeps no stats.
      # All of it put back after.
      def with_trainer(tr, seconds = 7500)
        stats = $stats
        was = swap_player(tr)
        if ENGINE == :gamedata
          $stats = seconds && Struct.new(:play_time).new(seconds)
          yield
        else
          $stats = nil
          with_frame_count(seconds && seconds * Graphics.frame_rate) { yield }
        end
      ensure
        $stats = stats
        swap_player(was)
      end

      # Puts tr where this engine keeps the player ($player in the GameData era, $Trainer before it); answers what
      # was there.
      def swap_player(tr)
        if ENGINE == :gamedata
          was = $player
          $player = tr
        else
          was = $Trainer
          $Trainer = tr
        end
        was
      end

      # Runs the block with Graphics.frame_count answering frames; the engine's own comes back after, or none.
      def with_frame_count(frames)
        meta = Graphics.singleton_class
        was = meta.method_defined?(:frame_count) ? Graphics.method(:frame_count) : nil
        Graphics.define_singleton_method(:frame_count) { frames }
        yield
      ensure
        was ? Graphics.define_singleton_method(:frame_count, was) : meta.send(:remove_method, :frame_count)
      end

      # Runs the block with the part readers, their order and the money label put back after.
      def with_parts
        cfg = PokeAccess::Config
        saved = [cfg.trainer_parts.dup, PokeAccess::Info::TRAINER_PARTS.dup, cfg.money_label]
        yield
      ensure
        cfg.trainer_parts = saved[0]
        PokeAccess::Info::TRAINER_PARTS.replace(saved[1])
        cfg.money_label = saved[2]
      end
    end
  end
end
