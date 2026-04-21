#===============================================================================
# Field Effects Plugin — Status, Weather and Special Mechanics
# File: FE_008_StatusWeather.rb
#
#   1. Status immunities
#        VOLCANIC: cannot inflict Frozen
#        BEACH:    Fighting-types + Inner Focus immune to Confusion
#
#   2. Extended weather durations via pbStartWeather alias
#
#   3. Sky Field — Tailwind lasts 8 turns
#
#   4. Cave — Ground moves hit airborne Pokémon
#
#   5. Cave — Stealth Rock deals 2× damage
#
#   6. Glitch Field — Recharge cancel (25% chance skip on HyperBeam etc.)
#
#   7. Superheated — Thrash / Outrage / Petal Dance fatigue after 1 turn
#
# NOTE: Their 011_FieldBattleHooks already wraps pbCanInflictStatus? to check
# PBS status_immunities.  Since our fields are not PBS-backed, we add our own
# aliases which chain after theirs.
#===============================================================================

#===============================================================================
# 1. STATUS IMMUNITIES
#===============================================================================
class Battle::Battler
  alias_method :fe_sw_original_pbCanInflictStatus?, :pbCanInflictStatus?

  def pbCanInflictStatus?(new_status, user, show_messages, move = nil, ignore_status = false)
    # VOLCANIC: Frozen cannot be inflicted.
    if new_status == :FROZEN && @battle.FE == :VOLCANIC
      if show_messages
        @battle.pbDisplay(_INTL("The volcanic heat prevents freezing!", pbThis))
      end
      return false
    end

    fe_sw_original_pbCanInflictStatus?(new_status, user, show_messages, move, ignore_status)
  end

  alias_method :fe_sw_original_pbCanConfuse?, :pbCanConfuse?

  def pbCanConfuse?(user = nil, show_messages = true, move = nil, self_inflicted = false)
    if @battle.FE == :BEACH
      if pbHasType?(:FIGHTING) || hasActiveAbility?(:INNERFOCUS)
        if show_messages
          @battle.pbDisplay(_INTL("The Beach's focus prevents {1} from becoming confused!", pbThis(true)))
        end
        return false
      end
    end
    fe_sw_original_pbCanConfuse?(user, show_messages, move, self_inflicted)
  end
end

#===============================================================================
# 2. EXTENDED WEATHER DURATIONS
# After pbStartWeather sets the duration, we extend it for specific fields.
#===============================================================================
class Battle
  FIELD_WEATHER_EXTENSIONS = {
    [:DESERT,        :Sun]         => 8,
    [:DESERT,        :HarshSun]    => 8,
    [:DESERT,        :Sandstorm]   => 8,
    [:ICY,           :Hail]        => 8,
    [:ICY,           :Snow]        => 8,
    [:SNOWYMOUNTAIN, :Sun]         => 8,
    [:SNOWYMOUNTAIN, :HarshSun]    => 8,
    [:SNOWYMOUNTAIN, :Hail]        => 8,
    [:SNOWYMOUNTAIN, :Snow]        => 8,
    [:MOUNTAIN,      :Sun]         => 8,
    [:MOUNTAIN,      :HarshSun]    => 8,
    [:SKY,           :Sun]         => 8,
    [:SKY,           :HarshSun]    => 8,
    [:SKY,           :Rain]        => 8,
    [:SKY,           :HeavyRain]   => 8,
    [:SKY,           :Sandstorm]   => 8,
    [:SKY,           :Hail]        => 8,
    [:SKY,           :Snow]        => 8,
    [:SKY,           :StrongWinds] => 8,
    [:BEACH,         :Sandstorm]   => 8,
    [:BIGTOP,        :Rain]        => 8,
    [:BIGTOP,        :HeavyRain]   => 8,
  }.freeze

  alias_method :fe_sw_original_pbStartWeather, :pbStartWeather

  def pbStartWeather(user, new_weather, fixed_duration = false, show_anim = true)
    fe_sw_original_pbStartWeather(user, new_weather, fixed_duration, show_anim)
    ext = FIELD_WEATHER_EXTENSIONS[[FE, new_weather]]
    if ext && @field.weatherDuration > 0 && @field.weatherDuration < ext
      @field.weatherDuration = ext
    end
  end
