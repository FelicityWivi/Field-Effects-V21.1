#===============================================================================
# Field Effects Plugin — Passive & EOR Effects (Part 2)
# File: FE_011_PassiveEffects.rb
#
# Implements passive mechanics not covered by FE_005 – FE_010:
#
#  1.  Passive type-based Defense boosts (damage calc)
#  2.  Shadow Shield always-on for DIMENSIONAL / NEWWORLD / STARLIGHTARENA
#  3.  Grounded Speed reductions (WATERSURFACE, UNDERWATER)
#  4.  Underwater physical non-Water ×0.5
#  5.  Plus/Minus SpAtk ×1.5 (ELECTERRAIN / SHORTCIRCUIT)
#  6.  Drain moves 75% recovery on GRASSY
#  7.  SWAMP EOR: Speed −1 all grounded + sleeping 1/16 HP
#  8.  RAINBOW EOR: sleeping heal 1/16 HP
#  9.  CORROSIVEMIST EOR: all non-Poison/Steel poisoned each round
# 10.  CORROSIVE EOR: sleeping non-Poison/Steel + Ingrain damage
# 11.  Field change/destroy ×1.3 power bonus (general rule)
#===============================================================================

#===============================================================================
# 1 + 2.  PASSIVE TYPE DEFENSE BOOSTS & SHADOW SHIELD ALWAYS-ON
#===============================================================================
class Battle::Move
  alias_method :fe011_dmg_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe011_dmg_original(user, target, numTargets, type, baseDmg, multipliers)

    case @battle.FE

    when :DARKCRYSTALCAVERN
      if target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
        multipliers[:defense_multiplier] *= 1.5
      end

    when :MISTY
      if target.pbHasType?(:FAIRY)
        multipliers[:defense_multiplier] *= 1.5
      end

    when :DESERT
      if target.pbHasType?(:GROUND)
        multipliers[:sp_def_multiplier] = (multipliers[:sp_def_multiplier] || 1.0) * 1.5
      end

    when :DRAGONSDEN
      if target.pbHasType?(:DRAGON)
        multipliers[:sp_def_multiplier] = (multipliers[:sp_def_multiplier] || 1.0) * 1.3
      end

    when :DIMENSIONAL
      if target.pbHasType?(:GHOST)
        multipliers[:defense_multiplier] *= 1.5
      end
      if target.hasActiveAbility?(:SHADOWSHIELD)
        multipliers[:final_damage_multiplier] = (multipliers[:final_damage_multiplier] || 1.0) * 0.75
      end

    when :FROZENDIMENSION
      if target.pbHasType?(:ICE) || target.pbHasType?(:GHOST)
        multipliers[:defense_multiplier] *= 1.2
      end
      if target.pbHasType?(:FIRE)
        multipliers[:defense_multiplier] *= 0.8
      end

    when :NEWWORLD, :STARLIGHTARENA
      if target.hasActiveAbility?(:SHADOWSHIELD)
        multipliers[:final_damage_multiplier] = (multipliers[:final_damage_multiplier] || 1.0) * 0.75
      end

    when :UNDERWATER
      # Physical non-Water moves from non-Water users ×0.5
      if physicalMove? && !user.pbHasType?(:WATER) && type != :WATER
        multipliers[:power_multiplier] *= 0.5
      end

    when :ELECTERRAIN, :SHORTCIRCUIT
      # Plus/Minus: SpAtk ×1.5 when user has Plus or Minus and ally has the other
      if specialMove?
        has_plus  = user.hasActiveAbility?(:PLUS)
        has_minus = user.hasActiveAbility?(:MINUS)
        if has_plus || has_minus
          ally_completes = @battle.allBattlers.any? { |b|
            next false if b.index == user.index || b.fainted?
            b.hasActiveAbility?(:PLUS) || b.hasActiveAbility?(:MINUS)
          }
          multipliers[:attack_multiplier] *= 1.5 if ally_completes
        end
      end
    end
  end
end

#===============================================================================
# 3.  GROUNDED SPEED REDUCTIONS
#===============================================================================
class Battle::Battler
  alias_method :fe011_speed_original, :pbSpeed

  def pbSpeed
    spd = fe011_speed_original

    case @battle.FE
    when :WATERSURFACE
      unless pbHasType?(:WATER) || hasActiveAbility?(:SWIFTSWIM) ||
             hasActiveAbility?(:SURGESURFER) || airborne?
        spd = (spd * 3 / 4.0).floor
      end
    when :UNDERWATER
      unless pbHasType?(:WATER) || hasActiveAbility?(:SWIFTSWIM) ||
             hasActiveAbility?(:STEELWORKER)
        spd = (spd / 2.0).floor
      end
    end

    [spd, 1].max
  end
end

#===============================================================================
# 4.  DRAIN MOVES 75% RECOVERY ON GRASSY
# pbRecoverHPFromDrain receives (user, target, hp_drained) and returns heal amt.
# Big Root is already handled in FE_006 (multiplies by 1.6 on GRASSY).
#===============================================================================
class Battle::Move
  alias_method :fe011_drain_original, :pbRecoverHPFromDrain if method_defined?(:pbRecoverHPFromDrain)

  def pbRecoverHPFromDrain(user, target, damageDealt)
    # Base drain: 50% of damage dealt
    base = if respond_to?(:fe011_drain_original)
             fe011_drain_original(user, target, damageDealt)
           else
             (damageDealt / 2.0).round
           end
    # GRASSY: boost to 75% before Big Root applies (Big Root handled in FE_006)
    if @battle.FE == :GRASSY && !user.hasActiveItem?(:BIGROOT)
      base = [(damageDealt * 3 / 4.0).round, base].max
    end
    base
  end
