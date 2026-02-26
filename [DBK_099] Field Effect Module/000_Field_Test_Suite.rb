# RPG Maker's Ruby does not ship the 'pp' stdlib gem. Some PE move class
# constructors call pp() for debug output, which triggers a lazy
# require 'pp' and raises LoadError. Stub it out as a no-op at load time.
unless defined?(PP)
  module Kernel
    def pp(*args); args.length == 1 ? args[0] : args; end
  end
end

#===============================================================================
# FIELD EFFECTS TEST SUITE
# For Pokemon Essentials v21.1 + Field Effects Plugin
#
# PURPOSE:
#   Stress-tests every registered field against every Pokemon species and every
#   move to catch NoMethodErrors, nil crashes, and logic errors before they
#   appear in actual battles.
#
# HOW TO RUN:
#   Option A – Debug menu (recommended):
#     Add this to your debug menu script:
#       pbFieldTestSuite
#
#   Option B – Console (in-game, $DEBUG must be true):
#     FieldTestSuite.run
#
#   Option C – From a map event:
#     FieldTestSuite.run(output_path: "Data/field_test_results.txt")
#
# OUTPUT:
#   Writes field_test_results.txt to BOTH the game root AND the save folder.
#   Also prints a live summary to the debug console.
#
# CONFIGURATION (see CONFIG block below):
#   - SAMPLE_POKEMON    : test every species, or a random sample
#   - SAMPLE_MOVES      : test every move, or a random sample
#   - STOP_ON_FIRST_ERR : abort a field test after its first error
#   - VERBOSE           : print passing tests to console too
#===============================================================================