end

#===============================================================================
# 3. SKY FIELD — TAILWIND LASTS 8 TURNS
#===============================================================================
class Battle::Move::StartUserSideDoubleSpeed   # Tailwind function code
  alias_method :fe_sky_tailwind_original, :pbEffectGeneral

  def pbEffectGeneral(user)
    fe_sky_tailwind_original(user)
    user.pbOwnSide.effects[PBEffects::Tailwind] = 8 if @battle.FE == :SKY
  end
end

#===============================================================================
# 4. CAVE — GROUND MOVES HIT AIRBORNE POKÉMON
# When the Cave field is active, Ground-type moves bypass the Flying immunity
# and Levitate effect (low ceiling prevents levitation).
#===============================================================================
class Battle::Move
  alias_method :fe_cave_ground_original_pbCalcTypeModSingle, :pbCalcTypeModSingle

  def pbCalcTypeModSingle(move_type, def_type, user, target)
    result = fe_cave_ground_original_pbCalcTypeModSingle(move_type, def_type, user, target)
    # Restore neutral effectiveness if the Cave field would suppress immunity for Ground moves.
    if @battle.FE == :CAVE && move_type == :GROUND && target.airborne?
      if result <= Effectiveness::INEFFECTIVE_ONE
        return Effectiveness::NORMAL_EFFECTIVE_ONE
      end
    end
    result
  end
end

#===============================================================================
# 5. CAVE — STEALTH ROCK 2× DAMAGE
# Hooks the entry hazard damage so SR deals double in the Cave.
#===============================================================================
class Battle
  alias_method :fe_cave_sr_original_pbOnBattlerEnteringBattle, :pbOnBattlerEnteringBattle

  def pbOnBattlerEnteringBattle(idx_battler, *args)
    @_cave_sr_battler_idx = idx_battler
    fe_cave_sr_original_pbOnBattlerEnteringBattle(idx_battler, *args)
    @_cave_sr_battler_idx = nil
  end

end

# CAVE — double Stealth Rock damage via pbEntryHazards hook
module Battle::FE_CaveStealthRockHook
  def pbEntryHazards(battler)
    if respond_to?(:FE) && FE == :CAVE
      battler_side = battler.pbOwnSide
      if battler_side.effects[PBEffects::StealthRock] && battler.takesIndirectDamage? &&
         GameData::Type.exists?(:ROCK) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS)
        bTypes = battler.pbTypes(true)
        eff = Effectiveness.calculate(:ROCK, *bTypes)
        unless Effectiveness.ineffective?(eff)
          # Deal double damage (base is totalhp * eff / 8, so *2 = totalhp * eff / 4)
          battler.pbReduceHP(battler.totalhp * eff / 4, false)
          pbDisplay(_INTL("Pointed stones dug into {1}!", battler.pbThis))
          battler.pbItemHPHealCheck
          # Prevent the standard Stealth Rock from firing again
          battler_side.effects[PBEffects::StealthRock] = false
          super
          battler_side.effects[PBEffects::StealthRock] = true
          return
        end
      end
    end
    super
  end
end
Battle.prepend(Battle::FE_CaveStealthRockHook)

#===============================================================================
# 6. GLITCH FIELD — RECHARGE CANCEL
# Each turn, a Pokémon that needs to recharge has a 25% chance to skip it.
#===============================================================================
class Battle::Battler
  alias_method :fe_glitch_original_pbUseMove, :pbUseMove

  def pbUseMove(choice, specialUsage = false)
    if @battle.FE == :GLITCH && (@effects[PBEffects::TwoTurnAttack] || 0) > 0
      if @battle.pbRandom(4) == 0
        @effects[PBEffects::TwoTurnAttack] = 0
        @battle.pbDisplay(_INTL("The glitch corrupted {1}'s recharge!", pbThis(true)))
      end
    end
    fe_glitch_original_pbUseMove(choice, specialUsage)
  end
