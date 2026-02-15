
#===============================================================================
# SpeedCalc handlers
#===============================================================================

Battle::AbilityEffects::SpeedCalc.add(:CHLOROPHYLL,
  proc { |ability, battler, mult|
    next mult * 2 if [:Sun, :HarshSun].include?(battler.effectiveWeather) || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
  }
)

Battle::AbilityEffects::SpeedCalc.add(:SANDRUSH,
  proc { |ability, battler, mult|
    next mult * 2 if [:Sandstorm].include?(battler.effectiveWeather) || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
  }
)

Battle::AbilityEffects::SpeedCalc.add(:SLUSHRUSH,
  proc { |ability, battler, mult|
    next mult * 2 if [:Hail].include?(battler.effectiveWeather) || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
  }
)

Battle::AbilityEffects::SpeedCalc.add(:SURGESURFER,
  proc { |ability, battler, mult|
    next mult * 2 if battler.battle.field.terrain == :Electric || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
  }
)

Battle::AbilityEffects::SpeedCalc.add(:SWIFTSWIM,
  proc { |ability, battler, mult|
    next mult * 2 if [:Rain, :HeavyRain].include?(battler.effectiveWeather) || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
  }
)

Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD,
  proc { |ability, battler, status|
    next true if [:Sun, :HarshSun].include?(battler.effectiveWeather) || battler.battle.apply_field_effect(:ability_activation, ability, battler, status).include?(ability)
  }
)

Battle::AbilityEffects::AccuracyCalcFromUser.add(:HUSTLE,
  proc { |ability, mods, user, target, move, type|
  if %i[city backalley].include?(field.id)
    mods[:accuracy_multiplier] *= 0.67 if move.physicalMove?
  else
    mods[:accuracy_multiplier] *= 0.8 if move.physicalMove?
  end
  }
)

Battle::AbilityEffects::AccuracyCalcFromTarget.add(:SANDVEIL,
  proc { |ability, mods, user, target, move, type|
    mods[:evasion_multiplier] *= 1.25 if target.effectiveWeather == :Sandstorm || user.battle.apply_field_effect(:ability_activation, ability, mods, user, target, move, type).include?(ability)
  }
)

