
    # Called when a Pokémon enters battle, and when Ally Switch is used.
  def pbEffectsOnBattlerEnteringPosition(battler)
    position = @positions[battler.index]
    # Healing Wish
    if position.effects[PBEffects::HealingWish]
      if battler.canHeal? || battler.status != :NONE
        pbCommonAnimation("HealingWish", battler)
        pbDisplay(_INTL("The healing wish came true for {1}!", battler.pbThis(true)))
        battler.pbRecoverHP(battler.totalhp)
        battler.pbCureStatus(false)
        position.effects[PBEffects::HealingWish] = false
      elsif Settings::MECHANICS_GENERATION < 8
        position.effects[PBEffects::HealingWish] = false
      end
      if %i[fairytale].any?{|f| is_field?(f)}
        if battler.pbCanRaiseStatStage?(:ATTACK, battler, self)
          showAnim = true
          battler.pbRaiseStatStage(:ATTACK, 1, battler, showAnim)
          showAnim = false
        end
        if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, self)
          battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler, showAnim)
        end
      end
    end
    # Lunar Dance
    if position.effects[PBEffects::LunarDance]
      full_pp = true
      battler.eachMove { |m| full_pp = false if m.pp < m.total_pp }
      if battler.canHeal? || battler.status != :NONE || !full_pp
        pbCommonAnimation("LunarDance", battler)
        pbDisplay(_INTL("{1} became cloaked in mystical moonlight!", battler.pbThis))
        battler.pbRecoverHP(battler.totalhp)
        battler.pbCureStatus(false)
        battler.eachMove { |m| battler.pbSetPP(m, m.total_pp) }
        position.effects[PBEffects::LunarDance] = false
      elsif Settings::MECHANICS_GENERATION < 8
        position.effects[PBEffects::LunarDance] = false
      end
    end
  end

    def pbEntryHazards(battler)
    battler_side = battler.pbOwnSide
    # Stealth Rock
    if battler_side.effects[PBEffects::StealthRock] && battler.takesIndirectDamage? &&
       GameData::Type.exists?(:ROCK) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS) &&
       !%i[dragonsden infernal crystalcave corruptcave volcanotop wasteland].any?{|f| is_field?(f)}
      bTypes = battler.pbTypes(true)
      eff = Effectiveness.calculate(:ROCK, *bTypes)
      if !Effectiveness.ineffective?(eff)
        if %i[rocky cave].any?{|f| is_field?(f)}
          battler.pbReduceHP(battler.totalhp * eff / 4, false)
        else
          battler.pbReduceHP(battler.totalhp * eff / 8, false)
        end
        pbDisplay(_INTL("Pointed stones dug into {1}!", battler.pbThis(true)))
        battler.pbItemHPHealCheck
      end
    end
      # Stealth Rock (Fire-type scaled damage)
    if battler_side.effects[PBEffects::StealthRock] && battler.takesIndirectDamage? &&
       GameData::Type.exists?(:FIRE) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS) &&
       %i[dragonsden infernal volcanotop].any?{|f| is_field?(f)}
      bTypes = battler.pbTypes(true)
      eff = Effectiveness.calculate(:FIRE, *bTypes)
      if !Effectiveness.ineffective?(eff)
        battler.pbReduceHP(battler.totalhp * eff / 8, false)
        pbDisplay(_INTL("{1} was hurt by the molten stealth rocks!", battler.pbThis))
        battler.pbItemHPHealCheck
      end
    end
    # Stealth Rock (Poison-type scaled damage)
    if battler_side.effects[PBEffects::StealthRock] && battler.takesIndirectDamage? &&
       GameData::Type.exists?(:POISON) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS) &&
       %i[corruptcave].any?{|f| is_field?(f)}
      bTypes = battler.pbTypes(true)
      eff = Effectiveness.calculate(:POISON, *bTypes)
      if !Effectiveness.ineffective?(eff)
        battler.pbReduceHP(battler.totalhp * eff / 8, false)
        pbDisplay(_INTL("{1} was hurt by the corrupted stealth rocks!", battler.pbThis))
        battler.pbItemHPHealCheck
      end
    end
    # Spikes
    if battler_side.effects[PBEffects::Spikes] > 0 && battler.takesIndirectDamage? &&
       !battler.airborne? && !battler.hasActiveItem?(:HEAVYDUTYBOOTS) &&
       !%i[wasteland].any?{|f| is_field?(f)}
      spikesDiv = [8, 6, 4][battler_side.effects[PBEffects::Spikes] - 1]
      battler.pbReduceHP(battler.totalhp / spikesDiv, false)
      pbDisplay(_INTL("{1} is hurt by the spikes!", battler.pbThis))
      battler.pbItemHPHealCheck
    end
    # toxic spikes
    if battler_side.effects[PBEffects::ToxicSpikes] > 0 && !battler.fainted? && !battler.airborne? &&
       !%i[wasteland].any?{|f| is_field?(f)}
      if battler.pbHasType?(:POISON) && !%i[corrosive].any?{|f| is_field?(f)}
        battler_side.effects[PBEffects::ToxicSpikes] = 0
        pbDisplay(_INTL("{1} absorbed the poison spikes!", battler.pbThis))
      elsif battler.pbCanPoison?(nil, false) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS)
        if battler_side.effects[PBEffects::ToxicSpikes] == 2
          battler.pbPoison(nil, _INTL("{1} was badly poisoned by the poison spikes!", battler.pbThis), true)
        else
          battler.pbPoison(nil, _INTL("{1} was poisoned by the poison spikes!", battler.pbThis))
        end
      end
    end
    # Sticky Web
    if battler_side.effects[PBEffects::StickyWeb] && !battler.fainted? && !battler.airborne? &&
       !battler.hasActiveItem?(:HEAVYDUTYBOOTS) && !%i[wasteland].any?{|f| is_field?(f)}
      pbDisplay(_INTL("{1} was caught in a sticky web!", battler.pbThis))
      if battler.pbCanLowerStatStage?(:SPEED)
        if %i[forest].any?{|f| is_field?(f)}
          battler.pbLowerStatStage(:SPEED, 2, nil)
        else
          battler.pbLowerStatStage(:SPEED, 1, nil)
        end
        battler.pbItemStatRestoreCheck
      end
    end
  end
