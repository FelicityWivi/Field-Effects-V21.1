class Battle::Field_base < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION)
    super
    @id   = :base
    @name = _INTL("Base")
  end
end

Battle::Field.register(:base, {
  :trainer_name => [], # which trainer will have this field as default field
  :environment  => [], # backdrop(or environment, check backdrop first)
  :map_id       => [], # map
  :edge_type    => [], # what advantageous types are in this field
})

# these are some field function keys, it is better to add the new lines to the original method, tbh i do not like overwriting/aliasing = =
# search "apply_field_effect"
# check example field learn how to use them

# :ability_activation

# :accuracy_modify
class Battle::Move
  alias field_pbCalcAccuracyModifiers pbCalcAccuracyModifiers
  def pbCalcAccuracyModifiers(user, target, modifiers)
    @battle.apply_field_effect(:accuracy_modify, user, target, self, modifiers, @calcType)
    field_pbCalcAccuracyModifiers(user, target, modifiers)
  end
end

# :base_type_change
class Battle::Move
  def pbBaseType(user)
    ret = @type
    if ret && user.abilityActive?
      ret = Battle::AbilityEffects.triggerModifyMoveBaseType(user.ability, user, self, ret)
    end

    ret_type = @battle.apply_field_effect(:base_type_change, user, self, ret)
    ret = ret_type if ret_type

    return ret
  end
end

# :begin_battle

# :block_berry
class Battle::Battler
  def canConsumeBerry?

    ret = @battle.apply_field_effect(:block_berry, self)
    return false if ret

    return false if @battle.pbCheckOpposingAbility([:UNNERVE, :ASONECHILLINGNEIGH, :ASONEGRIMNEIGH], @index)
    return true
  end
end

# :block_heal
class Battle::Battler
  def canHeal?
    return false if fainted? || @hp >= @totalhp

    ret = @battle.apply_field_effect(:block_heal, self)
    return false if ret

    return false if @effects[PBEffects::HealBlock] > 0
    return true
  end
end

# :block_move
class Battle::Battler
  alias field_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    show_message = move.pbShowFailMessages?(targets)
    typeMod = move.pbCalcTypeMod(move.calcType, user, target)
    target.damageState.typeMod = typeMod
    # Two-turn attacks can't fail here in the charging turn
    return true if user.effects[PBEffects::TwoTurnAttack]

    priority =  @battle.choices[user.index][4] || move.priority
    ret = @battle.apply_field_effect(:block_move, move, user, target, targets, typeMod, show_message, priority)
    return false if ret

    return field_pbSuccessCheckAgainstTarget(move, user, target, targets)
  end
end

# :block_weather

# :calc_damage
class Battle::Move
  alias field_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    @battle.apply_field_effect(:calc_damage, user, target, numTargets, self, type, baseDmg, multipliers)

    multipliers[:final_damage_multiplier] *= 0.5 if target.effects[PBEffects::Shelter] && target.effects[PBEffects::Shelter] == type

    field_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
  end
end

# :calc_speed
class Battle::Battler
  def pbSpeed
    return 1 if fainted?
    stage = @stages[:SPEED] + STAT_STAGE_MAXIMUM
    speed = @speed * STAT_STAGE_MULTIPLIERS[stage] / STAT_STAGE_DIVISORS[stage]
    speedMult = 1.0

    ret = @battle.apply_field_effect(:calc_speed, self, speed, speedMult)
    speedMult = ret if ret

    # Ability effects that alter calculated Speed
    if abilityActive?
      speedMult = Battle::AbilityEffects.triggerSpeedCalc(self.ability, self, speedMult)
    end
    # Item effects that alter calculated Speed
    if itemActive?
      speedMult = Battle::ItemEffects.triggerSpeedCalc(self.item, self, speedMult)
    end
    # Other effects
    speedMult *= 2 if pbOwnSide.effects[PBEffects::Tailwind] > 0
    speedMult /= 2 if pbOwnSide.effects[PBEffects::Swamp] > 0
    # Paralysis
    if status == :PARALYSIS && !hasActiveAbility?(:QUICKFEET)
      speedMult /= (Settings::MECHANICS_GENERATION >= 7) ? 2 : 4
    end
    # Badge multiplier
    if @battle.internalBattle && pbOwnedByPlayer? &&
       @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPEED
      speedMult *= 1.1
    end
    # Calculation
    return [(speed * speedMult).round, 1].max
  end