end

#===============================================================================
# 7. SUPERHEATED — THRASH / OUTRAGE / PETAL DANCE FATIGUE AFTER 1 TURN
# MultiTurn counter is forced to 1 so the move ends this turn.
#
# FIX: MultiTurnAttackOrRestoreHPAtEnd does not define pbEffectAgainstTarget.
#      These moves use PBEffects::Outrage (not TwoTurnAttack) and manage their
#      counter in pbEffectGeneral (init) / pbEffectAfterAllHits (decrement).
#      We prepend into pbEffectGeneral so the counter is capped to 1 right
#      after it is initialised, causing the move to fatigue this same turn.
#===============================================================================
module Battle::Move::FE_SuperheatedMultiTurnFix
  def pbEffectGeneral(user)
    super
    if @battle.FE == :SUPERHEATED && (user.effects[PBEffects::Outrage] || 0) > 1
      user.effects[PBEffects::Outrage] = 1
    end
  end
end

class Battle::Move::MultiTurnAttackOrRestoreHPAtEnd
  prepend Battle::Move::FE_SuperheatedMultiTurnFix
end

#===============================================================================
# SWITCH-IN STAT BOOSTS — field-dependent ability activations on entry
# Registered via Battle's pbOnBattlerEnteringBattle alias so they fire
# after all switch-in effects but before the first move.
#===============================================================================

# Switch-in stat boost table:
# { field_sym => { ability_sym => { stat => stages, ... }, ... }, ... }
FE_SWITCHIN_STAT_BOOSTS = {
  ELECTERRAIN: {
    STEADFAST:   { :SPEED => 1 },
    LIGHTNINGROD:{ :SPECIAL_ATTACK => 1 },
  },
  FAIRYTALE: {
    BATTLEARMOR: { :DEFENSE => 1 },
    SHELLARMOR:  { :DEFENSE => 1 },
    MAGICGUARD:  { :SPECIAL_DEFENSE  => 1 },
    MAGICBOUNCE: { :SPECIAL_DEFENSE  => 1 },
    MIRRORARMOR: { :SPECIAL_DEFENSE  => 1 },
    PASTELVEIL:  { :SPECIAL_DEFENSE  => 1 },
    MAGICIAN:    { :SPECIAL_ATTACK  => 1 },
  },
  BACKALLEY: {
    PICKPOCKET:  { :ATTACK => 1 },
    MERCILESS:   { :ATTACK => 1 },
    MAGICIAN:    { :SPECIAL_ATTACK  => 1 },
    ANTICIPATION:{ :DEFENSE => 1 },
    FOREWARN:    { :DEFENSE => 1 },
    RATTLED:     { :SPEED  => 1 },
  },
  CITY: {
    EARLYBIRD:   { :ATTACK => 1 },
    BIGPECKS:    { :DEFENSE => 1 },
    RATTLED:     { :SPEED  => 1 },
  },
  PSYCHIC: {
    ANTICIPATION: { :SPECIAL_ATTACK => 1 },
    FOREWARN:     { :SPECIAL_ATTACK => 1 },
    MAGICIAN:     { :SPECIAL_ATTACK => 1 },
    MINDSEYE:     { :SPECIAL_ATTACK => 1 },
    MAGICBOUNCE:  { :SPECIAL_DEFENSE => 1 },
    MAGICGUARD:   { :SPECIAL_DEFENSE => 1 },
  },
  DEEPEARTH: {
    SLOWSTART:   { :SPEED => -6, :EVASION => -6 },
  },
  MISTY: {
    WATERCOMPACTION: { :DEFENSE => 2 },
  },
  BEWITCHED: {
    POWERSPOTCH: { :SPECIAL_ATTACK => 1 },  # Power Spot switch-in on Bewitched
  },
}.freeze

