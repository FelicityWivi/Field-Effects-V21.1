#===============================================================================
# Field Effects Plugin — Ability Effects
# File: FE_005_AbilityEffects.rb
#
#   1. Type-changing ability damage boosts on specific fields
#      Galvanize / Battery / Teravolt ×1.5 on ELECTERRAIN
#      Pixilate ×1.5 on MISTY
#      Refrigerate ×1.5 on ICY, SNOWYMOUNTAIN
#      Aerilate ×1.5 on MOUNTAIN, SNOWYMOUNTAIN
#
#   2. Magic Field — Telepathy doubles Speed, Pure/Huge Power boost SpAtk
#      (separate pbSpeed alias that chains after their 016 alias)
#
#   3. Colosseum — Beast Boost on KO, no switching, Roar override
#
#   4. Haunted Field — Wandering Spirit EOR Speed drain
#
# NOTE: Their 016_FieldAutoHooks already aliases pbSpeed and pbCalcDamageMultipliers.
# Our aliases chain cleanly on top (we alias what's already there, which is their version).
#===============================================================================

#===============================================================================
# 1. TYPE-CHANGING ABILITY DAMAGE BOOSTS
# PE v21.1 already applies ×1.2 for Galvanize/Pixilate/Refrigerate/Aerilate.
# We apply the remainder to reach the field-boosted ×1.5 total.
# Ratio: 1.5 / 1.2 ≈ 1.25; we use the exact ratio to avoid float drift.
#===============================================================================
class Battle::Move
  alias_method :fe_ab_original_pbCalcDamageMultipliers, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe_ab_original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    extra = 1.5 / 1.2   # adjust from PE's base ×1.2 to our field ×1.5

    case @battle.FE
    when :ELECTERRAIN
      if type == :ELECTRIC
        multipliers[:power_multiplier] *= extra if user.hasActiveAbility?(:GALVANIZE)
        multipliers[:power_multiplier] *= extra if user.hasActiveAbility?(:TERAVOLT)
        multipliers[:power_multiplier] *= extra if user.hasActiveAbility?(:BATTERY)
      end

    when :MISTY
      multipliers[:power_multiplier] *= extra if type == :FAIRY && user.hasActiveAbility?(:PIXILATE)

    when :ICY
      multipliers[:power_multiplier] *= extra if type == :ICE && user.hasActiveAbility?(:REFRIGERATE)

    when :SNOWYMOUNTAIN
      multipliers[:power_multiplier] *= extra if type == :ICE  && user.hasActiveAbility?(:REFRIGERATE)
      multipliers[:power_multiplier] *= extra if type == :FLYING && user.hasActiveAbility?(:AERILATE)

    when :MOUNTAIN
      multipliers[:power_multiplier] *= extra if type == :FLYING && user.hasActiveAbility?(:AERILATE)
    end
  end
end

#===============================================================================
# 2. MAGIC FIELD — ABILITY EFFECTS ON SPEED AND SPATK
#===============================================================================
class Battle::Battler
  # Telepathy doubles Speed on the Magic Field.
  # Their 016 already aliases pbSpeed; we alias what's there.
  alias_method :fe_magic_speed_original, :pbSpeed

  def pbSpeed
    spd = fe_magic_speed_original
    spd *= 2 if @battle.FE == :MAGIC && hasActiveAbility?(:TELEPATHY)
    [spd.round, 1].max
  end
end

# Pure Power / Huge Power boost SpAtk (instead of Atk) on the Magic Field.
# Hook into pbCalcDamageMultipliers on the move to double SpAtk contribution.
class Battle::Move
  alias_method :fe_magic_power_original_pbCalcDamageMultipliers, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe_magic_power_original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    return unless @battle.FE == :MAGIC && specialMove?
    if user.hasActiveAbility?(:PUREPOWER) || user.hasActiveAbility?(:HUGEPOWER)
      multipliers[:attack_multiplier] *= 2.0
    end
  end
end

#===============================================================================
# 3. COLOSSEUM — BEAST BOOST ON KO / NO SWITCHING / ROAR OVERRIDE
#===============================================================================

# No switching inside the Colosseum.
# pbCanSwitchOut? is on Battle (not Battle::Battler) in v21.1; takes idxBattler param.
module Battle::FE_ColossumSwitchHook
  def pbCanSwitchOut?(idxBattler, partyScene = nil)
    if respond_to?(:FE) && self.FE == :COLOSSEUM
      pbDisplay(_INTL("The Colosseum forbids switching!"))
      return false
    end
    super
  end
end
Battle.prepend(Battle::FE_ColossumSwitchHook)