end

# :camouflage_type

# :change_effectiveness

# :end_field_battle

# :end_field_battler

# :end_of_move_universal

# :end_of_move

# :EOR_field_battle

# :EOR_field_battler

# :expand_target
class Battle::Move
  def pbTarget(_user)
    ret = @battle.apply_field_effect(:expand_target, _user, self, @target)
    return GameData::Target.get(ret) if ret

    return GameData::Target.get(@target)
  end
end

# :floral_heal_amount
class Battle::Move::HealTargetDependingOnGrassyTerrain
  def pbEffectAgainstTarget(user, target)
    hpGain = (target.totalhp / 2.0).round
    hpGain = (target.totalhp * 2 / 3.0).round if @battle.field.terrain == :Grassy

    ret = @battle.apply_field_effect(:floral_heal_amount, user, target, self)
    hpGain = (target.totalhp * ret).round if ret 

    target.pbRecoverHP(hpGain)
    @battle.pbDisplay(_INTL("{1}'s HP was restored.", target.pbThis))
  end
end

# :mimicry_type

# :move_priority
class Battle::Move
  def pbPriority(user)
    ret = @battle.apply_field_effect(:move_priority, user, self, @priority)
    pri = ret || @priority
    return pri
  end
end

# :move_second_type
class Battle::Move
  alias field_pbCalcTypeModSingle pbCalcTypeModSingle
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = field_pbCalcTypeModSingle(moveType, defType, user, target)

    ret_type = @battle.apply_field_effect(:move_second_type, ret, self, moveType, defType, user, target)
    if ret_type && GameData::Type.exists?(ret_type)
      ret *= Effectiveness.calculate(ret_type, defType)
    end

    ret_effectiveness = @battle.apply_field_effect(:change_effectiveness, ret, self, moveType, defType, user, target)
    ret = ret_effectiveness if ret_effectiveness

    return ret
  end
end

# :nature_power_change
class Battle::Move::UseMoveDependingOnEnvironment
  def pbOnStartUse(user, targets)
    # NOTE: It's possible in theory to not have the move Nature Power wants to
    #       turn into, but what self-respecting game wouldn't at least have Tri
    #       Attack in it?
    @npMove = :TRIATTACK

    ret = @battle.apply_field_effect(:nature_power_change, user, targets, self)
    if ret && GameData::Move.exists?(ret)
      @npMove = ret
      return
    end

    case @battle.field.terrain
    when :Electric
      @npMove = :THUNDERBOLT if GameData::Move.exists?(:THUNDERBOLT)
    when :Grassy
      @npMove = :ENERGYBALL if GameData::Move.exists?(:ENERGYBALL)
    when :Misty
      @npMove = :MOONBLAST if GameData::Move.exists?(:MOONBLAST)
    when :Psychic
      @npMove = :PSYCHIC if GameData::Move.exists?(:PSYCHIC)
    else
      try_move = nil
      case @battle.environment
      when :Grass, :TallGrass, :Forest, :ForestGrass
        try_move = (Settings::MECHANICS_GENERATION >= 6) ? :ENERGYBALL : :SEEDBOMB
      when :MovingWater, :StillWater, :Underwater
        try_move = :HYDROPUMP
      when :Puddle
        try_move = :MUDBOMB
      when :Cave
        try_move = (Settings::MECHANICS_GENERATION >= 6) ? :POWERGEM : :ROCKSLIDE
      when :Rock, :Sand
        try_move = (Settings::MECHANICS_GENERATION >= 6) ? :EARTHPOWER : :EARTHQUAKE
      when :Snow
        try_move = :BLIZZARD
        try_move = :FROSTBREATH if Settings::MECHANICS_GENERATION == 6
        try_move = :ICEBEAM if Settings::MECHANICS_GENERATION >= 7
      when :Ice
        try_move = :ICEBEAM
      when :Volcano
        try_move = :LAVAPLUME
      when :Graveyard
        try_move = :SHADOWBALL
      when :Sky
        try_move = :AIRSLASH
      when :Space
        try_move = :DRACOMETEOR
      when :UltraSpace
        try_move = :PSYSHOCK
      end
      @npMove = try_move if GameData::Move.exists?(try_move)
    end
  end