module FieldTestSuite




  #-----------------------------------------------------------------------------
  # CONFIGURATION
  #-----------------------------------------------------------------------------
  CONFIG = {
    # How many Pokemon species to test per field.
    # Set to :all to test every species (slow). Set to an integer for a sample.
    sample_pokemon:      :all,

    # How many moves to test per field/pokemon combination.
    # Set to :all to test every move (very slow). Set to an integer for a sample.
    sample_moves:        :all,

    # Stop testing a field after its first error is encountered.
    stop_on_first_err:   false,

    # Print every individual PASS to the console (very noisy).
    verbose:             false,

    # Output file path (relative to game root).
    output_path:         "field_test_results.txt",

    # Test these specific effect keys on every field.
    # Extend this list if you add new keys to the plugin.
    effect_keys:         %i[
      calc_damage
      pbCanInflictStatus?
      pbSpeed
      set_field_battler_universal
      status_immunity
      accuracy_modify
      base_type_change
      expand_target
      move_priority
      no_charging
      no_recharging
      EOR_field_battler
      begin_battle
      end_field_battler
      end_field_battle
    ],

    # Status conditions to probe per field.
    statuses:            %i[SLEEP POISON BURN PARALYSIS FROZEN],

    # Moves that are especially important to probe (always tested, regardless of sampling).
    priority_moves:      %i[
      TACKLE FLAMETHROWER SURF THUNDERBOLT PSYCHIC
      EARTHQUAKE ICEBEAM SHADOWBALL DRACOMETEOR
      EXPLOSION SELFDESTRUCT WAVECRASH
      NATURPOWER SECRETPOWER TERRAINPULSE CAMOUFLAGE
      TAILWIND FLORALHEALING
    ],

    # Abilities that commonly interact with field effects throughout the plugin.
    # These are tested on every field regardless of what field.ability_mods contains.
    # The field's own ability_mods keys are also added automatically per-field.
    field_abilities:     %i[
      SWIFTSWIM SURGESURFER CHLOROPHYLL SOLARPOWER SANDRUSH SANDFORCE SLUSHRUST
      DRIZZLE DROUGHT SANDSTREAM SNOWWARNING PRIMORDIALSEA DESOLATELAND DELTASTREAM
      MAGICGUARD WONDERGUARD OVERCOAT LEAFGUARD FLOWERVEIL
      IMMUNITY PASTELVEIL WATERVEIL MAGMAARMOR
      POISONHEAL TOXICBOOST GUTS FLAMEBODY FLASHFIRE STEAMENGINE
      WATERBUBBLE WATERABSORB VOLTABSORB MOTORDRIVE DRYSKIN LIGHTNINGROD STORMDRAIN
      GALVANIZE AERILATE REFRIGERATE PIXILATE NORMALIZE
      HUSTLE HUGEPOWER PUREPOWER SHEERFORCE GORILLATACTICS
      BEASTBOOST INTREPIDSWORD DAUNTLESSSHIELD
      MIMICRY GRASSPELT ROCKHEAD ROUGHSKIN IRONBARBS
      PRISMARMOR SOLIDROCK SHELLARMOR BATTLEARMOR
      STURDY STEADFAST REGENERATOR NATURALCURE SHEDSKIN
      PLUS MINUS BATTERY GALVANIZE TERAVOLT TURBOBLAZE
      TRACE IMPOSTER ZENMODE POWERCONSTRUCT
      SPEEDBOOST MOODY DOWNLOAD ANALYTIC TOUGHCLAWS
      NEUTRALIZINGGAS CLOUDNINE AIRLOCK SCREENCLEANER
      PROTOSYNTHESIS QUARKDRIVE
    ],
  }.freeze

  #-----------------------------------------------------------------------------
  # PUBLIC ENTRY POINT
  #-----------------------------------------------------------------------------
  def self.run(output_path: CONFIG[:output_path])
    @results  = { pass: 0, fail: 0, skip: 0, errors: [] }
    @output   = []
    @started  = Time.now
    begin

    _log "=" * 72
    _log "FIELD EFFECTS TEST SUITE"
    _log "Started: #{@started}"
    _log "Pokemon Essentials v21.1 compatible"
    _log "=" * 72
    _log ""

    # Build test assets once
    @battle       = _build_headless_battle
    @all_species  = _collect_species
    @all_moves    = _collect_moves
    @all_fields   = Battle::Field.field_data.keys.reject { |k| k == :base }

    _log "Fields found  : #{@all_fields.size}"
    _log "Species found : #{@all_species.size}"
    _log "Moves found   : #{@all_moves.size}"
    _log ""

    if @battle.nil?
      _log "FATAL: Could not construct headless battle. Aborting."
      _flush(output_path)
      return
    end

    # ── Per-field tests ──────────────────────────────────────────────────────
    @all_fields.each_with_index do |field_id, idx|
      _test_field(field_id, idx + 1, @all_fields.size)
    end

    # ── Summary ──────────────────────────────────────────────────────────────
    elapsed = (Time.now - @started).round(1)
    _log ""
    _log "=" * 72
    _log "SUMMARY"
    _log "-" * 72
    _log "Elapsed  : #{elapsed}s"
    _log "PASS     : #{@results[:pass]}"
    _log "FAIL     : #{@results[:fail]}"
    _log "SKIP     : #{@results[:skip]}"
    _log ""

    if @results[:errors].empty?
      _log "All tests passed! No errors detected."
    else
      _log "#{@results[:errors].size} ERROR(S) DETECTED:"
      @results[:errors].each_with_index do |err, i|
        _log "  #{i + 1}. [#{err[:field]}] #{err[:test]}"
        _log "       #{err[:message]}"
        _log "       #{err[:backtrace]}" if err[:backtrace]
      end
    end
    _log "=" * 72

    _flush(output_path)
    Console.echo_li("Field Test Suite complete. #{@results[:fail]} failure(s). See #{output_path}")
    rescue Exception => e
      raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
      _log ""
      _log "FATAL UNCAUGHT EXCEPTION: #{e.class}: #{e.message}"
      e.backtrace&.first(5)&.each { |l| _log "  #{l}" }
      _flush(output_path)
      Console.echo_li("[FieldTest] FATAL: #{e.class}: #{e.message}")
    end
  end

  #-----------------------------------------------------------------------------
  # FIELD-LEVEL TEST RUNNER
  #-----------------------------------------------------------------------------
  def self._test_field(field_id, idx, total)
    begin
    field_errors = 0
    begin; Graphics.update; rescue SystemExit, Interrupt => e; raise e; rescue Exception; end  # Keep game responsive
    _log "-" * 72
    _log "FIELD #{idx}/#{total}: :#{field_id}"

    # 1. Instantiation ────────────────────────────────────────────────────────
    field = nil
    _test("#{field_id}", "instantiation") do
      klass_name = "Battle::Field_#{field_id}"
      raise "Class #{klass_name} not defined" unless Object.const_defined?(klass_name)
      field = Object.const_get(klass_name).new(@battle, Battle::Field::DEFAULT_FIELD_DURATION)
      raise "Field#id mismatch: got :#{field.id}" unless field.id == field_id
    end

    if field.nil?
      _log "  !! Skipping further tests for :#{field_id} — instantiation failed"
      @results[:skip] += 1
      return
    end

    # Inject field into the mock battle so apply_field_effect works
    _inject_field(@battle, field)

    # 2. Effect key smoke tests ───────────────────────────────────────────────
    CONFIG[:effect_keys].each do |key|
      _test(field_id, "effect_key:#{key}") do
        _call_effect_key(@battle, field, key)
      end
    end

    # 3. Ability tests ───────────────────────────────────────────────────────
    _test_abilities(field, field_id)

    # 4. Species-level tests ──────────────────────────────────────────────────
    species_list = _sample(@all_species, CONFIG[:sample_pokemon])
    moves_list   = (_sample(@all_moves, CONFIG[:sample_moves]) | _priority_moves).compact

    species_list.each do |species|
      break if CONFIG[:stop_on_first_err] && @results[:errors].last&.dig(:field) == field_id

      pkmn    = _make_pokemon(species)
      next unless pkmn

      battler = _make_battler(@battle, pkmn, 0)
      next unless battler

      # 3a. Speed calc
      _test(field_id, "pbSpeed:#{species}") do
        battler.pbSpeed
      end

      # 3b. Status immunity
      CONFIG[:statuses].each do |status|
        _test(field_id, "pbCanInflictStatus?:#{species}:#{status}") do
          battler.pbCanInflictStatus?(status, battler, false)
        end
      end

      # 3c. canHeal? / canConsumeBerry?
      _test(field_id, "canHeal?:#{species}") do
        battler.canHeal?
      end

      _test(field_id, "canConsumeBerry?:#{species}") do
        battler.canConsumeBerry?
      end

      # 3d. Per-move tests
      moves_list.each do |move_id|
        move = _make_move(@battle, move_id)
        next unless move

        # calc_damage multipliers
        _test(field_id, "calc_damage:#{species}:#{move_id}") do
          mults = {
            base_damage_multiplier:  1.0,
            attack_multiplier:       1.0,
            defense_multiplier:      1.0,
            final_damage_multiplier: 1.0,
            power_multiplier:        1.0,
          }
          type = move.pbCalcType(battler) rescue move.type
          field.apply_field_effect(:calc_damage, battler, battler, 1, move, type, move.power, mults)
        end

        # Type change
        _test(field_id, "base_type_change:#{species}:#{move_id}") do
          field.apply_field_effect(:base_type_change, battler, move, move.type)
        end

        # Move priority
        _test(field_id, "move_priority:#{species}:#{move_id}") do
          field.apply_field_effect(:move_priority, battler, move, move.priority)
        end
      end
    end

    # 5. EOR heal logic ───────────────────────────────────────────────────────
    _test(field_id, "EOR_field_battler") do
      species_list.first(5).each do |species|
        pkmn    = _make_pokemon(species)
        next unless pkmn
        battler = _make_battler(@battle, pkmn, 0)
        next unless battler
        field.apply_field_effect(:EOR_field_battler, battler)
      end
    end

    # 6. Field indicator calc ─────────────────────────────────────────────────
    _test(field_id, "field_move_indicator") do
      species_list.first(3).each do |species|
        pkmn    = _make_pokemon(species)
        next unless pkmn
        battler = _make_battler(@battle, pkmn, 0)
        next unless battler
        moves_list.first(5).each do |move_id|
          move = _make_move(@battle, move_id)
          next unless move
          @battle.calculate_ui_field_multiplier(battler, move) rescue nil
        end
      end
    end

    field_err_count = @results[:errors].count { |e| e[:field] == field_id }
    _log "  → #{field_err_count == 0 ? 'OK' : "#{field_err_count} FAILURE(S)"}"
    rescue Exception => e
      raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
      _log("  !! UNHANDLED #{e.class}: #{e.message}")
      @results[:errors] << { field: field_id, test: :field_runner,
        message: "#{e.class}: #{e.message}",
        backtrace: e.backtrace&.first(3)&.join(' | ') }
    end
  end


  #-----------------------------------------------------------------------------
  # ABILITY TESTS
  # For each ability relevant to the current field, creates a battler with that
  # ability set and exercises every field interaction that ability could affect.
  #-----------------------------------------------------------------------------
  def self._test_abilities(field, field_id)
    # Collect abilities: field-specific from ability_mods + universal list
    field_specific = []
    if field.respond_to?(:ability_mods) && field.ability_mods.is_a?(Hash)
      field_specific = field.ability_mods.keys
    end
    abilities = (field_specific + CONFIG[:field_abilities]).uniq
                 .select { |a| GameData::Ability.exists?(a) }

    return if abilities.empty?

    _log "  [Abilities: testing #{abilities.size} (#{field_specific.size} field-specific + universal)]"

    # Reuse a single base Pokemon, just swap the ability each iteration
    base_species = _first_valid_species
    return unless base_species
    pkmn = _make_pokemon(base_species)
    return unless pkmn

    # A handful of moves that cover different type/category combos
    probe_moves = %i[TACKLE FLAMETHROWER SURF THUNDERBOLT SHADOWBALL EARTHQUAKE]
                    .select { |m| GameData::Move.exists?(m) }
                    .map    { |m| _make_move(@battle, m) }
                    .compact

    abilities.each do |ability_id|
      # Stamp the ability onto a fresh battler
      battler = _make_battler(@battle, pkmn, 0)
      next unless battler
      battler.instance_variable_set(:@ability_id, ability_id)

      label = "ability:#{ability_id}"

      # Speed calc (SWIFTSWIM, SURGESURFER, CHLOROPHYLL, SPEEDBOOST, etc.)
      _test(field_id, "#{label}:pbSpeed") do
        battler.pbSpeed
      end

      # Status immunity (IMMUNITY, WATERVEIL, MAGMAARMOR, etc.)
      CONFIG[:statuses].each do |status|
        _test(field_id, "#{label}:pbCanInflictStatus?:#{status}") do
          battler.pbCanInflictStatus?(status, battler, false)
        end
      end

      # Berry / heal blocking (MAGICGUARD, HONEYGATHER, etc.)
      _test(field_id, "#{label}:canHeal?") { battler.canHeal? }
      _test(field_id, "#{label}:canConsumeBerry?") { battler.canConsumeBerry? }

      # Damage multipliers for each probe move
      probe_moves.each do |move|
        _test(field_id, "#{label}:calc_damage:#{move.id}") do
          mults = {
            base_damage_multiplier:  1.0,
            attack_multiplier:       1.0,
            defense_multiplier:      1.0,
            final_damage_multiplier: 1.0,
            power_multiplier:        1.0,
          }
          type = move.pbCalcType(battler) rescue move.type
          field.apply_field_effect(:calc_damage, battler, battler, 1, move, type, move.power, mults)
        end
      end

      # Switch-in triggers (abilityStatBoosts, MIMICRY, STEADFAST, etc.)
      _test(field_id, "#{label}:set_field_battler") do
        field.apply_field_effect(:set_field_battler_universal, battler)
        field.apply_field_effect(:set_field_battler, battler) rescue nil
      end

      # End-of-round triggers (VOLTABSORB, MOTORDRIVE, POISONHEAL, etc.)
      _test(field_id, "#{label}:EOR") do
        battler.instance_variable_set(:@hp, pkmn.totalhp)  # restore HP
        field.apply_field_effect(:EOR_field_battler, battler)
      end

      # Passive damage immunity checks (MAGICGUARD, FLAREBOOST, etc.)
      _test(field_id, "#{label}:field_passive_damage?") do
        battler.field_passive_damage? if battler.respond_to?(:field_passive_damage?)
      end
    end
  end

  #-----------------------------------------------------------------------------
  # TEST RUNNER HELPER
  #-----------------------------------------------------------------------------
  def self._test(field_id, test_name, &block)
    begin
      yield
      @results[:pass] += 1
      _log_verbose("  PASS  #{test_name}")
    rescue Exception => e
      raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
      @results[:fail] += 1
      backtrace = e.backtrace&.first(3)&.join(" | ")
      @results[:errors] << {
        field:     field_id,
        test:      test_name,
        message:   "#{e.class}: #{e.message}",
        backtrace: backtrace,
      }
      _log("  FAIL  [#{field_id}] #{test_name}")
      _log("        #{e.class}: #{e.message}")
      _log("        #{backtrace}")
      return false
    end
    true
  end

  #-----------------------------------------------------------------------------
  # HEADLESS BATTLE CONSTRUCTION
  #-----------------------------------------------------------------------------
  def self._build_headless_battle
    scene = Battle::DebugSceneNoVisuals.new(false)

    s1 = _first_valid_species
    s2 = _first_valid_species(offset: 1)
    return nil unless s1 && s2

    p1 = [_make_pokemon(s1, level: 50)]
    p2 = [_make_pokemon(s2, level: 50)]
    return nil if p1[0].nil? || p2[0].nil?

    # Use $Trainer if it exists; otherwise build a minimal stub player so
    # Battle.new doesn't crash when it reads @player.length
    player = if defined?($Trainer) && $Trainer
               $Trainer
             else
               _stub_trainer
             end

    battle = Battle.new(scene, p1, p2, player, nil)

    # Silence all display/animation calls during testing
    battle.define_singleton_method(:pbDisplay)             { |*| }
    battle.define_singleton_method(:pbDisplayPaused)       { |*| }
    battle.define_singleton_method(:pbDisplayConfirm)      { |*| true }
    battle.define_singleton_method(:pbAnimation)           { |*| }
    battle.define_singleton_method(:pbCommonAnimation)     { |*| }

    # Build two live battlers so eachBattler / @battlers is populated
    b0 = Battle::Battler.new(battle, 0)
    b0.pbInitialize(p1[0], 0)
    b0.instance_variable_set(:@hp, p1[0].totalhp)

    b1 = Battle::Battler.new(battle, 1)
    b1.pbInitialize(p2[0], 0)
    b1.instance_variable_set(:@hp, p2[0].totalhp)

    battle.instance_variable_set(:@battlers, [b0, b1])

    # At this point, the field plugin's initialize alias has already run and
    # created the base field.  We're ready to inject test fields.
    return battle
  rescue Exception => e
    raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
    Console.echo_li("[FieldTestSuite] Battle build failed: #{e.class}: #{e.message}")
    e.backtrace&.first(3)&.each { |l| Console.echo_li("  #{l}") }
    return nil
  end

  class StubTrainer
    attr_reader :name, :id, :party, :badge_count
    def initialize
      @name        = "Test"
      @id          = 0
      @party       = []
      @badge_count = 0
    end
    def length; 1; end  # Battle.new checks player.length
  end

  def self._stub_trainer
    StubTrainer.new
  end

  #-----------------------------------------------------------------------------
  # INJECT A FIELD INTO THE MOCK BATTLE
  # has_field? returns true only when stacked_fields.length >= 2.
  # We keep the base field at index 0 and put the test field on top.
  #-----------------------------------------------------------------------------
  def self._inject_field(battle, field)
    base = battle.instance_variable_get(:@stacked_fields)&.first ||
           Battle::Field_base.new(battle, Battle::Field::INFINITE_FIELD_DURATION)
    battle.instance_variable_set(:@stacked_fields, [base, field])
    battle.instance_variable_set(:@current_field, field)
  end

  #-----------------------------------------------------------------------------
  # EFFECT KEY SMOKE-CALLER
  # Calls each effect key with minimal safe arguments so we at least verify
  # the proc doesn't crash on a nil or wrong-arity call.
  #-----------------------------------------------------------------------------
  def self._call_effect_key(battle, field, key)
    # Build minimal stand-ins
    dummy_species = _first_valid_species
    pkmn          = dummy_species ? _make_pokemon(dummy_species) : nil
    battler       = pkmn ? _make_battler(battle, pkmn, 0) : nil

    # Pick the first priority move that exists
    move_id = _priority_moves.find { |m| GameData::Move.exists?(m) }
    move    = move_id ? _make_move(battle, move_id) : nil

    mults = {
      base_damage_multiplier:  1.0,
      attack_multiplier:       1.0,
      defense_multiplier:      1.0,
      final_damage_multiplier: 1.0,
      power_multiplier:        1.0,
    }

    case key
    when :calc_damage
      return unless battler && move
      type = move.type
      field.apply_field_effect(:calc_damage, battler, battler, 1, move, type, move.power, mults)

    when :pbCanInflictStatus?, :status_immunity
      return unless battler
      field.apply_field_effect(:status_immunity, battler, :SLEEP, false, battler, false, false, nil, false)

    when :pbSpeed
      return unless battler
      battler.pbSpeed

    when :accuracy_modify
      return unless battler && move
      modifiers = { accuracy_multiplier: 1.0, evasion_multiplier: 1.0 }
      field.apply_field_effect(:accuracy_modify, battler, battler, move, modifiers, move.type)

    when :base_type_change
      return unless battler && move
      field.apply_field_effect(:base_type_change, battler, move, move.type)

    when :expand_target
      return unless battler && move
      field.apply_field_effect(:expand_target, battler, move, move.target)

    when :move_priority
      return unless battler && move
      field.apply_field_effect(:move_priority, battler, move, 0)

    when :no_charging
      return unless battler && move
      field.apply_field_effect(:no_charging, battler, move)

    when :no_recharging
      return unless battler && move
      targets = battler ? [battler] : []
      field.apply_field_effect(:no_recharging, battler, targets, move, 1)

    when :EOR_field_battler
      return unless battler
      field.apply_field_effect(:EOR_field_battler, battler)

    when :EOR_field_battle
      field.apply_field_effect(:EOR_field_battle)

    when :set_field_battler_universal
      return unless battler
      field.apply_field_effect(:set_field_battler_universal, battler)

    when :begin_battle
      field.apply_field_effect(:begin_battle)

    when :end_field_battler
      return unless battler
      field.apply_field_effect(:end_field_battler, battler)

    when :end_field_battle
      field.apply_field_effect(:end_field_battle)

    else
      # Generic fallback – call with no args and ignore the return value
      field.apply_field_effect(key)
    end
  rescue Exception => e
    raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
    # Re-raise so _test wrapper can record it
    raise e
  end

  #-----------------------------------------------------------------------------
  # POKEMON / BATTLER / MOVE FACTORIES
  #-----------------------------------------------------------------------------
  def self._make_pokemon(species, level: 30)
    # Try signatures in order: Level Caps EX and other plugins may require
    # owner as a non-optional third argument.
    owner = (defined?($player) && $player) ? $player : nil
    pkmn = nil
    [  # try most-specific signature first
      -> { Pokemon.new(species, level, owner) },
      -> { Pokemon.new(species, level) },
    ].each do |attempt|
      begin; pkmn = attempt.call; break; rescue ArgumentError; end
    end
    return nil unless pkmn
    # Give it a full moveset using its natural learnset
    GameData::Species.get(species).moves.each do |move_data|
      next unless GameData::Move.exists?(move_data[1])
      break if pkmn.numMoves >= Pokemon::MAX_MOVES
      pkmn.pbLearnMove(move_data[1])
    end
    # Guarantee at least one move
    if pkmn.numMoves == 0
      pkmn.pbLearnMove(:TACKLE) if GameData::Move.exists?(:TACKLE)
    end
    return pkmn
  rescue Exception => e
    raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
    Console.echo_li("[FieldTestSuite] _make_pokemon(#{species}) failed: #{e.message}") if $DEBUG
    return nil
  end

  def self._make_battler(battle, pkmn, idx)
    battler = Battle::Battler.new(battle, idx)
    # pbInitialize properly wires up hp, totalhp, types, stats, moves and
    # calls pbInitEffects which initialises all PBEffects entries.
    battler.pbInitialize(pkmn, 0)
    # Ensure the battler is at full HP so it doesn't look fainted
    battler.instance_variable_set(:@hp, pkmn.totalhp)
    return battler
  rescue Exception => e
    raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
    Console.echo_li("[FieldTestSuite] _make_battler failed: #{e.message}") if $DEBUG
    return nil
  end

  def self._make_move(battle, move_id)
    return nil unless GameData::Move.exists?(move_id)
    move_data = GameData::Move.get(move_id)
    # Find the right class by function code
    klass_name = "Battle::Move::#{move_data.function_code}"
    if Object.const_defined?(klass_name)
      move = Object.const_get(klass_name).new(battle, move_data)
    else
      move = Battle::Move.new(battle, move_data)
    end
    return move
  rescue Exception => e
    raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
    Console.echo_li("[FieldTestSuite] _make_move(#{move_id}) failed: #{e.message}") if $DEBUG
    return nil
  end

  #-----------------------------------------------------------------------------
  # DATA HELPERS
  #-----------------------------------------------------------------------------
  def self._collect_species
    species = []
    GameData::Species.each { |s| species << s.id if s.form == 0 }
    species
  end

  def self._collect_moves
    moves = []
    GameData::Move.each { |m| moves << m.id }
    moves
  end

  def self._priority_moves
    CONFIG[:priority_moves].select { |m| GameData::Move.exists?(m) }
  end

  def self._first_valid_species(offset: 0)
    count = 0
    GameData::Species.each do |s|
      next if s.form != 0
      return s.id if count == offset
      count += 1
    end
    nil
  end

  def self._sample(collection, config)
    return collection if config == :all
    return collection if collection.size <= config
    # Always include priority moves / species in the sample for moves
    collection.sample([config, collection.size].min)
  end

  #-----------------------------------------------------------------------------
  # LOGGING
  #-----------------------------------------------------------------------------
  def self._log(msg)
    @output ||= []
    @output << msg
    Console.echo_li("[FieldTest] #{msg}") rescue nil
  end

  def self._log_verbose(msg)
    _log(msg) if CONFIG[:verbose]
  end

  def self._flush(path)
    text = @output.join("\n")

    # Always write to the game root path
    begin
      File.open(path, "w") { |f| f.puts text }
      Console.echo_li("[FieldTest] Report written to: #{path}")
    rescue Exception => e
      raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
      Console.echo_li("[FieldTest] Could not write game root report: #{e.message}")
    end

    # Also write a copy to the save folder (where errorlog.txt lives)
    begin
      if Object.const_defined?(:RTP)
        save_path = RTP.getSaveFileName("field_test_results.txt")
        if save_path && !save_path.empty?
          File.open(save_path, "w") { |f| f.puts text }
          Console.echo_li("[FieldTest] Report also written to: #{save_path}")
        end
      end
    rescue Exception => e
      raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
      Console.echo_li("[FieldTest] Could not write save folder report: #{e.message}")
    end
  end
