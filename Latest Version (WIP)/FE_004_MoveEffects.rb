#===============================================================================
# Field Effects Plugin — Move Effects
# File: FE_004_MoveEffects.rb
#
# All field-dependent move mechanics that require runtime hooks:
#   1.  Crystal Cavern type roll        (pbCalcType alias)
#   2.  Short-Circuit electric roll     (pbCalcDamageMultipliers alias)
#   3.  Cave echo boost                 (pbCalcDamageMultipliers alias)
#   4.  Inverse type chart inversion    (pbCalcTypeModSingle alias)
#   5.  Glitch Gen-1 type chart         (pbCalcType + pbCalcTypeModSingle aliases)
#   6.  Glitch rolling damage mult      (pbCalcDamageMultipliers alias)
#   7.  Big Top High Striker            (pbCalcDamageMultipliers + pbBaseDamage aliases)
#   8.  Magic Persona Roll              (pbCalcDamageMultipliers alias)
#   9.  No-charging static table        (supplements FE_002 data-driven :no_charging)
#  10.  Move priority adjustments       (pbPriority alias)
#  11.  Stat stage modifiers table      (pbEffectAfterAllHits alias)
#  12.  ICY contact Speed+1             (pbEffectAfterAllHits alias)
#  13.  Post-move helper module         (FieldEffect::PostMove)
#===============================================================================

#===============================================================================
# 1. CRYSTAL CAVERN — TYPE ROLL
# Rock-type moves and eligible specials get their type randomised from
# [Fire, Water, Grass, Psychic]. Type is cached per-move-execution so
# multi-hit moves stay consistent.
#===============================================================================
class Battle::Move
  alias_method :cc_original_pbCalcType, :pbCalcType
  def pbCalcType(user)
    t = cc_original_pbCalcType(user)

    if @battle.FE == :CRYSTALCAVERN
      eligible = (t == :ROCK) || %i[JUDGMENT STRENGTH ROCKCLIMB MULTIATTACK PRISMATICLASER].include?(@id)
      if eligible
        unless @cc_roll_type_cached
          @cc_roll_type        = @battle.fe.getRoll(update_roll: true)
          @cc_roll_type_cached = true
        end
        return @cc_roll_type || t
      end
    end

    t
  end

  alias_method :cc_original_pbEffectAfterAllHits, :pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
    cc_original_pbEffectAfterAllHits(user, target)
    @cc_roll_type        = nil
    @cc_roll_type_cached = false
  end
end

#===============================================================================
# 4. INVERSE TYPE CHART
#===============================================================================
class Battle::Move
  alias_method :inv_original_pbCalcTypeModSingle, :pbCalcTypeModSingle
  def pbCalcTypeModSingle(move_type, def_type, user, target)
    result = inv_original_pbCalcTypeModSingle(move_type, def_type, user, target)
    return result unless @battle.FE == :INVERSE
    case result
    when Effectiveness::INEFFECTIVE_ONE, 0
      Effectiveness::SUPER_EFFECTIVE_ONE
    when Effectiveness::NOT_VERY_EFFECTIVE_ONE
      Effectiveness::SUPER_EFFECTIVE_ONE
    when Effectiveness::SUPER_EFFECTIVE_ONE
      Effectiveness::NOT_VERY_EFFECTIVE_ONE
    else
      result
    end
  end
end

#===============================================================================
# 5. GLITCH FIELD — GEN-1 TYPE CHART ANOMALIES
# A: Fairy → Normal  B: Dragon always ×1  C: Bug→Poison SE
# D: Ice→Fire neutral  E: Ghost immune to Psychic  F: Poison→Bug SE
# G: Steel resists Ghost/Dark
#===============================================================================
class Battle::Move
  alias_method :glitch_original_pbCalcType, :pbCalcType
  def pbCalcType(user)
    t = glitch_original_pbCalcType(user)
    return :NORMAL if t == :FAIRY && @battle.FE == :GLITCH
    t
  end

  alias_method :glitch_tc_original_pbCalcTypeModSingle, :pbCalcTypeModSingle
  def pbCalcTypeModSingle(move_type, def_type, user, target)
    result = glitch_tc_original_pbCalcTypeModSingle(move_type, def_type, user, target)
    return result unless @battle.FE == :GLITCH
    case move_type
    when :DRAGON
      Effectiveness::NORMAL_EFFECTIVE_ONE
    when :BUG
      def_type == :POISON ? Effectiveness::SUPER_EFFECTIVE_ONE : result
    when :ICE
      (def_type == :FIRE && result == Effectiveness::NOT_VERY_EFFECTIVE_ONE) ?
        Effectiveness::NORMAL_EFFECTIVE_ONE : result
    when :GHOST
      def_type == :PSYCHIC ? Effectiveness::INEFFECTIVE_ONE : result
    when :POISON
      def_type == :BUG ? Effectiveness::SUPER_EFFECTIVE_ONE : result
    when :DARK
      def_type == :STEEL ? (result * Effectiveness::NOT_VERY_EFFECTIVE_ONE / Effectiveness::NORMAL_EFFECTIVE_ONE).round : result
    else
      result
    end
  end
