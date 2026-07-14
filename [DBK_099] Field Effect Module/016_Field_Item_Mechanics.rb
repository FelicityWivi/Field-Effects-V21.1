#===============================================================================
# Comprehensive Field Mechanics System - ITEMS
# Item-related field mechanics: Battle::ItemEffects hooks and item-driven
# move effects (steal/swap/remove/restore item, no-item power boosts).
# Requires: 000_Field_Mechanics_Shared.rb to be loaded first.
#===============================================================================


# Trick/Switcheroo - Stat swap effects
class Battle::Move::UserTargetSwapItems
  alias backalley_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits) && !method_defined?(:backalley_pbEffectAfterAllHits)
  
  def pbEffectAfterAllHits(user, target)
    ret = respond_to?(:backalley_pbEffectAfterAllHits) ? backalley_pbEffectAfterAllHits(user, target) : super
    
    if @battle.has_field? && BACK_ALLEY_IDS.include?(@battle.current_field.id)
      if @id == :TRICK
        # Raise user Sp.Atk, lower target Sp.Atk
        user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user)
        target.pbLowerStatStage(:SPECIAL_ATTACK, 1, user)
      elsif @id == :SWITCHEROO
        # Raise user Attack, lower target Attack
        user.pbRaiseStatStage(:ATTACK, 1, user)
        target.pbLowerStatStage(:ATTACK, 1, user)
      end
    end
    
    return ret
  end
end

# Thief/Covet - 2x power when successfully stealing
class Battle::Move::RemoveTargetItem
  alias backalley_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage) && !method_defined?(:backalley_pbBaseDamage)
  
  def pbBaseDamage(baseDmg, user, target)
    dmg = respond_to?(:backalley_pbBaseDamage) ? backalley_pbBaseDamage(baseDmg, user, target) : super
    
    # On Back Alley, 2x power if can steal item
    if [:THIEF, :COVET].include?(@id) &&
       @battle.has_field? &&
       BACK_ALLEY_IDS.include?(@battle.current_field.id) &&
       !user.item && target.item
      dmg *= 2
    end
    
    return dmg
  end
end

# Acrobatics always deals double damage
class Battle::Move::DoublePowerIfUserHasNoItem
  alias bigtop_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage) && !method_defined?(:bigtop_pbBaseDamage)
  
  def pbBaseDamage(baseDmg, user, target)
    ret = respond_to?(:bigtop_pbBaseDamage) ? bigtop_pbBaseDamage(baseDmg, user, target) : super
    
    if user.battle.has_field? && BIG_TOP_IDS.include?(user.battle.current_field.id)
      return ret * 2  # Always double on Big Top
    end
    
    return ret
  end
end

# Black Sludge - Doubled effect
Battle::ItemEffects::EndOfRoundHealing.add(:BLACKSLUDGE,
  proc { |item, battler, battle|
    next if battler.hp == battler.totalhp && !battler.pbHasType?(:POISON)
    
    # Base healing/damage
    amt = battler.totalhp / 16
    
    # Double on Corrupted Cave
    if battle.has_field? && CORRUPTED_CAVE_IDS.include?(battle.current_field.id)
      amt *= 2
    end
    
    if battler.pbHasType?(:POISON)
      battler.pbFieldRecoverHP(amt)
      battle.pbDisplay(_INTL("{1} restored a little HP using its {2}!", battler.pbThis, battler.itemName))
    else
      battler.pbReduceHP(amt, false)
      battle.pbDisplay(_INTL("{1} was hurt by its {2}!", battler.pbThis, battler.itemName))
    end
  }
)

# Recycle - Raises random stat
class Battle::Move::RestoreUserConsumedItem
  def pbEffectGeneral(user)
    ret = super
    # On City Field, raise random stat
    if ret == 0 && @battle.has_field? && CITY_FIELD_IDS.include?(@battle.current_field.id)
      random_stat = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].sample
      user.pbRaiseStatStage(random_stat, 1, user)
    end
    return ret
  end
end

# Corrosive Gas - Lowers all stats by 1 stage when successful
class Battle::Move::RemoveTargetItem
  alias city_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget) && !method_defined?(:city_pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    ret = respond_to?(:city_pbEffectAgainstTarget) ? city_pbEffectAgainstTarget(user, target) : super
    
    # On City Field, lower all stats if successful
    if ret == 0 && 
       @id == :CORROSIVEGAS &&
       @battle.has_field? && 
       CITY_FIELD_IDS.include?(@battle.current_field.id)
      target.pbLowerStatStage(:ATTACK, 1, user)
      target.pbLowerStatStage(:DEFENSE, 1, user)
      target.pbLowerStatStage(:SPECIAL_ATTACK, 1, user)
      target.pbLowerStatStage(:SPECIAL_DEFENSE, 1, user)
      target.pbLowerStatStage(:SPEED, 1, user)
    end
    
    return ret
  end
end

#──────────────────────────────────────────────────────────────────────────────
# 2. TOPSY TURVY → Creates Inverse Field for 3 turns (unless user holds Everstone)
# Stores the prior field so we can revert after the duration expires.
#──────────────────────────────────────────────────────────────────────────────

class Battle::Move::InvertTargetStatStages
  alias inverse_topsyturvy_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget) && !method_defined?(:inverse_topsyturvy_pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:inverse_topsyturvy_pbEffectAgainstTarget) ? inverse_topsyturvy_pbEffectAgainstTarget(user, target) : super
    # Don't create the field if the user holds an Everstone
    return if user.item == :EVERSTONE

    # Don't stack — if Inverse Field is already active, do nothing extra
    return if @battle.has_field? && INVERSE_FIELD_IDS.include?(@battle.current_field.id)

    # Store the prior field before overwriting
    @battle.inverse_prior_field = @battle.has_field? ? @battle.current_field.id : nil
    @battle.inverse_field_turns = 3

    @battle.pbChangeBattleField(:INVERSE)
    @battle.pbDisplay(_INTL("Everything became inverted!"))
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: EOR — all grounded Pokémon lose 1 Speed stage
# Immunity: Clear Body, Quick Feet, Swift Swim, White Smoke, Propeller Tail,
#           Steam Engine, and holding Heavy-Duty Boots
# Trapping: Pokémon under Trapping effect lose -2 Speed instead of -1
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias swamp_speed_drop_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:swamp_speed_drop_pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    respond_to?(:swamp_speed_drop_pbEndOfRoundPhase) ? swamp_speed_drop_pbEndOfRoundPhase : super
    return unless has_field? && SWAMP_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.grounded?
      next if battler.hasActiveAbility?(SWAMP_SPEED_IMMUNE_ABILITIES)
      next if battler.hasActiveItem?(:HEAVYDUTYBOOTS) rescue false

      stages = (battler.effects[PBEffects::Trapping] > 0) ? 2 : 1
      next unless battler.pbCanLowerStatStage?(:SPEED, battler, nil)
      battler.pbLowerStatStage(:SPEED, stages, battler, false)
    end
  end
end