end

# :no_charging
class Battle::Move::TwoTurnMove
  def pbIsChargingTurn?(user)
    @powerHerb = false
    @chargingTurn = false   # Assume damaging turn by default
    @damagingTurn = true
    # nil at start of charging turn, move's ID at start of damaging turn
    if !user.effects[PBEffects::TwoTurnAttack]

      if skipChargingTurn?(user)
        skipChargingTurn
      else
        @powerHerb = user.hasActiveItem?(:POWERHERB)
        @chargingTurn = true
        @damagingTurn = @powerHerb
      end

    end
    return !@damagingTurn   # Deliberately not "return @chargingTurn"
  end

  def skipChargingTurn?(user)
    ret = @battle.apply_field_effect(:no_charging, user, self)
    return true if ret
    return false
  end

  def skipChargingTurn
    @powerHerb = false
    @chargingTurn = true
    @damagingTurn = true
  end
end

# :no_recharging
class Battle::Battler
  alias field_pbEffectsAfterMove pbEffectsAfterMove
  def pbEffectsAfterMove(user, targets, move, numHits)
    ret = @battle.apply_field_effect(:no_recharging, user, targets, move, numHits)
    user.effects[PBEffects::HyperBeam] = 0 if ret

    @battle.apply_field_effect(:end_of_move_universal, user, targets, move, numHits)
    @battle.apply_field_effect(:end_of_move, user, targets, move, numHits)
    field_pbEffectsAfterMove(user, targets, move, numHits)
  end
end

# :secret_power_effect
class Battle::Move::EffectDependsOnEnvironment
  def pbOnStartUse(user, targets)
    # NOTE: This is Gen 7's list plus some of Gen 6 plus a bit of my own.
    @secretPower = 0   # Body Slam, paralysis

    ret = @battle.apply_field_effect(:secret_power_effect, user, targets, self)
    if ret
      @secretPower = ret
      return
    end

    case @battle.field.terrain
    when :Electric
      @secretPower = 1   # Thunder Shock, paralysis
    when :Grassy
      @secretPower = 2   # Vine Whip, sleep
    when :Misty
      @secretPower = 3   # Fairy Wind, lower Sp. Atk by 1
    when :Psychic
      @secretPower = 4   # Confusion, lower Speed by 1
    else
      case @battle.environment
      when :Grass, :TallGrass, :Forest, :ForestGrass
        @secretPower = 2    # (Same as Grassy Terrain)
      when :MovingWater, :StillWater, :Underwater
        @secretPower = 5    # Water Pulse, lower Attack by 1
      when :Puddle
        @secretPower = 6    # Mud Shot, lower Speed by 1
      when :Cave
        @secretPower = 7    # Rock Throw, flinch
      when :Rock, :Sand
        @secretPower = 8    # Mud-Slap, lower Acc by 1
      when :Snow, :Ice
        @secretPower = 9    # Ice Shard, freeze
      when :Volcano
        @secretPower = 10   # Incinerate, burn
      when :Graveyard
        @secretPower = 11   # Shadow Sneak, flinch
      when :Sky
        @secretPower = 12   # Gust, lower Speed by 1
      when :Space
        @secretPower = 13   # Swift, flinch
      when :UltraSpace
        @secretPower = 14   # Psywave, lower Defense by 1
      when :Poisonlibrary
        @secretPower = 15   # Poison damage
      end
    end
  end
end

# :set_field_battle

# :set_field_battler

# :set_field_battler_universal # this is for sepcial usage, dont touch it

# :shelter_type