end

#===============================================================================
# 2, 3, 6, 7, 8 — pbCalcDamageMultipliers for roll-based fields
#===============================================================================
class Battle::Move
  alias_method :fe_move_original_pbCalcDamageMultipliers, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe_move_original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    case @battle.FE

    # 2. SHORT-CIRCUIT electric damage roll
    when :SHORTCIRCUIT
      if type == :ELECTRIC
        elec_overlay = (@battle.fe.terrain_overlays[:ELECTERRAIN] || 0) > 0
        roll_val = @battle.fe.getRoll(update_roll: true, maximize_roll: elec_overlay)
        if roll_val
          idx = FE_SHORTCIRCUITROLLS.index(roll_val)
          @battle.pbDisplay(_INTL(FE_SHORTCIRCUIT_MESSAGES[idx])) if idx
          multipliers[:power_multiplier] *= roll_val
        end
      end

    # 3. CAVE echo boost for sound moves
    when :CAVE
      if soundMove?
        multipliers[:power_multiplier] *= 1.5
        @battle.pbDisplay(_INTL("ECHO-Echo-echo!"))
      end

    # 6. GLITCH rolling damage multiplier
    when :GLITCH
      roll_val = @battle.fe.getRoll(update_roll: true)
      if roll_val
        multipliers[:power_multiplier] *= roll_val
        idx = FE_GLITCHROLLS.index(roll_val) || 3
        msg = FE_GLITCH_MESSAGES[idx]
        @battle.pbDisplay(_INTL(msg)) unless msg.empty?
      end

    # 7. BIG TOP — High Striker damage roll
    when :BIGTOP
      if physicalMove? || %i[FIGHTINGTYPE].include?(type)
        atk_stage = user.stages[:ATTACK]
        raw       = rand(1..15) + atk_stage
        raw       = 15 if %i[GUTS HUGEPOWER PUREPOWER SHEERFORCE].any? { |ab| user.hasActiveAbility?(ab) }
        mult_val  = case raw
                    when 1..4  then 0.5
                    when 5..9  then 1.0
                    when 10..12 then 1.5
                    when 13..14 then 1.8
                    else            2.0
                    end
        @battle.pbDisplay(_INTL("DING! The High Striker hit #{mult_val >= 2.0 ? 'MAX!' : mult_val >= 1.5 ? 'High!' : 'Low...'}"))
        multipliers[:power_multiplier] *= mult_val
      end
      if soundMove?
        multipliers[:power_multiplier] *= 1.5
      end

    # 8. MAGIC — Persona roll
    when :MAGIC
      FE_MAGIC_FIXED_MOVES.include?(@id) ? nil : apply_magic_roll(user, type, multipliers)
    end
  end

  private

  def apply_magic_roll(user, type, multipliers)
    tiers = FE_MAGIC_TIERS[type]
    return unless tiers
    sp_stage = user.stages[:SPECIAL_ATTACK] rescue 0
    roll     = rand(1..15) + sp_stage
    if roll < 2
      multipliers[:power_multiplier] *= 0.50
      @battle.pbDisplay(_INTL("You've ran out of Mana!"))
    elsif roll < 5
      multipliers[:power_multiplier] *= 0.75
      @battle.pbDisplay(_INTL("The magic has been drained from you!"))
    else
      tier = tiers.reverse.find { |min, _m, _msg| roll >= min }
      if tier
        multipliers[:power_multiplier] *= tier[1]
        @battle.pbDisplay(_INTL(tier[2])) unless tier[2].empty?
      end
    end
  end