class Battle
  alias_method :fe_switchin_original_pbOnBattlerEnteringBattle, :pbOnBattlerEnteringBattle

  def pbOnBattlerEnteringBattle(idxBattler, *args)
    fe_switchin_original_pbOnBattlerEnteringBattle(idxBattler, *args)
    return unless has_field?
    battler = @battlers[idxBattler]
    return unless battler && !battler.fainted?

    boosts = FE_SWITCHIN_STAT_BOOSTS[current_field.id] || {}
    boosts.each do |ability, stat_hash|
      next unless battler.hasActiveAbility?(ability)
      stat_hash.each do |stat, stages|
        if stages > 0
          next unless battler.pbCanRaiseStatStage?(stat, battler)
          battler.pbRaiseStatStageBasic(stat, stages)
          pbCommonAnimation("StatUp", battler, nil)
        elsif stages < 0
          next unless battler.pbCanLowerStatStage?(stat, battler)
          battler.pbLowerStatStageBasic(stat, -stages)
          pbCommonAnimation("StatDown", battler, nil)
        end
      end
      pbDisplay(_INTL("{1}'s {2} activated!", battler.pbThis, battler.abilityName))
    end

    # Darmanitan Zen Mode form change on entry to BEACH / PSYCHIC fields
    if [:BEACH, :PSYCHIC].include?(current_field.id)
      if battler.isSpecies?(:DARMANITAN) && battler.hasActiveAbility?(:ZENMODE)
        if battler.form != 1 && battler.hp <= battler.totalhp / 2
          battler.pbChangeForm(1, _INTL("{1} calmed its mind and entered Zen Mode!", battler.pbThis))
        end
      end
    end

    # Eiscue form change on VOLCANIC / VOLCANICTOP entry
    if [:VOLCANIC, :VOLCANICTOP, :SUPERHEATED].include?(current_field.id)
      if battler.isSpecies?(:EISCUE) && battler.form == 0
        battler.pbChangeForm(1, _INTL("{1}'s Ice Face melted!", battler.pbThis))
      end
    end
  end
end

#===============================================================================
# HAUNTED — Specific move effect overrides
#===============================================================================

# Night Shade ×1.5 damage on Haunted field
class Battle::Move::FixedDamageUserLevel  # Night Shade function code
  alias_method :fe_haunted_nightshade_original, :pbFixedDamage if method_defined?(:pbFixedDamage)

  def pbFixedDamage(user, target)
    base = respond_to?(:fe_haunted_nightshade_original) ? fe_haunted_nightshade_original(user, target) : super
    return base unless @id == :NIGHTSHADE && @battle.FE == :HAUNTED
    (base * 1.5).round
  end
end

# Lick 100% paralysis on Haunted field
class Battle::Move::ParalyzeTarget  # Lick-style moves
  alias_method :fe_haunted_lick_original, :pbAdditionalEffectChance if method_defined?(:pbAdditionalEffectChance)

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    if @id == :LICK && @battle.FE == :HAUNTED
      return 100
    end
    respond_to?(:fe_haunted_lick_original) ? fe_haunted_lick_original(user, target, effectChance) : super
  end
end

#===============================================================================
# FROZENDIMENSION — Dragon Rage 140 flat / Power Trip +40bp per boost
#===============================================================================

class Battle::Move::FixedDamage120  # Dragon Rage
  alias_method :fe_frozendim_dr_original, :pbFixedDamage if method_defined?(:pbFixedDamage)

  def pbFixedDamage(user, target)
    return 140 if @id == :DRAGONRAGE && @battle.FE == :FROZENDIMENSION
    respond_to?(:fe_frozendim_dr_original) ? fe_frozendim_dr_original(user, target) : super
  end
end

class Battle::Move::MorePowerfulWithHigherUserPositiveStatStages  # Power Trip / Stored Power
  alias_method :fe_frozendim_pt_original, :pbBaseDamage if method_defined?(:pbBaseDamage)

  def pbBaseDamage(baseDmg, user, target)
    base = respond_to?(:fe_frozendim_pt_original) ? fe_frozendim_pt_original(baseDmg, user, target) : super
    return base unless @id == :POWERTRIP && @battle.FE == :FROZENDIMENSION
    # Normal Power Trip: 20 + 20 per positive stage. On Frozen Dim: 20 + 40 per stage.
    total_stages = [:ATTACK,:DEFENSE,:SPATK,:SPDEF,:SPEED,:ACCURACY,:EVASION].sum do |s|
      [user.stages[s], 0].max
    end
    20 + (40 * total_stages)
  end