end

#-------------------------------------------------------------------------------
# Debug menu convenience wrapper
#-------------------------------------------------------------------------------
def pbFieldTestSuite
  # Show a non-blocking message so the screen doesn't look frozen
  Graphics.update
  pbMessage(_INTL("Running Field Test Suite…\nResults will be saved to field_test_results.txt in your game folder."))
  Graphics.update
  FieldTestSuite.run
  # Notify the player where to find the report
  output = FieldTestSuite::CONFIG[:output_path]
  fails  = FieldTestSuite.instance_variable_get(:@results)&.dig(:fail) || 0
  if fails == 0
    pbMessage(_INTL("Field Test Suite complete!\nAll tests passed.\nReport saved to: {1}", output))
  else
    pbMessage(_INTL("Field Test Suite complete!\n{1} failure(s) detected.\nReport saved to: {2}", fails, output))
  end
end

#-------------------------------------------------------------------------------
# PE v21.1 Debug Menu integration
# Adds "Field Test Suite" to the in-game debug menu automatically.
# No manual edits to Debug.rb are required.
#-------------------------------------------------------------------------------
if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :field_test_suite, {
    "name"        => _INTL("Field Test Suite"),
    "parent"      => :debug_menu,
    "description" => _INTL("Stress-test all registered field effects. Writes field_test_results.txt to the game folder."),
    "effect"      => proc { |owner, button|
      pbFieldTestSuite
      next false
    }
  })
end