end

#===============================================================================
# 9. NO-CHARGING STATIC TABLE
# Covers fields whose no-charge entries are not yet in FIELDEFFECTS data.
# Supplements the data-driven :no_charging procs from FE_002.
#===============================================================================
module FieldEffect
  NO_CHARGE_TABLE = {
    GRASSY:         { RAZORWIND:     "The grass whipped up a cutting wind instantly!" },
    RAINBOW:        { SOLARBEAM:     "The rainbow let it strike instantly!",
                      SOLARBLADE:    "The rainbow let it strike instantly!" },
    WATERSURFACE:   { DIVE:          "The shallow water allowed instant diving!" },
    UNDERWATER:     { DIVE:          nil },
    CAVE:           { FLY:           "The cave's low ceiling makes flying high impossible!",
                      BOUNCE:        "The cave's low ceiling prevents a high bounce!" },
    DRAGONSDEN:     { FLY:           "The dragon's wrath pulls the attack down instantly!",
                      BOUNCE:        "The scorching lava prevents a high bounce!" },
    FROZENDIMENSION:{ ICEBURN:       "The frozen field charged the attack instantly!",
                      FREEZESHOCK:   "The frozen field charged the attack instantly!" },
    HAUNTED:        { PHANTOMFORCE:  "The haunting allowed instant phasing!",
                      SHADOWFORCE:   "The haunting allowed instant phasing!" },
    SKY:            { RAZORWIND:     "The open skies let it launch instantly!",
                      SKYATTACK:     "The updrafts let it launch instantly!",
                      BOUNCE:        "The open skies let it launch instantly!",
                      FLY:           "The open skies let it soar instantly!" },
    DEEPEARTH:      { GEOMANCY:      "The gravity compressed the energy instantly!" },
    STARLIGHTARENA: { METEORASSAULT: "The starlight let it attack instantly!",
                      METEORBEAM:    "The starlight let it attack instantly!",
                      GEOMANCY:      "The starlight let it charge instantly!",
                      SOLARBEAM:     "The starlight let it strike instantly!",
                      SOLARBLADE:    "The starlight let it strike instantly!" },
    NEWWORLD:       { METEORBEAM:    "The cosmos let the beam fire instantly!" },
  }.freeze
end

# Hook pbIsChargingTurn? to check our static table when data-driven check passes.
# Their 016 conditionally patches this; we add ours on top cleanly.
class Battle::Move::TwoTurnMove
  alias_method :fe_nc_original_pbIsChargingTurn?, :pbIsChargingTurn?

  def pbIsChargingTurn?(user)
    # Data-driven check fires first via their :no_charging effect.
    # If that didn't skip, check our static table.
    if !user.effects[PBEffects::TwoTurnAttack]
      table = FieldEffect::NO_CHARGE_TABLE[@battle.FE] || {}
      if table.key?(@id)
        @powerHerb    = false
        @chargingTurn = true
        @damagingTurn = true
        msg = table[@id]
        @battle.pbDisplay(_INTL(msg)) if msg && !msg.empty?
        user.effects[PBEffects::TwoTurnAttack] = nil
        return false
      end
    end
    fe_nc_original_pbIsChargingTurn?(user)
  end
end

#===============================================================================
# 10. MOVE PRIORITY ADJUSTMENTS
#===============================================================================
class Battle::Move
  alias_method :fe_prio_original_pbPriority, :pbPriority

  def pbPriority(user)
    base = fe_prio_original_pbPriority(user)
    case @battle.FE
    when :GRASSY
      base += 1 if @id == :GRASSYGLIDE && user.grounded?
    when :DIMENSIONAL
      base += 1 if @id == :QUASH
    when :DEEPEARTH
      base += 1 if @id == :COREENFORCER
    end
    base
  end
end