end

#===============================================================================
# BIGTOP — Acrobatics always deals double power (no item check)
# BIGTOP — Dancer ability: Speed+1 / SpAtk+1 when ally uses a dance move
#===============================================================================
class Battle::Move::DoublePowerIfUserHasNoItem  # Acrobatics
  alias_method :fe_bigtop_acro_original, :pbBaseDamage if method_defined?(:pbBaseDamage)

  def pbBaseDamage(baseDmg, user, target)
    return baseDmg * 2 if @id == :ACROBATICS && @battle.FE == :BIGTOP
    respond_to?(:fe_bigtop_acro_original) ? fe_bigtop_acro_original(baseDmg, user, target) : super
  end
end

# Dancer: after any dance move is used on Big Top, raise Speed+1 and SpAtk+1 for Dancer users
class Battle::Battler
  alias_method :fe_bigtop_dancer_original, :pbEffectsOnMakingHit if method_defined?(:pbEffectsOnMakingHit)

  def pbEffectsOnMakingHit(move, user, target)
    respond_to?(:fe_bigtop_dancer_original) ? fe_bigtop_dancer_original(move, user, target) : super
    return unless @battle.FE == :BIGTOP
    dance_moves = %i[SWORDSDANCE CALMMIND DRAGONDANCE QUIVERDANCE FEATHERDANCE
                     PETALBLIZZARD REVELATIONDANCE CLANGEROUSSOUL LUNARDANCE]
    return unless dance_moves.include?(move.id)
    @battle.allBattlers.each do |b|
      next if b.fainted? || b.index == user.index
      next unless b.hasActiveAbility?(:DANCER)
      b.pbRaiseStatStageBasic(:SPEED, 1)  if b.pbCanRaiseStatStage?(:SPEED, b)
      b.pbRaiseStatStageBasic(:SPECIAL_ATTACK, 1)  if b.pbCanRaiseStatStage?(:SPECIAL_ATTACK, b)
      @battle.pbDisplay(_INTL("{1}'s Dancer joined the performance!", b.pbThis))
    end
  end
end

#===============================================================================
# MAGIC FIELD — Gravity/MagicRoom/TrickRoom last 8 turns instead of 5
#===============================================================================
class Battle::Move::StartGravity
  alias_method :fe_magic_grav_original, :pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    fe_magic_grav_original(user)
    @battle.field.effects[PBEffects::Gravity] = 8 if @battle.FE == :MAGIC && (@battle.field.effects[PBEffects::Gravity] || 0) > 0
  end
end if defined?(Battle::Move::StartGravity)

class Battle::Move::StartNegateHeldItems
  alias_method :fe_magic_mr_original, :pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    fe_magic_mr_original(user)
    @battle.field.effects[PBEffects::MagicRoom] = 8 if @battle.FE == :MAGIC && (@battle.field.effects[PBEffects::MagicRoom] || 0) > 0
  end
end if defined?(Battle::Move::StartNegateHeldItems)

class Battle::Move::StartSlowerBattlersActFirst
  alias_method :fe_magic_tr_original, :pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    fe_magic_tr_original(user)
    @battle.field.effects[PBEffects::TrickRoom] = 8 if @battle.FE == :MAGIC && (@battle.field.effects[PBEffects::TrickRoom] || 0) > 0
  end
end if defined?(Battle::Move::StartSlowerBattlersActFirst)

# MAGIC — Secret Power confuses the target
class Battle::Move::EffectDependsOnEnvironment
  alias_method :fe_magic_sp_original, :pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @id == :SECRETPOWER && @battle.FE == :MAGIC
      target.pbConfuse if target.pbCanConfuse?(user, false, self)
      return
    end
    respond_to?(:fe_magic_sp_original) ? fe_magic_sp_original(user, target) : super
  end