Battle::AbilityEffects::AccuracyCalcFromTarget.add(:SNOWCLOAK,
  proc { |ability, mods, user, target, move, type|
    mods[:evasion_multiplier] *= 1.25 if target.effectiveWeather == :Hail || target.battle.apply_field_effect(:ability_activation, ability, mods, user, target, move, type).include?(ability)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:FLOWERGIFT,
  proc { |ability, user, target, move, mults, power, type|
    if move.physicalMove? && [:Sun, :HarshSun].include?(user.effectiveWeather) || user.battle.apply_field_effect(:ability_activation, ability, user, target, move, mults, power, type).include?(ability)
      mults[:attack_multiplier] *= 1.5
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:MINUS,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.specialMove?
    if user.allAllies.any? { |b| b.hasActiveAbility?([:MINUS, :PLUS]) } || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
      mults[:attack_multiplier] *= 1.5
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:MINUS, :PLUS)

Battle::AbilityEffects::DamageCalcFromUser.add(:NEUROFORCE,
  proc { |ability, user, target, move, mults, power, type|
    if Effectiveness.super_effective?(target.damageState.typeMod) || battler.battle.apply_field_effect(:ability_activation, ability, battler, mult).include?(ability)
      mults[:final_damage_multiplier] *= 1.25
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:OVERGROW,
  proc { |ability, user, target, move, mults, power, type|
    if user.hp <= user.totalhp / 3 && type == :GRASS || user.battle.apply_field_effect(:ability_activation, ability, user, target, move, mults, power, type).include?(ability)
      mults[:attack_multiplier] *= 1.5
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:SANDFORCE,
  proc { |ability, user, target, move, mults, power, type|
    if user.effectiveWeather == :Sandstorm &&
       [:ROCK, :GROUND, :STEEL].include?(type) || user.battle.apply_field_effect(:ability_activation, ability, user, target, move, mults, power, type).include?(ability)
      mults[:power_multiplier] *= 1.3
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:SWARM,
  proc { |ability, user, target, move, mults, power, type|
    if user.hp <= user.totalhp / 3 && type == :BUG || user.battle.apply_field_effect(:ability_activation, ability, user, target, move, mults, power, type).include?(ability)
      mults[:attack_multiplier] *= 1.5
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:TORRENT,
  proc { |ability, user, target, move, mults, power, type|
    if user.hp <= user.totalhp / 3 && type == :WATER || user.battle.apply_field_effect(:ability_activation, ability, user, target, move, mults, power, type).include?(ability)
      mults[:attack_multiplier] *= 1.5
    end
  }
)

#===============================================================================
# DamageCalcFromTarget handlers
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:GRASSPELT,
  proc { |ability, user, target, move, mults, power, type|
    mults[:defense_multiplier] *= 1.5 if user.battle.field.terrain == :Grassy || user.battle.apply_field_effect(:ability_activation, ability, user, target, move, mults, power, type).include?(ability)
  }
)

Battle::AbilityEffects::EndOfRoundWeather.add(:ICEBODY,
  proc { |ability, weather, battler, battle|
    next unless weather == :Hail || battle.apply_field_effect(:ability_activation, ability, weather, battler).include?(ability)
    next unless battler.canHeal?
    battle.pbShowAbilitySplash(battler)
    battler.pbRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:ANTICIPATION,
  proc { |ability, battler, battle, switch_in|
#    next if !battler.pbOwnedByPlayer?
    battlerTypes = battler.pbTypes(true)
    types = battlerTypes
    found = false
    battle.allOtherSideBattlers(battler.index).each do |b|
      b.eachMove do |m|
        next if m.statusMove?
        if types.length > 0
          moveType = m.type
          if Settings::MECHANICS_GENERATION >= 6 && m.function_code == "TypeDependsOnUserIVs"   # Hidden Power
            moveType = pbHiddenPower(b.pokemon)[0]
          end
          eff = Effectiveness.calculate(moveType, *types)
          next if Effectiveness.ineffective?(eff)
          next if !Effectiveness.super_effective?(eff) &&
                  !["OHKO", "OHKOIce", "OHKOHitsUndergroundTarget"].include?(m.function_code)
        elsif !["OHKO", "OHKOIce", "OHKOHitsUndergroundTarget"].include?(m.function_code)
          next
        end
        found = true
        break
      end
      break if found
    end
    if found
      battle.pbShowAbilitySplash(battler) 
      battle.pbDisplay(_INTL("{1} shuddered with anticipation!", battler.pbThis))
      battle.pbHideAbilitySplash(battler) if !%i[backalley].any?{|f| is_field?(f)}
    end
    if %i[backalley].any?{|f| is_field?(f)}
      battle.pbShowAbilitySplash(battler) if !found
      battle.pbDisplay(_INTL("{1} is getting ready to defend itself because of its {2}!",battler.pbThis, battler.abilityName))
      showAnim = true
      showAnim = false if battler.pbRaiseStatStage(:DEFENSE, 1, battler, showAnim)
      battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler, showAnim)
      battle.pbHideAbilitySplash(battler)
    end
    if (battler.battle.field.terrain == :PsychicTemp || battler.battle.field.defaultTerrain == :Psychic)
      if found
        showAnim = true
        showAnim = false if battler.pbRaiseStatStage(:SPECIAL_ATTACK, 2, battler, showAnim)
        battle.pbHideAbilitySplash(battler)
      else
        battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 2, battler)
      end
    end
  }
)


Battle::AbilityEffects::OnSwitchIn.add(:DOWNLOAD,
  proc { |ability, battler, battle, switch_in|
    oDef = oSpDef = 0
    battle.allOtherSideBattlers(battler.index).each do |b|
      oDef   += b.defense
      oSpDef += b.spdef
    end
    stat = (oDef < oSpDef) ? :ATTACK : :SPECIAL_ATTACK
    if %i[shortcircuit].any?{|f| is_field?(f)}
      battle.pbShowAbilitySplash(battler)
      battler.pbRaiseStatStage(:ATTACK, 1, battler)
      battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler, false)
      battle.pbHideAbilitySplash(battler)
    elsif %i[backalley factory].any?{|f| is_field?(f)}
      battler.pbRaiseStatStageByAbility(stat, 2, battler)
    else
      battler.pbRaiseStatStageByAbility(stat, 1, battler)
    end
    if %i[dimensional].any?{|f| is_field?(f)}
      randType = battle.pbRandom(18)
      case randType
      when randType = 0
        battler.pbChangeTypes(:NORMAL)
        typeName = GameData::Type.get(:NORMAL).name
      when randType = 1
        battler.pbChangeTypes(:FIRE)
        typeName = GameData::Type.get(:FIRE).name
      when randType = 2
        battler.pbChangeTypes(:WATER)
        typeName = GameData::Type.get(:WATER).name
      when randType = 3
        battler.pbChangeTypes(:ELECTRIC)
        typeName = GameData::Type.get(:ELECTRIC).name
      when randType = 4
        battler.pbChangeTypes(:GRASS)
        typeName = GameData::Type.get(:GRASS).name
      when randType = 5
        battler.pbChangeTypes(:FLYING)
        typeName = GameData::Type.get(:FLYING).name
      when randType = 6
        battler.pbChangeTypes(:FIGHTING)
        typeName = GameData::Type.get(:FIGHTING).name
      when randType = 7
        battler.pbChangeTypes(:POISON)
        typeName = GameData::Type.get(:POISON).name
      when randType = 8
        battler.pbChangeTypes(:ROCK)
        typeName = GameData::Type.get(:ROCK).name
      when randType = 9
        battler.pbChangeTypes(:BUG)
        typeName = GameData::Type.get(:BUG).name
      when randType = 10
        battler.pbChangeTypes(:GROUND)
        typeName = GameData::Type.get(:GROUND).name
      when randType = 11
        battler.pbChangeTypes(:PSYCHIC)
        typeName = GameData::Type.get(:PSYCHIC).name
      when randType = 12
        battler.pbChangeTypes(:ICE)
        typeName = GameData::Type.get(:ICE).name
      when randType = 13
        battler.pbChangeTypes(:GHOST)
        typeName = GameData::Type.get(:GHOST).name
      when randType = 14
        battler.pbChangeTypes(:DRAGON)
        typeName = GameData::Type.get(:DRAGON).name
      when randType = 15
        battler.pbChangeTypes(:DARK)
        typeName = GameData::Type.get(:DARK).name
      when randType = 16
        battler.pbChangeTypes(:STEEL)
        typeName = GameData::Type.get(:STEEL).name
      when randType = 17
        battler.pbChangeTypes(:FAIRY)
        typeName = GameData::Type.get(:FAIRY).name
      end
      battle.pbDisplay(_INTL("{1}'s type changed to {2}!", battler.pbThis, typeName))
    end
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:ELECTRICSURGE,
  proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain == :Electric
    battle.pbShowAbilitySplash(battler)
    battle.pbStartTerrain(battler, :Electric)
    # NOTE: The ability splash is hidden again in def pbStartTerrain.
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:FOREWARN,
  proc { |ability, battler, battle, switch_in|
#    next if !battler.pbOwnedByPlayer?
    if is_field?(:backalley)
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} is getting ready to defend itself because of its {2}!",battler.pbThis, battler.abilityName))
      showAnim = true
      showAnim = false if battler.pbRaiseStatStage(:DEFENSE, 1, battler, showAnim)
      battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler, showAnim)
    end
    highestPower = 0
    forewarnMoves = []
    battle.allOtherSideBattlers(battler.index).each do |b|
      b.eachMove do |m|
        power = m.power
        power = 160 if ["OHKO", "OHKOIce", "OHKOHitsUndergroundTarget"].include?(m.function_code)
        power = 150 if ["PowerHigherWithUserHP"].include?(m.function_code)    # Eruption
        # Counter, Mirror Coat, Metal Burst
        power = 120 if ["CounterPhysicalDamage",
                        "CounterSpecialDamage",
                        "CounterDamagePlusHalf"].include?(m.function_code)
        # Sonic Boom, Dragon Rage, Night Shade, Endeavor, Psywave,
        # Return, Frustration, Crush Grip, Gyro Ball, Hidden Power,
        # Natural Gift, Trump Card, Flail, Grass Knot
        power = 80 if ["FixedDamage20",
                       "FixedDamage40",
                       "FixedDamageUserLevel",
                       "LowerTargetHPToUserHP",
                       "FixedDamageUserLevelRandom",
                       "PowerHigherWithUserHappiness",
                       "PowerLowerWithUserHappiness",
                       "PowerHigherWithUserHP",
                       "PowerHigherWithTargetFasterThanUser",
                       "TypeAndPowerDependOnUserBerry",
                       "PowerHigherWithLessPP",
                       "PowerLowerWithUserHP",
                       "PowerHigherWithTargetWeight"].include?(m.function_code)
        power = 80 if Settings::MECHANICS_GENERATION <= 5 && m.function_code == "TypeDependsOnUserIVs"
        next if power < highestPower
        forewarnMoves = [] if power > highestPower
        forewarnMoves.push(m.name)
        highestPower = power
      end
    end
    if forewarnMoves.length > 0
      battle.pbShowAbilitySplash(battler) if !%i[backalley].any?{|f| is_field?(f)}
      forewarnMoveName = forewarnMoves[battle.pbRandom(forewarnMoves.length)]
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} was alerted to {2}!",
          battler.pbThis, forewarnMoveName))
      else
        battle.pbDisplay(_INTL("{1}'s Forewarn alerted it to {2}!",
          battler.pbThis, forewarnMoveName))
      end
      battle.pbHideAbilitySplash(battler)
    end
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:FRISK,
  proc { |ability, battler, battle, switch_in|
    foes = battle.allOtherSideBattlers(battler.index).select { |b| b.item }
    if foes.length > 0
      battle.pbDisplay(_INTL("Just a routine inspection.")) if %i[city].any?{|f| is_field?(f)}
      battle.pbDisplay(_INTL("Don't move a muscle!")) if %i[backalley].any?{|f| is_field?(f)}
      if Settings::MECHANICS_GENERATION >= 6
        foes.each do |b|
          battle.pbDisplay(_INTL("{1} frisked {2} and found its {3}!",
             battler.pbThis, b.pbThis(true), b.itemName))
          if %i[city].any?{|f| is_field?(f)}
            if b.pbCanLowerStatStage?(:SPECIAL_DEFENSE, battler)
              b.pbLowerStatStage(:SPECIAL_DEFENSE,1, battler)
            end
          end
          if %i[backalley].any?{|f| is_field?(f)}
            if b.pbCanLowerStatStage?(:DEFENSE, battler)
              b.pbLowerStatStage(:DEFENSE,1, battler)
            end
          end
        end
      else
        foe = foes[battle.pbRandom(foes.length)]
        battle.pbDisplay(_INTL("{1} frisked the foe and found one {2}!",
           battler.pbThis, foe.itemName))
        if %i[city].any?{|f| is_field?(f)}
            if foe.pbCanLowerStatStage?(:SPECIAL_DEFENSE, battler)
              foe.pbLowerStatStage(:SPECIAL_DEFENSE,1, battler)
            end
        end
        if %i[backalley].any?{|f| is_field?(f)}
            if foe.pbCanLowerStatStage?(:DEFENSE, battler)
              foe.pbLowerStatStage(:DEFENSE,1, battler)
            end
        end  
      end
    end
    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:GRASSYSURGE,
  proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain == :Grassy
    battle.pbShowAbilitySplash(battler)
    battle.pbStartTerrain(battler, :Grassy)
    # NOTE: The ability splash is hidden again in def pbStartTerrain.
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:MIMICRY,
  proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain == :None && !battle.has_field?
    Battle::AbilityEffects.triggerOnTerrainChange(ability, battler, battle, false)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:MISTYSURGE,
  proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain == :Misty
    battle.pbShowAbilitySplash(battler)
    battle.pbStartTerrain(battler, :Misty)
    # NOTE: The ability splash is hidden again in def pbStartTerrain.
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:PSYCHICSURGE,
  proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain == :Psychic
    battle.pbShowAbilitySplash(battler)
    battle.pbStartTerrain(battler, :Psychic)
    # NOTE: The ability splash is hidden again in def pbStartTerrain.
  }
)

Battle::AbilityEffects::OnTerrainChange.add(:MIMICRY,
  proc { |ability, battler, battle, ability_changed|
    if battle.field.terrain == :None && !battle.has_field?
      # Revert to original typing
      battle.pbShowAbilitySplash(battler)
      battler.pbResetTypes
      battle.pbDisplay(_INTL("{1} changed back to its regular type!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    else
      # Change to new typing
      terrain_hash = {
        :Electric => :ELECTRIC,
        :Grassy   => :GRASS,
        :Misty    => :FAIRY,
        :Psychic  => :PSYCHIC
      }
      new_type = terrain_hash[battle.field.terrain]

      ret = battle.apply_field_effect(:mimicry_type, ability, battler)
      new_type = ret if ret

      new_type_name = nil
      if new_type
        type_data = GameData::Type.try_get(new_type)
        new_type = nil if !type_data
        new_type_name = type_data.name if type_data
      end
      if new_type
        battle.pbShowAbilitySplash(battler)
        battler.pbChangeTypes(new_type)
        battle.pbDisplay(_INTL("{1}'s type changed to {2}!", battler.pbThis, new_type_name))
        battle.pbHideAbilitySplash(battler)
      end
    end
  }
)