#===============================================================================
# 11. STAT STAGE MODIFIER TABLE
# Extra stages applied on top of the move's normal effect.
# Format: [field_sym, move_sym] => { target: :user/:target, stats: { STAT => stages } }
#===============================================================================
FE_STAT_MODS = {
  [:ELECTERRAIN, :CHARGE]       => { target: :user,   stats: { :SPECIAL_DEFENSE   =>  1 } },
  [:ELECTERRAIN, :EERIEIMPULSE] => { target: :target, stats: { :SPECIAL_ATTACK   => -2 } },
  [:ELECTERRAIN, :ELECTROWEB]   => { target: :target, stats: { :SPEED   => -1 } },
  [:GRASSY, :GROWTH]            => { target: :user,   stats: { :ATTACK  =>  1, :SPECIAL_ATTACK => 1 } },
  [:GRASSY, :COIL]              => { target: :user,   stats: { :ATTACK  =>  1, :DEFENSE => 1 } },
  [:GRASSY, :COTTONSPORE]       => { target: :target, stats: { :SPEED   => -2 } },
  [:MISTY, :COSMICPOWER]        => { target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1 } },
  [:MISTY, :AROMATICMIST]       => { target: :target, stats: { :SPECIAL_DEFENSE   =>  1 } },
  [:MISTY, :SWEETSCENT]         => { target: :target, stats: { :DEFENSE => -1, :SPECIAL_DEFENSE => -1 } },
  [:CHESS, :CALMMIND]           => { target: :user,   stats: { :SPECIAL_ATTACK   =>  1, :SPECIAL_DEFENSE => 1 } },
  [:CHESS, :NASTYPLOT]          => { target: :user,   stats: { :SPECIAL_ATTACK   =>  2 } },
  [:VOLCANIC, :SMOKESCREEN]     => { target: :target, stats: { :ACCURACY => -1 } },
  [:VOLCANICTOP, :SMOKESCREEN]  => { target: :target, stats: { :ACCURACY => -1 } },
  [:SWAMP, :STRUGGLEBUG]        => { target: :target, stats: { :SPEED   => -1 } },
  [:SWAMP, :MUDSHOT]            => { target: :target, stats: { :SPEED   => -1 } },
  [:FACTORY, :METALSOUND]       => { target: :target, stats: { :SPECIAL_DEFENSE   => -1 } },
  [:FACTORY, :IRONDEFENSE]      => { target: :user,   stats: { :DEFENSE =>  1 } },
  [:FACTORY, :SHIFTGEAR]        => { target: :user,   stats: { :SPEED   =>  2 } },
  [:FACTORY, :AUTOTOMIZE]       => { target: :user,   stats: { :SPEED   =>  2 } },
  [:SHORTCIRCUIT, :METALSOUND]  => { target: :target, stats: { :SPECIAL_DEFENSE   => -1 } },
  [:SHORTCIRCUIT, :FLASH]       => { target: :target, stats: { :ACCURACY => -1 } },
  [:ICY, :DEFENSECURL]          => { target: :user,   stats: { :SPEED   =>  1 } },
  [:ICY, :LUNGE]                => { target: :user,   stats: { :SPEED   =>  1 } },
  [:ICY, :ROLLOUT]              => { target: :user,   stats: { :SPEED   =>  1 } },
  [:ICY, :STEAMROLLER]          => { target: :user,   stats: { :SPEED   =>  1 } },
  [:CRYSTALCAVERN, :ROCKPOLISH] => { target: :user,   stats: { :ATTACK  =>  1, :SPECIAL_ATTACK => 1 } },
  [:RAINBOW, :MEDITATE]         => { target: :user,   stats: { :ATTACK  =>  1 } },
  [:RAINBOW, :COSMICPOWER]      => { target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1, :ATTACK => 1, :SPECIAL_ATTACK => 1, :SPEED => 1 } },
  [:BIGTOP, :DRAGONDANCE]       => { target: :user,   stats: { :ATTACK  =>  1, :SPEED => 1 } },
  [:BIGTOP, :QUIVERDANCE]       => { target: :user,   stats: { :SPECIAL_ATTACK   =>  1, :SPECIAL_DEFENSE => 1, :SPEED => 1 } },
  [:BIGTOP, :SWORDSDANCE]       => { target: :user,   stats: { :ATTACK  =>  2 } },
  [:BIGTOP, :FEATHERDANCE]      => { target: :target, stats: { :DEFENSE => -2 } },
  [:COLOSSEUM, :SWORDSDANCE]    => { target: :user,   stats: { :ATTACK  =>  2 } },
  [:COLOSSEUM, :HOWL]           => { target: :user,   stats: { :ATTACK  =>  1 } },
  [:CANYON, :ROCKPOLISH]        => { target: :user,   stats: { :SPEED   =>  2 } },
  [:CANYON, :GROWTH]            => { target: :user,   stats: { :ATTACK  =>  1, :SPECIAL_ATTACK => 1 } },
  [:CANYON, :DEFENDORDER]       => { target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1 } },
  [:BEACH, :CALMMIND]           => { target: :user,   stats: { :SPECIAL_ATTACK   =>  1, :SPECIAL_DEFENSE => 1 } },
  [:BEACH, :MEDITATE]           => { target: :user,   stats: { :ATTACK  =>  2 } },
  [:BEACH, :KINESIS]            => { target: :target, stats: { :ACCURACY => -1 } },
  [:BEACH, :SANDATTACK]         => { target: :target, stats: { :ACCURACY => -1 } },
  [:BACKALLEY, :NASTYPLOT]      => { target: :user,   stats: { :SPECIAL_ATTACK   =>  2 } },
  [:BACKALLEY, :SNARL]          => { target: :target, stats: { :SPECIAL_ATTACK   => -1 } },
  [:BACKALLEY, :PARTINGSHOT]    => { target: :target, stats: { :ATTACK  => -1, :SPECIAL_ATTACK => -1 } },
  [:BACKALLEY, :FAKETEARS]      => { target: :target, stats: { :SPECIAL_DEFENSE   => -1 } },
  [:BACKALLEY, :SMOKESCREEN]    => { target: :target, stats: { :ACCURACY => -1 } },
  [:CITY, :WORKUP]              => { target: :user,   stats: { :ATTACK  =>  1, :SPECIAL_ATTACK => 1 } },
  [:CITY, :SMOKESCREEN]         => { target: :target, stats: { :ACCURACY => -1 } },
  [:DARKCRYSTALCAVERN, :FLASH]  => { target: :target, stats: { :ACCURACY => -1 } },
  [:FOREST, :GROWTH]            => { target: :user,   stats: { :ATTACK  =>  1, :SPECIAL_ATTACK => 1 } },
  [:FOREST, :DEFENDORDER]       => { target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1 } },
  [:FAIRYTALE, :SWORDSDANCE]    => { target: :user,   stats: { :ATTACK  =>  2 } },
  [:DEEPEARTH, :AUTOTOMIZE]     => { target: :user,   stats: { :SPEED   =>  2 } },
  [:DEEPEARTH, :ROTOTILLER]     => { target: :user,   stats: { :SPEED   =>  1 } },
  [:DEEPEARTH, :MAGNETFLUX]     => { target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1 } },
  [:DEEPEARTH, :EERIEIMPULSE]   => { target: :target, stats: { :SPECIAL_ATTACK   => -2 } },
  [:NEWWORLD, :COSMICPOWER]     => { target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1 } },
  [:NEWWORLD, :FLASH]           => { target: :target, stats: { :ACCURACY => -1 } },
  [:STARLIGHTARENA, :COSMICPOWER]=>{ target: :user,   stats: { :DEFENSE =>  1, :SPECIAL_DEFENSE => 1 } },
  [:STARLIGHTARENA, :FLASH]     => { target: :target, stats: { :ACCURACY => -1 } },
  [:INFERNAL, :NASTYPLOT]       => { target: :user,   stats: { :SPECIAL_ATTACK   =>  2 } },
  [:MURKWATERSURFACE, :ACIDARMOR]=>{ target: :user,   stats: { :DEFENSE =>  1 } },
  [:CORROSIVE, :ACIDARMOR]      => { target: :user,   stats: { :DEFENSE =>  1 } },
  [:CORROSIVEMIST, :SMOKESCREEN]=> { target: :target, stats: { :ACCURACY => -1 } },
  [:WATERSURFACE, :TAKEHEART]   => { target: :user,   stats: { :SPECIAL_ATTACK   =>  1 } },
  [:MIRROR, :FLASH]             => { target: :target, stats: { :ACCURACY => -1 } },
  [:HAUNTED, :SCARYFACE]        => { target: :target, stats: { :SPEED   => -2 } },
  [:HAUNTED, :BITTERMALICE]     => { target: :target, stats: { :SPECIAL_ATTACK   => -1 } },
  [:FROZENDIMENSION, :SNARL]    => { target: :target, stats: { :SPECIAL_ATTACK   => -1 } },
  [:FROZENDIMENSION, :PARTINGSHOT]=>{ target: :target,stats: { :SPEED   => -1 } },
}.freeze

