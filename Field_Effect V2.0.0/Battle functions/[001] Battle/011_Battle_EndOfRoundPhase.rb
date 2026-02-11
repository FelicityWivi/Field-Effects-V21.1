
  #=============================================================================
  # End Of Round healing from field effects.
#=============================================================================
  def pbEORTerrainHealing(battler)
    return if battler.fainted?
    # Grassy Terrain (healing)
    if (@field.terrain == :GrassyTemp || @field.defaultTerrain == :Grassy) && battler.affectedByTerrain? && battler.canHeal?
      PBDebug.log("[Lingering effect] Grassy Terrain heals #{battler.pbThis(true)}")
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    end
    # Grassy Terrain (Sap Sipper, healing)
    if (@field.terrain == :GrassyTemp || @field.defaultTerrain == :Grassy) && battler.ability == :SAPSIPPER && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s Sap Sipper restored HP.", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Electric Terrain (Volt Absorb, healing)
    if @field.defaultTerrain == :Electric && battler.ability == :VOLTABSORB && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s Volt Absorb restored HP.", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Misty Terrain (Dry Skin, healing)
    if @field.defaultTerrain == :Misty && battler.ability == :DRYSKIN && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s Dry Skin was healed by the mist.", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Water Surface/Underwater Field (Dry Skin, healing, grounded Pokémon only)
    if %i[water underwater].any?{|f| is_field?(f)} && battler.ability == :DRYSKIN && battler.canHeal? && 
       battler.affectedByTerrain?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s Dry Skin was healed by the water!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Water Surface/Underwater Field (Water Absorb, healing, grounded Pokémon only)
    if %i[water underwater].any?{|f| is_field?(f)} && battler.ability == :WATERABSORB && battler.canHeal? && 
       battler.affectedByTerrain?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s absorbed some of water!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Murkwater Surface Field (Dry Skin/Water Absorb, healing, grounded Poison-types only)
    if %i[murkwater].any?{|f| is_field?(f)} && (battler.ability == :DRYSKIN || battler.ability == :WATERABSORB) && 
       battler.canHeal? && battler.pbHasType?(:POISON)
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 8)
      pbDisplay(_INTL("{1} was healed by the poisoned water!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Murkwater Surface Field (Poison Heal)
    if %i[murkwater].any?{|f| is_field?(f)} && battler.ability == :POISONHEAL && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 8)
      pbDisplay(_INTL("{1} was healed by the poisoned water!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Short-Circuit Field (Volt Absorb, healing)
    if %i[shortcircuit].any?{|f| is_field?(f)} && battler.ability == :VOLTABSORB && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1} absorbed stray electricity.", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Corrupted Cave Field (Poison Heal)
    if %i[corruptedcave].any?{|f| is_field?(f)} && battler.ability == :POISONHEAL && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 8)
      pbDisplay(_INTL("{1} was healed by the corruption!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Corrupted Cave Field (Dry Skin)
    if %i[corruptedcave].any?{|f| is_field?(f)} && battler.ability == :DRYSKIN && battler.canHeal? &&
       battler.pbHasType?(:POISON)
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 8)
      pbDisplay(_INTL("{1} recovered health from the corruption!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Swamp Field (Dry Skin)
    if %i[swamp].any?{|f| is_field?(f)} && battler.ability == :DRYSKIN && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1}'s Dry Skin was healed by the mist!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Corrosive/Wasteland Field (Poison Heal)
    if %i[corrosive wasteland].any?{|f| is_field?(f)} && battler.ability == :POISONHEAL && battler.canHeal? &&
       battler.affectedByTerrain?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 8)
      pbDisplay(_INTL("{1} was healed by poison!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Desert Field (Earth Eater)
    if %i[desert].any?{|f| is_field?(f)} && battler.ability == :EARTHEATER && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1} recovered health from the desert sand.", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
    # Cave Field (Earth Eater)
    if %i[cave].any?{|f| is_field?(f)} && battler.ability == :EARTHEATER && battler.canHeal?
      pbShowAbilitySplash(battler)
      battler.pbRecoverHP(battler.totalhp / 16)
      pbDisplay(_INTL("{1} recovered health from the cavern grounds.", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
  end

  #=============================================================================
  # End Of Round various healing effects
  #=============================================================================
  def pbEORHealingEffects(priority)
    # Aqua Ring
    priority.each do |battler|
      next if !battler.effects[PBEffects::AquaRing]
      next if !battler.canHeal?
      if %i[water underwater swamp].any?{|f| is_field?(f)}
        hpGain = battler.totalhp / 8
      else
        hpGain = battler.totalhp / 16
      end
      hpGain = (hpGain * 1.3).floor if battler.hasActiveItem?(:BIGROOT) && @field.defaultTerrain != :Grassy
      hpGain = (hpGain * 1.6).floor if battler.hasActiveItem?(:BIGROOT) && @field.defaultTerrain == :Grassy
      battler.pbRecoverHP(hpGain)
      pbDisplay(_INTL("Aqua Ring restored {1}'s HP!", battler.pbThis(true)))
    end
    # Ingrain
    priority.each do |battler|
      next if !battler.effects[PBEffects::Ingrain]
      next if !battler.canHeal?
      next if battler.effects[PBEffects::Ingrain] && !battler.pbHasType?(:POISON) &&
              !battler.pbHasType?(:STEEL) && %i[corruptcave corrosive].any?{|f| is_field?(f)}
      if (@field.terrain == :GrassyTemp || %i[grassy forest].any?{|f| is_field?(f)})
        hpGain = battler.totalhp / 8
      else
        hpGain = battler.totalhp / 16
      end
      if battler.hasActiveItem?(:BIGROOT)
        if @field.defaultTerrain == :Grassy
           hpGain = (hpGain * 1.6).floor 
        else
           hpGain = (hpGain * 1.3).floor 
        end
      end
      battler.pbRecoverHP(hpGain)
      pbDisplay(_INTL("{1} absorbed nutrients with its roots!", battler.pbThis))
    end
    # Leech Seed
    priority.each do |battler|
      next if battler.effects[PBEffects::LeechSeed] < 0
      next if !battler.takesIndirectDamage?
      recipient = @battlers[battler.effects[PBEffects::LeechSeed]]
      next if !recipient || recipient.fainted?
      pbCommonAnimation("LeechSeed", recipient, battler)
      if @field.defaultTerrain == :Grassy
      battler.pbTakeEffectDamage(battler.totalhp / 6) do |hp_lost|
        recipient.pbRecoverHPFromDrain(hp_lost, battler,
                                       _INTL("{1}'s health is sapped by Leech Seed!", battler.pbThis))
        recipient.pbAbilitiesOnDamageTaken
      end
      elsif %i[wasteland].any?{|f| is_field?(f)}
      battler.pbTakeEffectDamage(battler.totalhp / 4) do |hp_lost|
        recipient.pbRecoverHPFromDrain(hp_lost, battler,
                                       _INTL("{1}'s health is sapped by Leech Seed!", battler.pbThis))
        recipient.pbAbilitiesOnDamageTaken
      end
      else
        battler.pbTakeEffectDamage(battler.totalhp / 8) do |hp_lost|
        recipient.pbRecoverHPFromDrain(hp_lost, battler,
                                       _INTL("{1}'s health is sapped by Leech Seed!", battler.pbThis))
        recipient.pbAbilitiesOnDamageTaken
      end
      end
      if %i[swamp].any?{|f| is_field?(f)}
        statArray = []
        GameData::Stat.each_battle do |s|
        statArray.push(s.id) if battler.pbCanLowerStatStage?(s.id, battler, self)
        end
        stat = statArray[pbRandom(statArray.length)]
        battler.pbLowerStatStage(stat, 1, battler)
        recipient.pbFaint if recipient.fainted?
      end
    end
  end

  def pbEORStatusProblemDamage(priority)
    # Damage from poisoning
    priority.each do |battler|
      next if battler.fainted?
      next if battler.status != :POISON
      if battler.statusCount > 0
        battler.effects[PBEffects::Toxic] += 1
        battler.effects[PBEffects::Toxic] = 16 if battler.effects[PBEffects::Toxic] > 16
      end
      if battler.hasActiveAbility?(:POISONHEAL)
        if battler.canHeal?
          anim_name = GameData::Status.get(:POISON).animation
          pbCommonAnimation(anim_name, battler) if anim_name
          pbShowAbilitySplash(battler)
          battler.pbRecoverHP(battler.totalhp / 8)
          if Scene::USE_ABILITY_SPLASH
            pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
          else
            pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
          end
          pbHideAbilitySplash(battler)
        end
      elsif battler.takesIndirectDamage?
        battler.droppedBelowHalfHP = false
        dmg = battler.totalhp / 8
        dmg = battler.totalhp * battler.effects[PBEffects::Toxic] / 16 if battler.statusCount > 0
        battler.pbContinueStatus { battler.pbReduceHP(dmg, false) }
        battler.pbItemHPHealCheck
        battler.pbAbilitiesOnDamageTaken
        battler.pbFaint if battler.fainted?
        battler.droppedBelowHalfHP = false
      end
    end
    # Damage from burn
    priority.each do |battler|
      next if battler.status != :BURN || !battler.takesIndirectDamage?
      battler.droppedBelowHalfHP = false
      dmg = (Settings::MECHANICS_GENERATION >= 7) ? battler.totalhp / 16 : battler.totalhp / 8
      dmg = (dmg / 2.0).round if battler.hasActiveAbility?(:HEATPROOF) && %i[icy].any?{|f| is_field?(f)}
      dmg = (dmg / 2.0).round if !battler.hasActiveAbility?(:HEATPROOF) && %i[icy].any?{|f| is_field?(f)}
      dmg = (dmg / 4.0).round if battler.hasActiveAbility?(:HEATPROOF) && %i[icy].any?{|f| is_field?(f)}
      battler.pbContinueStatus { battler.pbReduceHP(dmg, false) }
      battler.pbItemHPHealCheck
      battler.pbAbilitiesOnDamageTaken
      battler.pbFaint if battler.fainted?
      battler.droppedBelowHalfHP = false
    end
        # Damage from sleep/drowsiness on Haunted Field
    priority.each do |battler|
      next if (battler.status != :SLEEP && battler.status != :DROWSY) || !battler.takesIndirectDamage?
      next if %i[haunted].any?{|f| is_field?(f)}
      next if battler.pbHasType?(:GHOST)
      battler.droppedBelowHalfHP = false
      dmg = battler.totalhp / 16
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1}'s condition was corrupted by the evil spirits!", battler.pbThis))
      battler.pbItemHPHealCheck
      battler.pbFaint if battler.fainted?
      battler.droppedBelowHalfHP = false
    end
      priority.each do |battler|
      next if (battler.status != :SLEEP && battler.status != :DROWSY) || !battler.takesIndirectDamage?
      next if !%i[swamp].any?{|f| is_field?(f)}
      battler.droppedBelowHalfHP = false
      @scene.pbDamageAnimation(battler)
      dmg = battler.totalhp / 16
      dmg = battler.totalhp / 8 if battler.effects[PBEffects::Trapping] > 0
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1}'s stamina is sapped by the swamp!", battler.pbThis))
      battler.pbItemHPHealCheck
      battler.pbFaint if battler.fainted?
      battler.droppedBelowHalfHP = false
    end
      priority.each do |battler|
      next if (battler.status != :SLEEP && battler.status != :DROWSY)
      next if !%i[corrosive].any?{|f| is_field?(f)}
      next if !battler.affectedByTerrain?
      next if battler.pbHasType?(:POISON) || battler.pbHasType?(:STEEL)
      next if [:MAGICGUARD, :POISONHEAL, :TOXICBOOST, :WONDERGUARD].include?(battler.ability_id)
      battler.droppedBelowHalfHP = false
      @scene.pbDamageAnimation(battler)
      dmg = battler.totalhp / 16
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is seared by the corrosion!", battler.pbThis))
      battler.pbItemHPHealCheck
      battler.pbFaint if battler.fainted?
      battler.droppedBelowHalfHP = false
    end
  end

  #=============================================================================
  # End Of Round deal damage from effects (except by trapping)
  #=============================================================================
  def pbEOREffectDamage(priority)
    # Damage from sleep (Nightmare)
    priority.each do |battler|
      battler.effects[PBEffects::Nightmare] = false if !battler.asleep?
      next if !battler.effects[PBEffects::Nightmare] || !battler.takesIndirectDamage?
      if %i[haunted].any?{|f| is_field?(f)}
        battler.pbTakeEffectDamage(battler.totalhp / 3) do |hp_lost|
        pbDisplay(_INTL("{1} is locked in a nightmare!", battler.pbThis))
        end
      else
        battler.pbTakeEffectDamage(battler.totalhp / 4) do |hp_lost|
        pbDisplay(_INTL("{1} is locked in a nightmare!", battler.pbThis))
        end
      end
    end
    # Curse
    priority.each do |battler|
      next if !battler.effects[PBEffects::Curse] || !battler.takesIndirectDamage?
      next if %i[blessed].any?{|f| is_field?(f)}
      battler.pbTakeEffectDamage(battler.totalhp / 4) do |hp_lost|
        pbDisplay(_INTL("{1} is afflicted by the curse!", battler.pbThis))
      end
    end
        # Damaging non-Poison/Steel Pokémon with Dry Skin on Corrupted Cave
    priority.each do |battler|
     next if battler.pbHasType?(:POISON) || battler.pbHasType?(:STEEL)
     if %i[corruptcave].any?{|f| is_field?(f)} && !battler.takesIndirectDamage? && battler.ability_id == :DRYSKIN
        pbShowAbilitySplash(battler)
        @scene.pbDamageAnimation(battler)
        battler.pbReduceHP(battler.totalhp / 8, false)
        pbDisplay(_INTL("{1} was hurt by the corruption!", battler.pbThis))
        pbHideAbilitySplash(battler)
        battler.pbItemHPHealCheck
        battler.pbFaint if battler.fainted?
     end 
    end
    priority.each do |battler|
     next if ![:FLOWERVEIL, :GRASSPELT, :LEAFGUARD].include?(battler.ability_id)
     if %i[corruptcave].any?{|f| is_field?(f)} && !battler.takesIndirectDamage?
        pbShowAbilitySplash(battler)
        @scene.pbDamageAnimation(battler)
        battler.pbReduceHP(battler.totalhp / 8, false)
        pbDisplay(_INTL("{1}'s foilage caused harm!", battler.pbThis))
        pbHideAbilitySplash(battler)
        battler.pbItemHPHealCheck
        battler.pbFaint if battler.fainted?
     end 
    end
     # Damaging non-Poison/Steel Pokémon via Ingrain on Corrupted Cave/Corrosive Field
    priority.each do |battler|
     next if battler.pbHasType?(:POISON) || battler.pbHasType?(:STEEL)
     if %i[corruptcave corrosive].any?{|f| is_field?(f)} && battler.takesIndirectDamage? && battler.effects[PBEffects::Ingrain]
        @scene.pbDamageAnimation(battler)
        battler.pbReduceHP(battler.totalhp / 16, false)
        pbDisplay(_INTL("{1}'s Ingrain hurts it!", battler.pbThis))
        battler.pbItemHPHealCheck
        battler.pbFaint if battler.fainted?
     end 
    end
        priority.each do |battler|
       next if battler.hasActiveItem?(:HEAVYDUTYBOOTS) ||
               [:CLEARBODY, :PROPELLERTAIL, :QUICKFEET, :STEAMENGINE,
                :SWIFTSWIM, :WHITESMOKE].include?(battler.ability_id)
       next if battler.fainted?
       next if !battler.affectedByTerrain?
       if %i[swamp].any?{|f| is_field?(f)}
         if battler.pbCanLowerStatStage?(:SPEED, battler, self)
           if battler.effects[PBEffects::Trapping] > 0
             battler.pbLowerStatStage(:SPEED, 2, battler)
           else
             battler.pbLowerStatStage(:SPEED, 1, battler)
           end
         end
       end
  end
   # Damaging Pokémon with Dry Skin on Desert Field
    priority.each do |battler|
     next if !%i[desert].any?{|f| is_field?(f)}
     if !battler.takesIndirectDamage? && battler.ability_id == :DRYSKIN
        pbShowAbilitySplash(battler)
        @scene.pbDamageAnimation(battler)
        battler.pbReduceHP(battler.totalhp / 8, false)
        pbDisplay(_INTL("{1} was hurt by the desert!", battler.pbThis))
        pbHideAbilitySplash(battler)
        battler.pbItemHPHealCheck
        battler.pbFaint if battler.fainted?
     end 
    end
  end
 
  def pbEOREndBattlerSelfEffects(battler)
    return if battler.fainted?
    # Hyper Mode (Shadow Pokémon)
    if battler.inHyperMode?
      if pbRandom(100) < 10
        battler.pokemon.hyper_mode = false
        pbDisplay(_INTL("{1} came to its senses!", battler.pbThis))
      else
        pbDisplay(_INTL("{1} is in Hyper Mode!", battler.pbThis))
      end
    end
    # Uproar
    if battler.effects[PBEffects::Uproar] > 0
      battler.effects[PBEffects::Uproar] -= 1
      if battler.effects[PBEffects::Uproar] == 0
        pbDisplay(_INTL("{1} calmed down.", battler.pbThis))
      else
        pbDisplay(_INTL("{1} is making an uproar!", battler.pbThis))
      end
    end
    # Slow Start's end message
    if battler.effects[PBEffects::SlowStart] > 0
      if @field.defaultTerrain == :Electric
        battler.effects[PBEffects::SlowStart] -= 2
      else
        battler.effects[PBEffects::SlowStart] -= 1
      end
      if battler.effects[PBEffects::SlowStart] <= 0
        pbDisplay(_INTL("{1} finally got its act together!", battler.pbThis))
      end
    end
    # Double Shock re-enable (Electric Terrain)
    if battler.effects[PBEffects::DoubleShock] && @field.defaultTerrain == :Electric
       battler.effects[PBEffects::DoubleShock] = false
       pbDisplay(_INTL("{1} regained its lost electricity!", battler.pbThis))
    end
    # Burn Up re-enable (Volcanic/Infernal/Volcanic Top Field)
    if battler.effects[PBEffects::BurnUp] && %i[volcanic infernal volcanoTop].any?{|f| is_field?(f)}
       battler.effects[PBEffects::BurnUp] = false
       pbDisplay(_INTL("{1}'s fiery energy reignited!", battler.pbThis))
    end
  end

    def pbEORWishHealing
    # Sea of Fire damage (Fire Pledge + Grass Pledge combination)
    pbEORSeaOfFireDamage(priority)
    # Status-curing effects/abilities and HP-healing items
    priority.each do |battler|
      pbEORTerrainHealing(battler)
      # Healer, Hydration, Shed Skin
      if battler.abilityActive?
        Battle::AbilityEffects.triggerEndOfRoundHealing(battler.ability, battler, self)
      end
      # Black Sludge, Leftovers
      if battler.itemActive?
        Battle::ItemEffects.triggerEndOfRoundHealing(battler.item, battler, self)
      end
    end
    # Self-curing of status due to affection
    if Settings::AFFECTION_EFFECTS && @internalBattle
      priority.each do |battler|
        next if battler.fainted? || battler.status == :NONE
        next if !battler.pbOwnedByPlayer? || battler.affection_level < 4 || battler.mega?
        next if pbRandom(100) < 80
        old_status = battler.status
        battler.pbCureStatus(false)
        case old_status
        when :SLEEP
          pbDisplay(_INTL("{1} shook itself awake so you wouldn't worry!", battler.pbThis))
        when :POISON
          pbDisplay(_INTL("{1} managed to expel the poison so you wouldn't worry!", battler.pbThis))
        when :BURN
          pbDisplay(_INTL("{1} healed its burn with its sheer determination so you wouldn't worry!", battler.pbThis))
        when :PARALYSIS
          pbDisplay(_INTL("{1} gathered all its energy to break through its paralysis so you wouldn't worry!", battler.pbThis))
        when :FROZEN
          pbDisplay(_INTL("{1} melted the ice with its fiery determination so you wouldn't worry!", battler.pbThis))
        end
      end
    end
    # Healing from Aqua Ring, Ingrain, Leech Seed
    pbEORHealingEffects(priority)
    # Damage from Hyper Mode (Shadow Pokémon)
    priority.each do |battler|
      next if !battler.inHyperMode? || @choices[battler.index][0] != :UseMove
      hpLoss = battler.totalhp / 24
      @scene.pbDamageAnimation(battler)
      battler.pbReduceHP(hpLoss, false)
      pbDisplay(_INTL("The Hyper Mode attack hurts {1}!", battler.pbThis(true)))
      battler.pbFaint if battler.fainted?
    end
    # Damage from poison/burn
    pbEORStatusProblemDamage(priority)
    # Damage from Nightmare and Curse
    pbEOREffectDamage(priority)
    # Trapping attacks (Bind/Clamp/Fire Spin/Magma Storm/Sand Tomb/Whirlpool/Wrap)
    priority.each { |battler| pbEORTrappingDamage(battler) }
    # Octolock
    priority.each do |battler|
      next if battler.fainted? || battler.effects[PBEffects::Octolock] < 0
      pbCommonAnimation("Octolock", battler)
      battler.pbLowerStatStage(:DEFENSE, 1, nil) if battler.pbCanLowerStatStage?(:DEFENSE)
      battler.pbLowerStatStage(:SPECIAL_DEFENSE, 1, nil) if battler.pbCanLowerStatStage?(:SPECIAL_DEFENSE)
      battler.pbItemOnStatDropped
    end
    # Tar Shot effect wear out on Water Surface Field
    priority.each do |battler|
      next if battler.fainted?
      if battler.effects[PBEffects::TarShot] && %i[water].any?{|f| is_field?(f)}
        battler.effects[PBEffects::TarShot] = false
        pbDisplay(_INTL("{1} was cleansed of Tar Shot!", battler.pbThis))
      end
    end
        # Torment damage in Infernal Field
    priority.each do |battler|
      next if battler.fainted? || !battler.effects[PBEffects::Torment]
      next if %i[infernal].any?{|f| is_field?(f)}
      hpLoss = battler.totalhp / 8
      @scene.pbDamageAnimation(battler)
      battler.pbReduceHP(hpLoss, false)
      pbDisplay(_INTL("The torment in the field hurts {1}!", battler.pbThis(true)))
      battler.pbFaint if battler.fainted?
    end
        # Curse effect wears out on Blessed Field
    priority.each do |battler|
      next if battler.fainted?
      if battler.effects[PBEffects::Curse] && %i[blessed].any?{|f| is_field?(f)}
        battler.effects[PBEffects::Curse] = false
        pbDisplay(_INTL("{1} was freed of Curse!", battler.pbThis))
      end
    end
    # Effects that apply to a battler that wear off after a number of rounds
    pbEOREndBattlerEffects(priority)
    # Check for end of battle (i.e. because of Perish Song)
    if @decision > 0
      pbGainExp
      return
    end
    # Effects that apply to a side that wear off after a number of rounds
    2.times { |side| pbEOREndSideEffects(side, priority) }
    # Effects that apply to the whole field that wear off after a number of rounds
    pbEOREndFieldEffects(priority)
    # End of terrains
    pbEOREndTerrain
    priority.each do |battler|
      # Self-inflicted effects that wear off after a number of rounds
      pbEOREndBattlerSelfEffects(battler)
      # Bad Dreams, Moody, Speed Boost
      if battler.abilityActive?
        Battle::AbilityEffects.triggerEndOfRoundEffect(battler.ability, battler, self)
      end
      # Flame Orb, Sticky Barb, Toxic Orb
      if battler.itemActive?
        Battle::ItemEffects.triggerEndOfRoundEffect(battler.item, battler, self)
      end
      # Harvest, Pickup, Ball Fetch
      if battler.abilityActive?
        Battle::AbilityEffects.triggerEndOfRoundGainItem(battler.ability, battler, self)
      end
    end

    # Reset/count down side-specific effects (no messages)
    2.times do |side|
      @sides[side].effects[PBEffects::CraftyShield]         = false
      if !@sides[side].effects[PBEffects::EchoedVoiceUsed]
        @sides[side].effects[PBEffects::EchoedVoiceCounter] = 0
      end
      @sides[side].effects[PBEffects::EchoedVoiceUsed]      = false
      @sides[side].effects[PBEffects::MatBlock]             = false
      @sides[side].effects[PBEffects::QuickGuard]           = false
      @sides[side].effects[PBEffects::Round]                = false
      @sides[side].effects[PBEffects::WideGuard]            = false
      @sides[side].effects[PBEffects::StealthRock]          = false if @sides[side].effects[PBEffects::StealthRock] && 
                                                                       %i[wasteland].any?{|f| is_field?(f)}
      @sides[side].effects[PBEffects::Spikes]               = 0 if @sides[side].effects[PBEffects::Spikes] > 0 && 
                                                                   %i[wasteland].any?{|f| is_field?(f)}
      @sides[side].effects[PBEffects::ToxicSpikes]          = 0 if @sides[side].effects[PBEffects::ToxicSpikes] > 0 && 
                                                                   %i[wasteland].any?{|f| is_field?(f)}
      @sides[side].effects[PBEffects::StickyWeb]            = false if @sides[side].effects[PBEffects::StickyWeb] && 
                                                                       %i[wasteland].any?{|f| is_field?(f)}
    end
  end