end

#===============================================================================
# 5.  SWAMP EOR — Speed −1 all grounded each round
#===============================================================================
module Battle::FE_SwampSpeedHook
  def end_of_round_field_process
    super
    return unless respond_to?(:FE) && self.FE == :SWAMP
    pbPriority(true).each do |b|
      next if b.fainted? || b.airborne?
      immune = [:CLEARBODY, :QUICKFEET, :SWIFTSWIM, :WHITESMOKE,
                :PROPELLERTAIL, :STEAMENGINE]
      next if immune.any? { |ab| b.hasActiveAbility?(ab) }
      next unless b.pbCanLowerStatStage?(:SPEED, b)
      b.pbLowerStatStageBasic(:SPEED, 1)
      pbDisplay(_INTL("{1} is slowed by the swamp!", b.pbThis))
    end
  end
end
Battle.prepend(Battle::FE_SwampSpeedHook)

#===============================================================================
# 6 + 7 + 8.  EOR PASSIVE: SWAMP sleep damage / RAINBOW sleep heal /
#              CORROSIVEMIST poison all / CORROSIVE sleep+Ingrain damage
# Extend FieldEffect::EOR.process_battler (defined in FE_007) with new cases.
#===============================================================================
module FieldEffect
  module EOR
    class << self
      alias_method :fe011_battler_original, :process_battler

      def process_battler(battler, battle, field_id)
        fe011_battler_original(battler, battle, field_id)
        return if battler.fainted?

        case field_id

        when :SWAMP
          if battler.asleep? && battler.takesIndirectDamage? &&
             !battler.hasActiveAbility?(:MAGICGUARD)
            dmg = [(battler.totalhp / 16.0).ceil, 1].max
            battler.pbReduceHP(dmg, false)
            battle.pbDisplay(_INTL("{1} suffered in its swampy sleep!", battler.pbThis))
            battler.pbFaint if battler.fainted?
          end

        when :RAINBOW
          if battler.asleep? && battler.canHeal?
            heal = [(battler.totalhp / 16.0).ceil, 1].max
            battler.pbRecoverHP(heal)
            battle.pbDisplay(_INTL("{1} rested peacefully in the rainbow's glow!", battler.pbThis))
          end

        when :CORROSIVEMIST
          # All non-Poison/Steel Pokemon are poisoned if not already
          return if battler.pbHasType?(:POISON) || battler.pbHasType?(:STEEL)
          return if battler.status != :NONE
          return if battler.hasActiveAbility?(:MAGICGUARD) || battler.hasActiveAbility?(:IMMUNITY)
          return if battler.hasActiveAbility?(:PASTELVEIL)
          # Neutralizing Gas blocks field effects
          return if battle.allBattlers.any? { |b|
            !b.fainted? && b.hasActiveAbility?(:NEUTRALIZINGGAS)
          }
          battler.pbPoison(nil) if battler.pbCanPoison?(nil, false)

        when :CORROSIVE
          # Sleeping non-Poison/Steel: 1/16 HP damage
          if battler.asleep? && !battler.pbHasType?(:POISON) && !battler.pbHasType?(:STEEL)
            return if battler.hasActiveAbility?(:MAGICGUARD) || battler.hasActiveAbility?(:WONDERGUARD)
            return if battler.hasActiveAbility?(:IMMUNITY)
            dmg = [(battler.totalhp / 16.0).ceil, 1].max
            battler.pbReduceHP(dmg, false)
            battle.pbDisplay(_INTL("Poison seeped into {1}'s sleep!", battler.pbThis))
            battler.pbFaint if battler.fainted?
          end
          # Ingrain / Grass Pelt damage on Corrosive
          has_ingrain    = battler.effects[PBEffects::Ingrain] rescue false
          has_grass_pelt = battler.hasActiveAbility?(:GRASSPELT)
          if (has_ingrain || has_grass_pelt) && battler.takesIndirectDamage?
            dmg = [(battler.totalhp / 16.0).ceil, 1].max
            battler.pbReduceHP(dmg, false)
            battle.pbDisplay(_INTL("The corrosive field damaged {1}!", battler.pbThis))
            battler.pbFaint if battler.fainted?
          end
        end
      end
    end
  end
end

#===============================================================================
# 9.  FIELD TRANSFORM ×1.3 POWER BONUS (General rule)
# The move that triggers a field change gets ×1.3 damage that turn.
# Implemented as a one-shot flag set by FE_002_Bridge's create_new_field hook.
# We read it here in damage calc and clear it immediately after.
#===============================================================================
class Battle
  # Flag is set true by FE_002's create_new_field hook before this calc runs.
  attr_accessor :fe_transform_bonus_active

  def fe_transform_bonus_active
    @fe_transform_bonus_active ||= false
  end
end

class Battle::Move
  alias_method :fe011_transform_bonus_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe011_transform_bonus_original(user, target, numTargets, type, baseDmg, multipliers)
    if @battle.fe_transform_bonus_active
      multipliers[:power_multiplier] *= 1.3
      @battle.fe_transform_bonus_active = false
    end
  end
end