class Battle::Move
  alias_method :fe_ss_original_pbEffectAfterAllHits, :pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
    fe_ss_original_pbEffectAfterAllHits(user, target)
    entry = FE_STAT_MODS[[@battle.FE, @id]]
    return unless entry
    applier = entry[:target] == :target ? target : user
    return if applier.nil? || applier.fainted?
    entry[:stats].each do |stat, extra|
      next if extra == 0
      if extra > 0
        next unless applier.pbCanRaiseStatStage?(stat, user)
        applier.pbRaiseStatStageBasic(stat, extra)
      else
        next unless applier.pbCanLowerStatStage?(stat, user)
        applier.pbLowerStatStageBasic(stat, -extra)
      end
    end
  end
end

#===============================================================================
# 12. ICY FIELD — ALL PHYSICAL CONTACT MOVES GRANT Speed+1
#===============================================================================
class Battle::Move
  alias_method :fe_icy_original_pbEffectAfterAllHits, :pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
    fe_icy_original_pbEffectAfterAllHits(user, target)
    return unless @battle.FE == :ICY
    return unless physicalMove? && pbContactMove?(user)
    return unless user.pbCanRaiseStatStage?(:SPEED, user)
    user.pbRaiseStatStageBasic(:SPEED, 1)
    @battle.pbDisplay(_INTL("{1} gained momentum on the ice!", user.pbThis))
  end