end if defined?(Battle::Move::EffectDependsOnEnvironment)

#===============================================================================
# INFERNAL — Stealth Rock deals Fire-type damage
# COLOSSEUM — Defiant: Def+2 also fires when any stat is lowered
#===============================================================================

# Infernal Stealth Rock — Fire-type damage via pbEntryHazards hook
module Battle::FE_InfernalStealthRockHook
  def pbEntryHazards(battler)
    if respond_to?(:FE) && FE == :INFERNAL
      battler_side = battler.pbOwnSide
      if battler_side.effects[PBEffects::StealthRock] && battler.takesIndirectDamage? &&
         !battler.hasActiveItem?(:HEAVYDUTYBOOTS)
        eff = Effectiveness.calculate(:FIRE, *battler.pbTypes(true))
        unless Effectiveness.ineffective?(eff)
          dmg = [(battler.totalhp * eff / 8), 1].max
          battler.pbReduceHP(dmg, false)
          pbDisplay(_INTL("Pointed stones dug into {1} with infernal heat!", battler.pbThis))
          battler.pbItemHPHealCheck
          battler_side.effects[PBEffects::StealthRock] = false
          super
          battler_side.effects[PBEffects::StealthRock] = true
          return
        end
      end
    end
    super
  end
end
Battle.prepend(Battle::FE_InfernalStealthRockHook)

# Colosseum — Defiant triggers Def+2 when any stat is lowered (not just Atk)
class Battle::Battler
  alias_method :fe_col_defiant_original_pbLowerStatStage, :pbLowerStatStage if method_defined?(:pbLowerStatStage)

  def pbLowerStatStage(stat, stages, user, *args)
    result = respond_to?(:fe_col_defiant_original_pbLowerStatStage) ?
             fe_col_defiant_original_pbLowerStatStage(stat, stages, user, *args) : super
    if @battle.FE == :COLOSSEUM && result && hasActiveAbility?(:DEFIANT)
      if pbCanRaiseStatStage?(:DEFENSE, self)
        pbRaiseStatStageBasic(:DEFENSE, 2)
        @battle.pbDisplay(_INTL("{1}'s Defiant raised its Defense!", pbThis))
      end
    end
    result
  end
end

#===============================================================================
# DARKCRYSTALCAVERN — Synthesis/Morning Sun heal 25%, Moonlight heals 75%
# BEWITCHED — Moonlight heals 75%
#===============================================================================
class Battle::Move::HealUserDependingOnWeather
  alias_method :fe_heal_weather_original, :pbHealAmount if method_defined?(:pbHealAmount)

  def pbHealAmount(user)
    case @battle.FE
    when :DARKCRYSTALCAVERN
      if @id == :MOONLIGHT
        return (user.totalhp * 3 / 4.0).round
      elsif [:SYNTHESIS, :MORNINGSUN].include?(@id)
        return (user.totalhp / 4.0).round
      end
    when :BEWITCHED
      return (user.totalhp * 3 / 4.0).round if @id == :MOONLIGHT
    end
    respond_to?(:fe_heal_weather_original) ? fe_heal_weather_original(user) : super
  end
end if defined?(Battle::Move::HealUserDependingOnWeather)

#===============================================================================
# BEWITCHED — Effect Spore doubled rate
#===============================================================================
class Battle::Battler
  alias_method :fe_bewitch_spore_original, :pbAbilitiesOnDamageTaken if method_defined?(:pbAbilitiesOnDamageTaken)

  def pbAbilitiesOnDamageTaken(*args)
    # Temporarily double Effect Spore chance on Bewitched
    @fe_effect_spore_boosted = (@battle.FE == :BEWITCHED)
    result = respond_to?(:fe_bewitch_spore_original) ? fe_bewitch_spore_original(*args) : super
    @fe_effect_spore_boosted = false
    result
  end
end

# Note: Full Effect Spore doubling requires patching the Effect Spore handler
# which checks rand(100) < 30. We flag it above; a full patch would need:
# Battle::AbilityEffects::OnBeingHit override for :EFFECTSPORE