# On KO: attacker gains +1 in their highest stat (Beast Boost style).
class Battle::Battler
  alias_method :fe_col_original_pbFaint, :pbFaint

  def pbFaint(showMessage = true)
    attacker_idx = @battle.lastAttacker[@index] rescue nil
    fe_col_original_pbFaint(showMessage)

    return unless @battle.FE == :COLOSSEUM
    return unless attacker_idx
    attacker = @battle.battlers[attacker_idx]
    return unless attacker && !attacker.fainted?

    stat_vals = {
      :ATTACK  => attacker.attack,
      :SPECIAL_ATTACK   => attacker.spatk,
      :DEFENSE => attacker.defense,
      :SPECIAL_DEFENSE   => attacker.spdef,
      :SPEED   => attacker.speed,
    }
    best = stat_vals.max_by { |_, v| v }&.first
    return unless best && attacker.pbCanRaiseStatStage?(best, attacker)
    attacker.pbRaiseStatStageBasic(best, 1)
    @battle.pbCommonAnimation("StatUp", attacker, nil)
    @battle.pbDisplay(_INTL("{1} gained power from the victory!", attacker.pbThis))
  end
end

# Roar on Colosseum: raises Atk+2/SpAtk+2 instead of forcing a switch.
# In v21.1, Roar uses Battle::Move::SwitchOutTargetStatusMove.
# The switch logic lives in pbSwitchOutTargetEffect; we override that.
class Battle::Move::SwitchOutTargetStatusMove
  alias_method :fe_col_original_pbSwitchOutTargetEffect, :pbSwitchOutTargetEffect

  def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    if @battle.FE == :COLOSSEUM
      targets.each do |target|
        next if target.fainted? || target.damageState.unaffected
        target.pbRaiseStatStageBasic(:ATTACK,         2) if target.pbCanRaiseStatStage?(:ATTACK,         user)
        target.pbRaiseStatStageBasic(:SPECIAL_ATTACK, 2) if target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user)
        @battle.pbDisplay(_INTL("{1} answered the roar with fury!", target.pbThis))
      end
      return   # suppress the actual switch-out
    end
    fe_col_original_pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
  end
end

#===============================================================================
# 4. HAUNTED FIELD — WANDERING SPIRIT EOR SPEED DRAIN
# Registered through the EOR battle hook in FE_007_EOR.
# (See FieldEffect::EOR.process_battler :HAUNTED case.)
#===============================================================================
# NOTE: No additional code needed here — the EOR module handles this.
# This file is the right place for more Haunted ability hooks if needed.

#===============================================================================
# FIELD-WIDE ABILITY PASSIVES — damage calc hooks
# All checks added to the existing FE_005 alias chain.
#===============================================================================
class Battle::Move
  alias_method :fe_ab2_original_pbCalcDamageMultipliers, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe_ab2_original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    case @battle.FE

    # CAVE — Punk Rock ×1.5 on sound moves
    when :CAVE
      if soundMove? && user.hasActiveAbility?(:PUNKROCK)
        multipliers[:power_multiplier] *= 1.5
      end

    # CRYSTALCAVERN / DARKCRYSTALCAVERN — Prism Armor: target takes ×0.75 from SE hits
    when :CRYSTALCAVERN, :DARKCRYSTALCAVERN
      if target.hasActiveAbility?(:PRISMARMOR)
        eff = Effectiveness.calculate(type, *target.pbTypes(true)) rescue nil
        if eff && Effectiveness.super_effective?(eff)
          multipliers[:final_damage_multiplier] *= 0.75
        end
      end
      # DARKCRYSTALCAVERN — Shadow Shield: target takes ×0.75 at full HP
      if @battle.FE == :DARKCRYSTALCAVERN && target.hasActiveAbility?(:SHADOWSHIELD)
        multipliers[:final_damage_multiplier] *= 0.75 if target.hp == target.totalhp
      end

    # SNOWYMOUNTAIN — Ice Scales: halve special damage when user hits a Grass/Ice resist
    when :SNOWYMOUNTAIN
      if target.hasActiveAbility?(:ICESCALES) && specialMove?
        multipliers[:defense_multiplier] *= 2.0
      end

    # GRASSY — Grass Pelt: Def ×1.5 for the target (passive defense)
    when :GRASSY
      if target.hasActiveAbility?(:GRASSPELT)
        multipliers[:defense_multiplier] *= 1.5
      end

    # MISTY — Marvel Scale: Def ×1.5 for the target
    when :MISTY
      if target.hasActiveAbility?(:MARVELSCALE) && target.status != :NONE
        multipliers[:defense_multiplier] *= 1.5
      end

    # MOUNTAIN / VOLCANICTOP — Long Reach: ×1.5 damage
    when :MOUNTAIN, :VOLCANICTOP, :SNOWYMOUNTAIN
      if user.hasActiveAbility?(:LONGREACH)
        multipliers[:power_multiplier] *= 1.5
      end

    # ROCKY — Long Reach accuracy -10% handled in pbBaseAccuracy below
    # Rock Head: no recoil (handled in recoil hook); Gorilla Tactics: double miss recoil (hooks needed)

    # COLOSSEUM — Wonder Guard: residual damage can still hurt (block immunity to indirect)
    # Defiant: Def+2 when any stat is lowered (hook in stat stage section)

    # BACKALLEY — Hustle: Attack ×1.75 but Accuracy ×0.67
    when :BACKALLEY
      if user.hasActiveAbility?(:HUSTLE) && physicalMove?
        multipliers[:attack_multiplier] *= 1.75
      end

    # HOLY — Justified: damage ×2 for Dark moves hitting user with Justified (already boosted once)
    when :HOLY
      if target.hasActiveAbility?(:JUSTIFIED) && type == :DARK
        # Justified already boosts Atk on hit; no extra damage mod needed
      end
    end
  end