end

#===============================================================================
# 13. POST-MOVE HELPER MODULE
# Methods invoked by FIELDEFFECTS :moveEffects eval strings via Battle delegates.
#===============================================================================
module FieldEffect
  module PostMove
    module_function

    def cave_collapse(battle)
      # Earthquake family in Cave — increments collapse counter; collapses at 2.
      battle.fe.counter += 1
      if battle.fe.counter >= 2
        battle.pbDisplay(_INTL("The cave is collapsing!"))
        battle.allBattlers.each do |b|
          next if b.fainted?
          dmg = [(b.totalhp / 4.0).ceil, 1].max
          b.pbReduceHP(dmg, false)
          battle.pbDisplay(_INTL("{1} was hurt by the cave-in!", b.pbThis))
          b.pbFaint if b.fainted?
        end
        battle.create_new_field(:CAVE)
      end
    end

    def mist_explosion(battle)
      return if battle.checkGlobalAbility(:DAMP)
      battle.pbDisplay(_INTL("The toxic mist combusted!"))
      battle.allBattlers.each do |b|
        next if b.fainted? || b.pbHasType?(:POISON)
        dmg = [(b.totalhp / 8.0).ceil, 1].max
        b.pbReduceHP(dmg, false)
        battle.pbDisplay(_INTL("{1} was caught in the explosion!", b.pbThis))
        b.pbFaint if b.fainted?
      end
    end

    def water_pollution(battle)
      battle.pbDisplay(_INTL("The water was tainted!"))
    end

    def eruption_check(battle)
      battle.pbDisplay(_INTL("The volcano is trembling...")) if battle.fe.counter3 == 1
    end

    def progressive(battle, array, start_idx, end_idx)
      # Drives multi-stage fields forward or backward.
      current = array.index(battle.FE) || start_idx
      next_field = array[[current + 1, end_idx].min]
      battle.create_new_field(next_field) if next_field
    end

    def grow_field(battle)
      stages = %i[FLOWERGARDEN1 FLOWERGARDEN2 FLOWERGARDEN3 FLOWERGARDEN4 FLOWERGARDEN5]
      current = stages.index(battle.FE)
      return unless current
      next_s = stages[current + 1]
      battle.create_new_field(next_s) if next_s
    end

    def reduce_field(battle)
      stages = %i[FLOWERGARDEN1 FLOWERGARDEN2 FLOWERGARDEN3 FLOWERGARDEN4 FLOWERGARDEN5]
      current = stages.index(battle.FE)
      return unless current && current > 0
      battle.create_new_field(stages[current - 1])
    end

    def grow_darkness(battle)
      stages = %i[DARKNESS1 DARKNESS2 DARKNESS3]
      current = stages.index(battle.FE)
      return unless current
      next_s = stages[current + 1]
      battle.create_new_field(next_s) if next_s
    end
  end
end