# :status_immunity
class Battle::Battler
  alias field_pbCanInflictStatus? pbCanInflictStatus?
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    return false if fainted?
    self_inflicted = (user && user.index == @index)   # Rest and Flame Orb/Toxic Orb only

    ret = @battle.apply_field_effect(:status_immunity, self, newStatus, false, user, showMessages, self_inflicted, move, ignoreStatus)
    return false if ret

    return field_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end

  alias field_pbCanSynchronizeStatus? pbCanSynchronizeStatus?
  def pbCanSynchronizeStatus?(newStatus, user)
    return false if fainted?
    # Trying to replace a status problem with another one
    return false if self.status != :NONE

    ret = @battle.apply_field_effect(:status_immunity, self, newStatus, false, user)
    return false if ret

    return field_pbCanSynchronizeStatus?(newStatus, user)
  end

  alias field_pbCanSleepYawn? pbCanSleepYawn?
  def pbCanSleepYawn?
    return false if self.status != :NONE

    ret = @battle.apply_field_effect(:status_immunity, self, :SLEEP, true)
    return false if ret

    return field_pbCanSleepYawn?
  end

  alias field_pbCanConfuse? pbCanConfuse?
  def pbCanConfuse?(user = nil, showMessages = true, move = nil, selfInflicted = false)
    return false if fainted?

    ret = @battle.apply_field_effect(:status_immunity, self, :CONFUSION, false, user, showMessages, selfInflicted, move)
    return false if ret

    return field_pbCanConfuse?(user, showMessages, move, selfInflicted)
  end
end

# :switch_in
class Battle
  def pbOnBattlerEnteringBattle(battler_index, skip_event_reset = false)
    battler_index = [battler_index] if !battler_index.is_a?(Array)
    battler_index.flatten!
    # NOTE: This isn't done for switch commands, because they previously call
    #       pbRecallAndReplace, which could cause Neutralizing Gas to end, which
    #       in turn could cause Intimidate to trigger another Pokémon's Eject
    #       Pack. That Eject Pack should trigger at the end of this method, but
    #       this resetting would prevent that from happening, so it is skipped
    #       and instead done earlier in def pbAttackPhaseSwitch.
    if !skip_event_reset
      allBattlers.each do |b|
        b.droppedBelowHalfHP = false
        b.statsDropped = false
      end
    end
    # For each battler that entered battle, in speed order
    pbPriority(true).each do |b|
      next if !battler_index.include?(b.index) || b.fainted?
      pbRecordBattlerAsParticipated(b)
      pbMessagesOnBattlerEnteringBattle(b)

      apply_field_effect(:switch_in, b)

      # Position/field effects triggered by the battler appearing
      pbEffectsOnBattlerEnteringPosition(b)   # Healing Wish/Lunar Dance
      pbEntryHazards(b)
      # Battler faints if it is knocked out because of an entry hazard above
      if b.fainted?
        b.pbFaint
        pbGainExp
        pbJudge
        next
      end
      b.pbCheckForm
      # Primal Revert upon entering battle
      pbPrimalReversion(b.index)
      # Ending primordial weather, checking Trace
      b.pbContinualAbilityChecks(true)
      # Abilities that trigger upon switching in
      if (!b.fainted? && b.unstoppableAbility?) || b.abilityActive?
        Battle::AbilityEffects.triggerOnSwitchIn(b.ability, b, self, true)
      end
      pbEndPrimordialWeather   # Checking this again just in case
      # Items that trigger upon switching in (Air Balloon message)
      if b.itemActive?
        Battle::ItemEffects.triggerOnSwitchIn(b.item, b, self)
      end
      # Berry check, status-curing ability check
      b.pbHeldItemTriggerCheck
      b.pbAbilityStatusCureCheck
    end
    # Check for triggering of Emergency Exit/Wimp Out/Eject Pack (only one will
    # be triggered)
    pbPriority(true).each do |b|
      break if b.pbItemOnStatDropped
      break if b.pbAbilitiesOnDamageTaken
    end
    allBattlers.each do |b|
      b.droppedBelowHalfHP = false
      b.statsDropped = false
    end
  end
end

# :tailwind_duration
class Battle::Move::StartUserSideDoubleSpeed
  def pbEffectGeneral(user)
    user.pbOwnSide.effects[PBEffects::Tailwind] = 4

    ret = @battle.apply_field_effect(:tailwind_duration, user, self)
    user.pbOwnSide.effects[PBEffects::Tailwind] += ret if ret

    @battle.pbDisplay(_INTL("The Tailwind blew from behind {1}!", user.pbTeam(true)))
  end
end

# :terrain_pulse_type