end

# BACKALLEY / ROCKY — accuracy modification for Hustle and Long Reach
class Battle::Move
  alias_method :fe_ab2_original_pbBaseAccuracy, :pbBaseAccuracy

  def pbBaseAccuracy(user, target)
    acc = fe_ab2_original_pbBaseAccuracy(user, target)
    case @battle.FE
    when :BACKALLEY
      if user.hasActiveAbility?(:HUSTLE) && physicalMove? && acc > 0
        acc = (acc * 0.67).round
      end
    when :ROCKY
      if user.hasActiveAbility?(:LONGREACH) && acc > 0
        acc = [acc - 10, 1].max
      end
    end
    acc
  end
end

# GLITCH — Crit rate +1 stage if user is faster than target
# Hook pbCritialOverride (note: v21.1 has a typo — "Critial" not "Critical")
class Battle::Move
  alias_method :fe_glitch_crit_original, :pbCritialOverride

  def pbCritialOverride(user, target)
    base = fe_glitch_crit_original(user, target)
    return base unless @battle.FE == :GLITCH
    # pbCritialOverride returns -1 (never), 0 (normal), 1 (always)
    # We can only add +1 to normal crit stage, not override pbIsCritical?'s accumulator directly.
    # Increment the FocusEnergy effect as a proxy for +1 crit stage boost.
    user.effects[PBEffects::FocusEnergy] = (user.effects[PBEffects::FocusEnergy] || 0) + 1       if user.pbSpeed > target.pbSpeed && base == 0
    base
  end
end

# ICY — Burn damage halved (1/32 instead of 1/16)
# v21.1 handles burn inline in pbEORStatusProblemDamage; hook that instead.
module Battle::FE_IcyBurnHook
  def pbEORStatusProblemDamage(priority)
    if respond_to?(:FE) && self.FE == :ICY
      # Apply halved burn damage before the standard loop runs
      priority.each do |battler|
        next if battler.status != :BURN || !battler.takesIndirectDamage?
        battler.droppedBelowHalfHP = false
        dmg = [(battler.totalhp / 32.0).ceil, 1].max
        battler.pbContinueStatus { battler.pbReduceHP(dmg, false) }
        battler.pbItemHPHealCheck
        battler.pbAbilitiesOnDamageTaken
        battler.pbFaint if battler.fainted?
        battler.droppedBelowHalfHP = false
      end
      # Run everything else (poison etc.) through the normal path,
      # but temporarily null out BURN status to skip it
      priority.each do |b|
        b.instance_variable_set(:@_fe_icy_burn_skip, true) if b.status == :BURN
      end
      super
      priority.each do |b|
        b.instance_variable_set(:@_fe_icy_burn_skip, false)
      end
    else
      super
    end
  end
end
Battle.prepend(Battle::FE_IcyBurnHook)

# Skip the standard burn damage for the battler when ICY flag is set
class Battle::Battler
  alias_method :fe_icy_burn_original_pbContinueStatus, :pbContinueStatus

  def pbContinueStatus(&block)
    if @battle.FE == :ICY && status == :BURN &&        instance_variable_defined?(:@_fe_icy_burn_skip) && @_fe_icy_burn_skip
      return  # skip standard burn damage; halved version already applied above
    end
    fe_icy_burn_original_pbContinueStatus(&block)
  end
end

# HOLY — RKS System always Dark type on this field
# v21.1 determines RKS type via GameData::Item held; we override via pbTypes hook
class Battle::Battler
  alias_method :fe_holy_rks_original_pbTypes, :pbTypes

  def pbTypes(withGem = false)
    types = fe_holy_rks_original_pbTypes(withGem)
    if @battle.FE == :HOLY && hasActiveAbility?(:RKSSYSTEM)
      return [:DARK]
    end
    types
  end
end
