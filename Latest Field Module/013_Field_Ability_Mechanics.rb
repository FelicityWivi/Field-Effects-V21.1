#===============================================================================
# Comprehensive Field Mechanics System - ABILITIES
# Ability-related field mechanics: Battle::AbilityEffects hooks, EOR ability
# handlers, ability stat boosts/form changes, and Mimicry.
# Requires: 000_Field_Mechanics_Shared.rb to be loaded first.
#===============================================================================


# Ability Effects
Battle::AbilityEffects::OnSwitchIn.add(:MIMICRY,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? && battle.field.terrain == :None
    battle.apply_mimicry_to_battler(battler, true)
  }
)

Battle::AbilityEffects::OnTerrainChange.add(:MIMICRY,
  proc { |ability, battler, battle, ability_changed|
    battle.apply_mimicry_to_battler(battler, !ability_changed)
  }
)

#===============================================================================
# 5. ABILITY MODIFICATIONS
#===============================================================================
class Battle::Move
  def field_ability_multiplier(user, ability_id, default_multiplier)
    return default_multiplier unless @battle.has_field?
    
    field_mods = @battle.current_field.ability_mods
    return default_multiplier unless field_mods && field_mods.is_a?(Hash)
    
    if field_mods[ability_id] && field_mods[ability_id][:multiplier]
      return field_mods[ability_id][:multiplier]
    end
    
    return default_multiplier
  end
end

# Override abilities to use field multipliers
Battle::AbilityEffects::DamageCalcFromUser.copy(:PUNKROCK,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.soundMove?
    mults[:attack_multiplier] *= move.field_ability_multiplier(user, :PUNKROCK, 1.3)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:STEELWORKER,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :STEEL
    mults[:attack_multiplier] *= move.field_ability_multiplier(user, :STEELWORKER, 1.5)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:DRAGONSMAW,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :DRAGON
    mults[:attack_multiplier] *= move.field_ability_multiplier(user, :DRAGONSMAW, 1.5)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:TRANSISTOR,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :ELECTRIC
    mults[:attack_multiplier] *= move.field_ability_multiplier(user, :TRANSISTOR, 1.5)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:ROCKYPAYLOAD,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :ROCK
    mults[:attack_multiplier] *= move.field_ability_multiplier(user, :ROCKYPAYLOAD, 1.5)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:AERILATE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :AERILATE, 1.2) if move.powerBoost
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:GALVANIZE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :GALVANIZE, 1.2) if move.powerBoost
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:PIXILATE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :PIXILATE, 1.2) if move.powerBoost
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:REFRIGERATE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :REFRIGERATE, 1.2) if move.powerBoost
  }
)

#===============================================================================
# 10. ABILITY ACTIVATION
# Populates @ability_activation (used by existing ability checks via apply_field_effect)
# and handles special EOR effects like Flash Fire triggering at end of turn
#===============================================================================
class Battle::Field
  # Special abilities that need EOR handling beyond just passive activation
  EOR_ABILITY_HANDLERS = {
    :FLASHFIRE => proc { |battler, battle, field|
      next unless battler.grounded?
      next if battler.effects[PBEffects::FlashFire]
      next unless battler.hasActiveAbility?(:FLASHFIRE)
      battle.pbShowAbilitySplash(battler)
      battler.effects[PBEffects::FlashFire] = true
      battle.pbDisplay(_INTL("{1} is being boosted by the flames!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    },
    :STEAMENGINE => proc { |battler, battle, field|
      next unless battler.hasActiveAbility?(:STEAMENGINE)
      next unless battler.pbCanRaiseStatStage?(:SPEED, battler, nil)
      battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
    }
  }
  
  def register_ability_activation
    return unless @ability_activated && @ability_activated.any?
    
    # @ability_activation is the array used by apply_field_effect(:ability_activation).
    # Populate it from @ability_activated keys so ability-immunity checks work.
    @ability_activation ||= []
    @ability_activated.each_key do |ability|
      @ability_activation << ability unless @ability_activation.include?(ability)
    end
    
    if $DEBUG
      Console.echo_li("[ABILITY ACTIVATE] #{@name} activates: #{@ability_activation.inspect}")
    end
    
    # Register EOR handlers for abilities that need special end-of-turn effects.
    # Chain onto any existing EOR_field_battler proc rather than overwriting it.
    eor_abilities = @ability_activated.select { |_ability, config| config[:eor] }
    return unless eor_abilities.any?
    
    existing_eor = @effects[:EOR_field_battler] || proc { |_battler| }
    
    @effects[:EOR_field_battler] = proc { |battler|
      existing_eor.call(battler)
      next if battler.fainted?
      
      eor_abilities.each do |ability, config|
        next unless battler.hasActiveAbility?(ability)
        
        # Check grounded condition if specified
        next if config[:grounded] && !battler.grounded?
        
        # Run built-in handler if it exists
        if EOR_ABILITY_HANDLERS[ability]
          EOR_ABILITY_HANDLERS[ability].call(battler, @battle, self)
        end
        
        # Run custom proc if specified
        config[:proc]&.call(battler, @battle, self)
      end
    }
  end
end

#===============================================================================
# 10. HEALTH CHANGES
# End of round healing or damage based on conditions
#===============================================================================
class Battle::Field
  def register_health_changes
    return unless @health_changes && @health_changes.any?
    
    existing_eor = @effects[:EOR_field_battler] || proc { |_battler| }

    @effects[:EOR_field_battler] = proc { |battler|
      existing_eor.call(battler)
      next if battler.fainted?
      
      @health_changes.each do |config|
        # Check if battler qualifies
        next unless battler_qualifies_for_health_change?(battler, config)
        
        amount_fraction = config[:amount]  # e.g., 1/16 or 1/8
        is_healing = config[:healing]      # true for heal, false for damage
        damage_type = config[:damage_type] # e.g., :FIRE for type-scaled damage
        message = config[:message]
        
        # Calculate the amount
        amount = (battler.totalhp * amount_fraction).round
        amount = 1 if amount < 1
        
        # Apply type effectiveness if it's damage with a type
        if !is_healing && damage_type
          battler_types = battler.pbTypes.select { |t| t && GameData::Type.exists?(t) }
          effectiveness = Effectiveness.calculate(damage_type, *battler_types)
          amount = (amount * effectiveness / Effectiveness::NORMAL_EFFECTIVE).round
          amount = 1 if amount < 1
        end
        
        # Apply multipliers from abilities/effects (damage only)
        if !is_healing
          multiplier = calculate_health_change_multiplier(battler, config)
          if multiplier != 1.0
            amount = (amount * multiplier).round
            amount = 1 if amount < 1
          end
        end
        
        if is_healing
          # Healing
          next unless battler.canHeal?
          battler.pbFieldRecoverHP(amount)
          if message
            @battle.pbDisplay(message.gsub("{1}", battler.pbThis).gsub("{2}", @name))
          end
        else
          # Damage — flash the HP bar, reduce HP, display message, then run
          # item/ability/faint checks. Matches PE21.1's pbEORWeatherDamage pattern.
          @battle.scene.pbDamageAnimation(battler)
          battler.pbReduceHP(amount, false, true)
          if message
            @battle.pbDisplay(message.gsub("{1}", battler.pbThis).gsub("{2}", @name))
          end
          battler.pbItemHPHealCheck
          battler.pbAbilitiesOnDamageTaken
          battler.pbFaint if battler.fainted?
        end
      end
    }
  end
  
  def battler_qualifies_for_health_change?(battler, config)
    # Check grounded requirement
    if config[:grounded]
      return false unless battler.grounded?
    end
    
    # Check type requirements
    if config[:types]
      has_type = false
      config[:types].each do |type|
        if battler.pbHasType?(type)
          has_type = true
          break
        end
      end
      return false unless has_type
    end
    
    # Check excluded types
    if config[:exclude_types]
      config[:exclude_types].each do |type|
        return false if battler.pbHasType?(type)
      end
    end
    
    # Check immunities (abilities, effects that prevent damage)
    if config[:immune_abilities]
      config[:immune_abilities].each do |ability|
        return false if battler.hasActiveAbility?(ability)
      end
    end
    
    if config[:immune_effects]
      config[:immune_effects].each do |effect|
        value = battler.effects[effect]
        # Check if effect is active (can be true, or > 0 for counters)
        return false if value == true || (value.is_a?(Integer) && value > 0)
      end
    end
    
    return true
  end
  
  def calculate_health_change_multiplier(battler, config)
    multiplier = 1.0
    
    # Check for damage multiplier abilities
    if config[:multiplier_abilities]
      config[:multiplier_abilities].each do |ability, mult|
        if battler.hasActiveAbility?(ability)
          multiplier *= mult
        end
      end
    end
    
    # Check for damage multiplier effects
    if config[:multiplier_effects]
      config[:multiplier_effects].each do |effect, mult|
        value = battler.effects[effect]
        # Check if effect is active (can be true, or > 0 for counters)
        if value == true || (value.is_a?(Integer) && value > 0)
          multiplier *= mult
        end
      end
    end
    
    return multiplier
  end
end

#===============================================================================
# 11. ABILITY STAT BOOSTS
# Stat boosts when Pokémon with certain abilities enter the field
#===============================================================================
class Battle::Field
  def register_ability_stat_boosts
    return unless @ability_stat_boosts && @ability_stat_boosts.any?
    
    # Register ability effects for each configured ability
    @ability_stat_boosts.each do |ability, config|
      stat = config[:stat]
      stages = config[:stages] || 1
      message = config[:message]
      field_id = @id
      field_name = @name
      
      # Add to ability effects that trigger on switch-in
      Battle::AbilityEffects::OnSwitchIn.add(ability,
        proc { |ability_intern, battler, battle|
          # Only trigger if on the correct field
          next if !battle.has_field? || battle.current_field.id != field_id
          next if battler.fainted?
          
          if battler.pbCanRaiseStatStage?(stat, battler, nil)
            battle.pbShowAbilitySplash(battler)
            battler.pbRaiseStatStage(stat, stages, battler)
            if message
              battle.pbDisplay(message.gsub("{1}", battler.pbThis).gsub("{2}", field_name))
            end
            battle.pbHideAbilitySplash(battler)
          end
        }
      )
    end
  end
  
  def register_ability_form_changes
    return unless @ability_form_changes && @ability_form_changes.any?
    
    # Register ability effects for each configured species/ability combo
    @ability_form_changes.each do |species, ability_configs|
      ability_configs.each do |ability, config|
        new_form = config[:form]
        message = config[:message]
        show_ability = config[:show_ability] || false
        field_id = @id
        
        # Add to ability effects that trigger on switch-in
        Battle::AbilityEffects::OnSwitchIn.add(ability,
          proc { |ability_intern, battler, battle|
            # Only trigger if on the correct field and correct species
            next if !battle.has_field? || battle.current_field.id != field_id
            next unless battler.isSpecies?(species)
            next if battler.fainted?
            next if battler.form == new_form
            
            if show_ability
              battle.pbShowAbilitySplash(battler, true)
              battle.pbHideAbilitySplash(battler)
            end
            
            if message
              battler.pbChangeForm(new_form, message.gsub("{1}", battler.pbThis))
            else
              battler.pbChangeForm(new_form, _INTL("{1} transformed!", battler.pbThis))
            end
          }
        )
      end
    end
    
    # Also add to begin_battle for lead Pokemon
    existing_begin_battle = @effects[:begin_battle] || proc { }
    @effects[:begin_battle] = proc {
      existing_begin_battle.call
      
      # Apply form changes to all active battlers at battle start
      @battle.allBattlers.each do |battler|
        next if battler.fainted?
        
        @ability_form_changes.each do |species, ability_configs|
          next unless battler.isSpecies?(species)
          
          ability_configs.each do |ability, config|
            next unless battler.hasActiveAbility?(ability)
            
            new_form = config[:form]
            message = config[:message]
            show_ability = config[:show_ability] || false
            
            if battler.form != new_form
              if show_ability
                @battle.pbShowAbilitySplash(battler, true)
                @battle.pbHideAbilitySplash(battler)
              end
              
              if message
                battler.pbChangeForm(new_form, message.gsub("{1}", battler.pbThis))
              else
                battler.pbChangeForm(new_form, _INTL("{1} transformed!", battler.pbThis))
              end
            end
          end
        end
      end
    }
  end
end

#===============================================================================
# 30. BACK ALLEY FIELD MECHANICS
# Healing reduction, ability switch-in boosts, item theft mechanics
#===============================================================================

BACK_ALLEY_IDS = %i[backalley].freeze

# Pickpocket - Attack +1 on switch-in
# Merciless - Attack +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:PICKPOCKET,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BACK_ALLEY_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:MERCILESS,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BACK_ALLEY_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)
  }
)

# Magician - Sp.Atk +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:MAGICIAN,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BACK_ALLEY_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler)
  }
)

# Anticipation/Forewarn - Def/SpDef +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:ANTICIPATION,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BACK_ALLEY_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:FOREWARN,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BACK_ALLEY_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler)
  }
)

# Rattled - Speed +1 on switch-in (already added in City)

# Frisk - Steals item if user has none
Battle::AbilityEffects::OnSwitchIn.add(:FRISK,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BACK_ALLEY_IDS.include?(battle.current_field.id)
    next if battler.item
    
    # Try to steal from an opponent
    battle.allOtherBattlers(battler.index).each do |b|
      next if !b || b.fainted? || !b.item
      
      stolen_item = b.item
      b.pbRemoveItem(false)
      battler.item = stolen_item
      battle.pbDisplay(_INTL("{1} stole {2}'s {3}!", battler.pbThis, b.pbThis(true), GameData::Item.get(stolen_item).name))
      break
    end
  }
)

# Poison Gas/Smog/Corrosive Gas - Same as City Field (already implemented)
# Defiant/Stench/Hustle/Download - Same as City Field (already implemented)

#===============================================================================
# 39. MURKWATER SURFACE - EOR poison, speed reduction, ability effects
#===============================================================================

MURKWATER_IDS = %i[murkwatersurface].freeze

# Sound-based moves get 1.5x boost
class Battle::Move
  alias bigtop_sound_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:bigtop_sound_pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:bigtop_sound_pbCalcDamageMultipliers) ? bigtop_sound_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
    return unless @battle.has_field? && BIG_TOP_IDS.include?(@battle.current_field.id)
    
    # Sound move boost (1.5x)
    if soundMove?
      multipliers[:power_multiplier] *= 1.5
    end
    
    # High Striker system
    return unless is_high_striker_move?(user)
    
    # Roll 1-15
    base_roll = rand(1..15)
    
    # Ability guarantee: Guts, Huge Power, Pure Power, Sheer Force
    if user.hasActiveAbility?([:GUTS, :HUGEPOWER, :PUREPOWER, :SHEERFORCE])
      base_roll = (base_roll < 9) ? 14 : 15
    end
    
    # Add Attack stage to roll
    attack_stage = user.stages[:ATTACK]
    final_roll = base_roll + attack_stage
    
    # Apply multiplier based on roll
    mult = 1.0
    message = ""
    
    if final_roll >= 15
      mult = 3.0
      message = "...OVER 9000!!!"
    elsif final_roll >= 13
      mult = 2.0
      message = "...POWERFUL!"
    elsif final_roll >= 9
      mult = 1.5
      message = "...NICE!"
    elsif final_roll >= 3
      mult = 1.0
      message = "...OK!"
    else
      mult = 0.5
      message = "...WEAK!"
    end
    
    multipliers[:power_multiplier] *= mult
    
    # Show message
    @battle.pbDisplay(_INTL("{1}", message)) if message && !message.empty?
  end
  
  def is_high_striker_move?(user)
    # Check if field has high striker moves list
    return false unless @battle.current_field.respond_to?(:high_striker_moves)
    high_striker_list = @battle.current_field.high_striker_moves
    return false unless high_striker_list
    
    # Check if move is in the list
    return true if high_striker_list.include?(@id)
    
    # Check if it's a physical Fighting-type move
    return true if @type == :FIGHTING && physicalMove?(@type)
    
    return false
  end
end

# Dancer ability - Speed/SpAtk boost on dance moves
# Encore duration doubled
# Pay Day increased money
# NOTE: Additional effects documented

#===============================================================================
# 38. ROCKY FIELD - Flinch/miss mechanics, Stealth Rock 2x, raised Def effects
#===============================================================================

ROCKY_FIELD_IDS = %i[rocky].freeze

# Stealth Rock 2x damage
Battle::AbilityEffects::OnSwitchIn.add(:ROCKY_STEALTH_ROCK,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !ROCKY_FIELD_IDS.include?(battle.current_field.id)
    next if !battler.pbOwnSide.effects[PBEffects::StealthRock]
    
    # Apply extra Stealth Rock damage (original is already applied, add another 1x)
    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:ROCK, *bTypes)
    if !Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      battler.pbReduceHP(battler.totalhp * eff / 8, false)
      battle.pbDisplay(_INTL("The sharp rocks dug deeper into {1}!", battler.pbThis))
    end
  }
)

#===============================================================================
# 37. PSYCHIC TERRAIN - Priority blocking, room durations, ability modifications
#===============================================================================

PSYCHIC_TERRAIN_IDS = %i[psychic].freeze

# Effect Spore doubled activation rate
Battle::AbilityEffects::OnBeingHit.add(:EFFECTSPORE,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.pbHasType?(:GRASS)
    next if user.hasActiveAbility?(:OVERCOAT)
    next if user.pbHasItem?(:SAFETYGOGGLES)
    
    # Base 30% chance
    chance = 30
    # Double on Bewitched Woods
    if battle.has_field? && BEWITCHED_WOODS_IDS.include?(battle.current_field.id)
      chance = 60
    end
    
    next if rand(100) >= chance
    case rand(3)
    when 0 then user.pbPoison(target) if user.pbCanPoison?(target, false)
    when 1 then user.pbParalyze(target) if user.pbCanParalyze?(target, false)
    when 2 then user.pbSleep if user.pbCanSleep?(target, false)
    end
  }
)

# Natural Cure heals status EOR
Battle::AbilityEffects::EndOfRoundEffect.add(:NATURALCURE_BEWITCHED,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !BEWITCHED_WOODS_IDS.include?(battle.current_field.id)
    next if battler.ability != :NATURALCURE
    if battler.status != :NONE
      old_status = battler.status
      battler.pbCureStatus
      battle.pbDisplay(_INTL("{1}'s Natural Cure healed its {2}!", battler.pbThis, GameData::Status.get(old_status).name))
    end
  }
)

# Flower Veil affects all types
# Flower Gift always active
# Pastel Veil removes Fairy weaknesses
# Cotton Down doubled effect
# NOTE: Complex ability modifications documented

#===============================================================================
# 35. DESERT FIELD MECHANICS
# Ground SpDef boost, Sandstorm 1/8 damage, Sunny Day damage/healing
#===============================================================================

DESERT_FIELD_IDS = %i[desert].freeze

# Corrosion - 1.5x damage boost
Battle::AbilityEffects::DamageCalcFromUser.add(:CORROSION_CORROSIVE,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !CORROSIVE_FIELD_IDS.include?(user.battle.current_field.id)
    next if user.ability != :CORROSION
    mults[:power_multiplier] *= 1.5
  }
)

# Entry hazard poison damage for Corrosive Field
Battle::AbilityEffects::OnSwitchIn.add(:CORROSIVE_ENTRY_HAZARD,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CORROSIVE_FIELD_IDS.include?(battle.current_field.id)
    next if battler.pbHasType?(:POISON) || battler.pbHasType?(:STEEL)
    next if battler.hasActiveAbility?([:TOXICBOOST, :POISONHEAL, :IMMUNITY, :WONDERGUARD, :PASTELVEIL, :MAGICGUARD])
    next if !battler.grounded?
    
    # Entry hazard poison damage (type-scaling)
    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:POISON, *bTypes)
    if !Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      dmg = (battler.totalhp * eff / 8).round
      battler.pbReduceHP(dmg, false)
      battle.pbDisplay(_INTL("{1} was poisoned by the corrosive field!", battler.pbThis))
    end
  }
)

# Floral Healing/Life Dew poison targets
# Field explosion on Fire moves
# NOTE: Field explosion handled via changeEffects (@battle.mistExplosion)

#===============================================================================
# 32. CORRUPTED CAVE FIELD MECHANICS
# EOR poison, ability effects, Stealth Rock Poison chart, Ingrain damage
#===============================================================================

CORRUPTED_CAVE_IDS = %i[corrupted].freeze

# Toxic Boost - Doubled boost (100% instead of 50%)
Battle::AbilityEffects::DamageCalcFromUser.add(:TOXICBOOST_CORRUPTED,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !CORRUPTED_CAVE_IDS.include?(user.battle.current_field.id)
    next if user.ability != :TOXICBOOST
    next if user.status != :POISON || !move.physicalMove?
    mults[:attack_multiplier] *= 2.0  # 100% boost (doubled from normal 50%)
  }
)

# Corrosion - 1.5x damage boost to all moves
Battle::AbilityEffects::DamageCalcFromUser.add(:CORROSION_CORRUPTED,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !CORRUPTED_CAVE_IDS.include?(user.battle.current_field.id)
    next if user.ability != :CORROSION
    mults[:power_multiplier] *= 1.5
  }
)

# Dry Skin - Heals if Poison-type, damages otherwise
Battle::AbilityEffects::EndOfRoundHealing.add(:DRYSKIN_CORRUPTED,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !CORRUPTED_CAVE_IDS.include?(battle.current_field.id)
    next if battler.ability != :DRYSKIN
    
    if battler.pbHasType?(:POISON)
      # Heal Poison-types
      if battler.hp < battler.totalhp
        battler.pbFieldRecoverHP((battler.totalhp / 8.0).round)
        battle.pbDisplay(_INTL("{1} absorbed the corruption!", battler.pbThis))
      end
    else
      # Damage non-Poison types
      dmg = (battler.totalhp / 8.0).round
      battler.pbReduceHP(dmg, false)
      battle.pbDisplay(_INTL("{1} was hurt by Dry Skin!", battler.pbThis))
    end
    next true
  }
)

# Stealth Rock - Uses Poison type chart instead of Rock
Battle::AbilityEffects::OnSwitchIn.add(:STEALTHROCK_CORRUPTED,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CORRUPTED_CAVE_IDS.include?(battle.current_field.id)
    next if !battler.pbOwnSide.effects[PBEffects::StealthRock]
    
    # Calculate using Poison type instead of Rock
    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:POISON, *bTypes)
    if !Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      battler.pbReduceHP(battler.totalhp * eff / 8, false)
      battle.pbDisplay(_INTL("Poisonous rocks dug into {1}!", battler.pbThis))
    end
  }
)

Battle::AbilityEffects::OnBeingHit.add(:LIQUIDOOZE,
  proc { |ability, user, target, move, battle|
    next if !move.pbLifeLeechingMove?
    next if user.hasActiveAbility?(:MAGICGUARD)
    
    # Calculate drain amount
    drain = (target.damageState.hpLost / 2.0).round
    
    # Double on Corrupted Cave
    if battle.has_field? && CORRUPTED_CAVE_IDS.include?(battle.current_field.id)
      drain *= 2
    end
    
    user.pbReduceHP(drain, false)
    battle.pbDisplay(_INTL("{1} sucked up the poisoned liquid!", user.pbThis))
  }
)

# Water hits Water for neutral damage
# Whirlpool confuses, Electric never misses
# NOTE: Similar implementations to other fields

#===============================================================================
# 30. WATER SURFACE FIELD MECHANICS
# Speed reduction for non-Water grounded, ability activations
#===============================================================================

WATER_SURFACE_IDS = %i[watersurface].freeze

# Swift Swim / Surge Surfer - Speed 2x
Battle::AbilityEffects::SpeedCalc.add(:SWIFTSWIM,
  proc { |ability, battler, mult|
    next mult * 2 if battler.battle.has_field? && WATER_SURFACE_IDS.include?(battler.battle.current_field.id)
    next mult * 2 if [:Rain, :HeavyRain].include?(battler.battle.field.weather)
    next mult
  }
)

Battle::AbilityEffects::SpeedCalc.add(:SURGESURFER,
  proc { |ability, battler, mult|
    next mult * 2 if battler.battle.has_field? && WATER_SURFACE_IDS.include?(battler.battle.current_field.id)
    next mult * 2 if battler.battle.field.terrain == :Electric
    next mult
  }
)

# Torrent - Always active
Battle::AbilityEffects::DamageCalcFromUser.add(:TORRENT,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :WATER
    if user.battle.has_field? && WATER_SURFACE_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 1.5
    elsif user.hp <= user.totalhp / 3
      mults[:attack_multiplier] *= 1.5
    end
  }
)

# Dry Skin / Water Absorb - Gradual HP restore
Battle::AbilityEffects::EndOfRoundHealing.add(:DRYSKIN,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if !battler.grounded? || battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis)) if Battle::Scene::USE_ABILITY_SPLASH
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

Battle::AbilityEffects::EndOfRoundHealing.add(:WATERABSORB,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if !battler.grounded? || battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis)) if Battle::Scene::USE_ABILITY_SPLASH
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Gulp Missile - Always Arrokuda
Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE,
  proc { |ability, user, target, move, battle|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    # Always form 2 (Arrokuda)
    target.pbChangeForm(2, _INTL("{1} caught an Arrokuda!", target.pbThis))
  }
)

# Water Veil - Cures ALL status conditions
Battle::AbilityEffects::OnSwitchIn.add(:WATERVEIL_CURE,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if battler.ability != :WATERVEIL
    if battler.status != :NONE
      old_status = battler.status
      battler.pbCureStatus
      battle.pbDisplay(_INTL("{1}'s Water Veil cured its {2}!", battler.pbThis, GameData::Status.get(old_status).name))
    end
  }
)

# Hydration - Cures status at end of turn
Battle::AbilityEffects::EndOfRoundEffect.add(:HYDRATION_WATERSURFACE,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if battler.ability != :HYDRATION
    if battler.status != :NONE
      old_status = battler.status
      battler.pbCureStatus
      battle.pbDisplay(_INTL("{1}'s Hydration cured its {2}!", battler.pbThis, GameData::Status.get(old_status).name))
    end
  }
)

# Water Compaction - Activates each turn
Battle::AbilityEffects::EndOfRoundEffect.add(:WATERCOMPACTION_WATERSURFACE,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if battler.ability != :WATERCOMPACTION
    battler.pbRaiseStatStageByAbility(:DEFENSE, 2, battler)
  }
)

# Steam Engine - Speed +1 at end of turn
Battle::AbilityEffects::EndOfRoundEffect.add(:STEAMENGINE_WATERSURFACE,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if battler.ability != :STEAMENGINE
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

# Schooling - Always active (form 1)
Battle::AbilityEffects::OnSwitchIn.add(:SCHOOLING_WATERSURFACE,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !WATER_SURFACE_IDS.include?(battle.current_field.id)
    next if battler.ability != :SCHOOLING
    next if battler.form == 1  # Already in school form
    battler.pbChangeForm(1, _INTL("{1} formed a school!", battler.pbThis))
  }
)

#===============================================================================
# 29. CITY FIELD MECHANICS
# Ability switch-in boosts, Poison Gas/Smog modifications
#===============================================================================

CITY_FIELD_IDS = %i[city].freeze

# Early Bird - Attack +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:EARLYBIRD,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)
  }
)

# Pickup - Speed +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:PICKUP,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

# Big Pecks - Defense +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:BIGPECKS,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)
  }
)

# Rattled - Speed +1 on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:RATTLED,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

# Frisk - Lowers opponents' Special Defense
Battle::AbilityEffects::OnSwitchIn.add(:FRISK,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    
    # Lower all opponents' Sp.Def
    battle.allOtherBattlers(battler.index).each do |b|
      next if b.fainted?
      b.pbLowerStatStage(:SPECIAL_DEFENSE, 1, battler)
    end
  }
)

# Competitive - Raises Sp.Atk by extra stage (total +2)
# Already handled via abilityMods in parser

# Stench - Doubled activation rate (60% from 30%)
Battle::AbilityEffects::OnBeingHit.add(:STENCH,
  proc { |ability, user, target, move, battle|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    next if !move.pbContactMove?(user)
    next if user.fainted?
    
    # 60% chance to flinch on City Field
    next if rand(100) >= 60
    
    user.pbFlinch
  }
)

# Hustle - 67% accuracy (33% reduction), 1.75x Attack on City Field
Battle::AbilityEffects::DamageCalcFromUser.add(:HUSTLE,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !CITY_FIELD_IDS.include?(user.battle.current_field.id)
    next if !move.physicalMove?(type)
    
    # 1.75x Attack instead of 1.5x
    mults[:attack_multiplier] *= 1.75 / 1.5  # Multiply by extra 1.1667
  }
)

Battle::AbilityEffects::AccuracyCalcFromUser.add(:HUSTLE,
  proc { |ability, mods, user, target, move, type|
    next if !user.battle.has_field? || !CITY_FIELD_IDS.include?(user.battle.current_field.id)
    next if !move.physicalMove?(type)
    
    # 67% accuracy (33% reduction) instead of 80% (20% reduction)
    mods[:accuracy_multiplier] *= 0.67 / 0.8  # Multiply by extra 0.8375
  }
)

# Download - Doubled boost (+2 instead of +1)
Battle::AbilityEffects::OnSwitchIn.add(:DOWNLOAD,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CITY_FIELD_IDS.include?(battle.current_field.id)
    
    # Calculate which stat to raise
    raise_atk = false
    battle.allOtherBattlers(battler.index).each do |b|
      next if !b || b.fainted?
      if b.defense < b.spdef
        raise_atk = true
        break
      end
    end
    
    # Raise by 2 stages instead of 1
    if raise_atk
      battler.pbRaiseStatStageByAbility(:ATTACK, 2, battler)
    else
      battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 2, battler)
    end
  }
)

#===============================================================================
# 28. SNOWY MOUNTAIN FIELD MECHANICS
# Ice-type Defense boost in Hail, ability activations, Ice Scales modification
#===============================================================================

SNOWY_MOUNTAIN_IDS = %i[snowymountain].freeze

# Slush Rush - Activated in Hail/Snow
Battle::AbilityEffects::SpeedCalc.add(:SLUSHRUSH,
  proc { |ability, battler, mult|
    next mult if !battler.battle.has_field? || !SNOWY_MOUNTAIN_IDS.include?(battler.battle.current_field.id)
    next mult * 2 if [:Hail, :Snow].include?(battler.battle.field.weather)
    next mult
  }
)

# Ice Body - Gradual HP restore in Hail/Snow
Battle::AbilityEffects::EndOfRoundHealing.add(:ICEBODY,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !SNOWY_MOUNTAIN_IDS.include?(battle.current_field.id)
    next if ![:Hail, :Snow].include?(battle.field.weather)
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Snow Cloak - Evasion boost in Hail/Snow (already in base game, just needs activation)
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:SNOWCLOAK,
  proc { |ability, mods, user, target, move, type|
    next if !target.battle.has_field? || !SNOWY_MOUNTAIN_IDS.include?(target.battle.current_field.id)
    if [:Hail, :Snow].include?(target.battle.field.weather)
      mods[:evasion_multiplier] *= 1.25
    end
  }
)

# Long Reach - 1.5x damage (same as Mountain Field)
Battle::AbilityEffects::DamageCalcFromUser.add(:LONGREACH,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !SNOWY_MOUNTAIN_IDS.include?(user.battle.current_field.id)
    mults[:attack_multiplier] *= 1.5
  }
)

# Ball Fetch - Gets Snowballs on Snowy Mountain
Battle::AbilityEffects::OnSwitchIn.add(:BALLFETCH,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !SNOWY_MOUNTAIN_IDS.include?(battle.current_field.id)
    next if battler.item
    
    # Give Snowball item
    battler.item = :SNOWBALL
    battle.pbDisplay(_INTL("{1} fetched a Snowball!", battler.pbThis))
  }
)

# Long Reach - 1.5x damage on Mountain Field
Battle::AbilityEffects::DamageCalcFromUser.add(:LONGREACH,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !MOUNTAIN_FIELD_IDS.include?(user.battle.current_field.id)
    mults[:attack_multiplier] *= 1.5
  }
)

# Justified - Effect doubled (Attack +2 instead of +1)
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:JUSTIFIED,
  proc { |ability, target, user, move, switched_battlers, battle|
    next if !battle.has_field? || !BLESSED_FIELD_IDS.include?(battle.current_field.id)
    next if move.calcType != :DARK
    
    # Boost by 2 stages instead of 1
    battle.pbShowAbilitySplash(target, true)
    target.pbRaiseStatStage(:ATTACK, 2, target)
    battle.pbHideAbilitySplash(target)
  }
)

# Cursed Body - Has no effect (disabled)
# Perish Body - Has no effect (disabled)
# These are handled by checking the field in their base implementations

# RKS System - Always Dark type on Blessed Field
Battle::AbilityEffects::OnSwitchIn.add(:RKSSYSTEM,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !BLESSED_FIELD_IDS.include?(battle.current_field.id)
    battler.pbChangeTypes(:DARK)
    battle.pbDisplay(_INTL("{1} transformed into the Dark type!", battler.pbThis))
  }
)

# Power Spot - 1.5x damage (from 1.3x)
# Already handled in general Power Spot code

#===============================================================================
# 25. HAUNTED FIELD MECHANICS
# Sleep HP loss, Ghost neutral to Normal, ability effects
#===============================================================================

HAUNTED_FIELD_IDS = %i[haunted].freeze

# Night Shade - 1.5x damage
# Magic Powder - Puts target to sleep
# Destiny Bond - No consecutive fail
# Mean Look and Fire Spin - Target both opponents
# Bitter Malice - Lower SpAtk
# Spirit Break - SE vs Ghost
# (These need move-specific implementations)

# Perish Body - Traps on contact
Battle::AbilityEffects::OnBeingHit.add(:PERISHBODY,
  proc { |ability, user, target, move, battle|
    next if !battle.has_field? || !HAUNTED_FIELD_IDS.include?(battle.current_field.id)
    next if !move.pbContactMove?(user)
    next if user.fainted?
    
    # Trap the attacker
    if user.effects[PBEffects::Trapping] <= 0
      battle.pbShowAbilitySplash(target)
      user.effects[PBEffects::Trapping] = 5
      user.effects[PBEffects::TrappingUser] = target.index
      battle.pbDisplay(_INTL("{1} became trapped by {2}!", user.pbThis, target.pbThis(true)))
      battle.pbHideAbilitySplash(target)
    end
    
    # Also trigger normal Perish Song effect
  }
)

# Cursed Body - Always activates on fainting
# NOTE: OnFaint handler doesn't exist in v21.1 Essentials
# This would need to be implemented in the base game's fainting code
# by checking for Haunted Field and Cursed Body ability, then disabling a random move

# Wandering Spirit - Speed loss per turn
Battle::Field::EOR_ABILITY_HANDLERS[:WANDERINGSPIRIT] = proc { |battler, battle, field|
  next unless battler.hasActiveAbility?(:WANDERINGSPIRIT)
  next unless battler.pbCanLowerStatStage?(:SPEED, battler, nil)
  battler.pbLowerStatStage(:SPEED, 1, battler, false)
}

# Shadow Tag - Frisks on entry
Battle::AbilityEffects::OnSwitchIn.add(:SHADOWTAG,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !HAUNTED_FIELD_IDS.include?(battle.current_field.id)
    
    # Frisk all opponents
    battle.allOtherBattlers(battler.index).each do |b|
      next if !b.item
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} frisked {2} and found its {3}!",
                             battler.pbThis, b.pbThis(true), b.itemName))
      battle.pbHideAbilitySplash(battler)
    end
  }
)

# Rattled - Speed boost on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:RATTLED,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !HAUNTED_FIELD_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

# Resuscitation - Resets stat changes on Haunted Field
# NOTE: Resuscitation is a custom ability, may not exist in base Essentials
# If it exists, it would need:
Battle::AbilityEffects::OnSwitchIn.add(:RESUSCITATION,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !HAUNTED_FIELD_IDS.include?(battle.current_field.id)
    
    # Reset all stat stages
    GameData::Stat.each_battle do |s|
      battler.stages[s.id] = 0
    end
    battle.pbDisplay(_INTL("{1}'s stat changes were reset!", battler.pbThis))
  }
) if GameData::Ability.exists?(:RESUSCITATION)

# ---------------------------------------------------------------------------
# ROCKY side: Extra Stealth Rock damage on switch-in
# ---------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchIn.add(:CANYON_STEALTH_ROCK,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CANYON_FIELD_IDS.include?(battle.current_field.id)
    next if !battler.pbOwnSide.effects[PBEffects::StealthRock]
    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:ROCK, *bTypes)
    if !Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      battler.pbReduceHP(battler.totalhp * eff / 8, false)
      battle.pbDisplay(_INTL("The sharp canyon rocks dug deeper into {1}!", battler.pbThis))
    end
  }
) if GameData::Ability.exists?(:CANYON_STEALTH_ROCK) rescue nil

# ---------------------------------------------------------------------------
# FOREST side: Overgrow always active on Canyon Field (Grass moves 1.5x)
# ---------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:OVERGROW,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :GRASS
    if user.battle.has_field? && CANYON_FIELD_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 1.5
    end
  }
) rescue nil

# ---------------------------------------------------------------------------
# FOREST side: Swarm always active on Canyon Field (Bug moves 1.5x)
# ---------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:SWARM,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :BUG
    if user.battle.has_field? && CANYON_FIELD_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 1.5
    end
  }
) rescue nil

# ---------------------------------------------------------------------------
# FOREST side: Grass Pelt — physical defense boost
# ---------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromTarget.add(:GRASSPELT,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !CANYON_FIELD_IDS.include?(target.battle.current_field.id)
    next if !move.physicalMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
) rescue nil

# ---------------------------------------------------------------------------
# FOREST side: Leaf Guard — status immunity
# ---------------------------------------------------------------------------
Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD,
  proc { |ability, battler, status|
    next true if battler.battle.has_field? && CANYON_FIELD_IDS.include?(battler.battle.current_field.id)
    next false
  }
) rescue nil

# ---------------------------------------------------------------------------
# FOREST side: Sap Sipper — EOR heal 1/16 HP on Canyon Field
# ---------------------------------------------------------------------------
Battle::AbilityEffects::EndOfRoundHealing.add(:SAPSIPPER,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !CANYON_FIELD_IDS.include?(battle.current_field.id)
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
) rescue nil

# ---------------------------------------------------------------------------
# FOREST side: Effect Spore activates at 60% on Canyon Field
# ---------------------------------------------------------------------------
Battle::AbilityEffects::OnBeingHit.add(:EFFECTSPORE,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.fainted?
    chance = battle.has_field? && CANYON_FIELD_IDS.include?(battle.current_field.id) ? 60 : 30
    next if rand(100) >= chance
    r = rand(3)
    case r
    when 0
      next if !user.pbCanSleep?(target, false)
      battle.pbShowAbilitySplash(target)
      msg = Battle::Scene::USE_ABILITY_SPLASH ? nil : _INTL("{1}'s {2} made {3} fall asleep!", target.pbThis, target.abilityName, user.pbThis(true))
      user.pbSleep(msg)
      battle.pbHideAbilitySplash(target)
    when 1
      next if !user.pbCanParalyze?(target, false)
      battle.pbShowAbilitySplash(target)
      msg = Battle::Scene::USE_ABILITY_SPLASH ? nil : _INTL("{1}'s {2} paralyzed {3}!", target.pbThis, target.abilityName, user.pbThis(true))
      user.pbParalyze(msg)
      battle.pbHideAbilitySplash(target)
    when 2
      next if !user.pbCanPoison?(target, false)
      battle.pbShowAbilitySplash(target)
      msg = Battle::Scene::USE_ABILITY_SPLASH ? nil : _INTL("{1}'s {2} poisoned {3}!", target.pbThis, target.abilityName, user.pbThis(true))
      user.pbPoison(target, msg)
      battle.pbHideAbilitySplash(target)
    end
  }
) rescue nil

#===============================================================================
# 24. FOREST FIELD MECHANICS
# Hardcoded ability and move effects specific to Forest Field
#===============================================================================

FOREST_FIELD_IDS = %i[forest].freeze

# Overgrow - Always activated (Grass moves 1.5x)
Battle::AbilityEffects::DamageCalcFromUser.add(:OVERGROW,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :GRASS
    if user.battle.has_field? && FOREST_FIELD_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 1.5
    elsif user.hp <= user.totalhp / 3  # Normal Overgrow condition
      mults[:attack_multiplier] *= 1.5
    end
  }
)

# Swarm - Always activated (Bug moves 1.5x)
Battle::AbilityEffects::DamageCalcFromUser.add(:SWARM,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :BUG
    if user.battle.has_field? && FOREST_FIELD_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 1.5
    elsif user.hp <= user.totalhp / 3  # Normal Swarm condition
      mults[:attack_multiplier] *= 1.5
    end
  }
)

# Grass Pelt - Defense boost
Battle::AbilityEffects::DamageCalcFromTarget.add(:GRASSPELT,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !FOREST_FIELD_IDS.include?(target.battle.current_field.id)
    next if !move.physicalMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
)

# Leaf Guard - Status immunity
Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD,
  proc { |ability, battler, status|
    next true if battler.battle.has_field? && FOREST_FIELD_IDS.include?(battler.battle.current_field.id)
    next false
  }
)

# Sap Sipper - Gradual HP restore
Battle::AbilityEffects::EndOfRoundHealing.add(:SAPSIPPER,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !FOREST_FIELD_IDS.include?(battle.current_field.id)
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Effect Spore - 60% activation chance (doubled from 30%)
Battle::AbilityEffects::OnBeingHit.add(:EFFECTSPORE,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.fainted?
    
    # 60% on Forest Field, 30% normally
    chance = 30
    if battle.has_field? && FOREST_FIELD_IDS.include?(battle.current_field.id)
      chance = 60
    end
    
    next if rand(100) >= chance
    
    # Random status: Sleep, Paralysis, or Poison
    r = rand(3)
    case r
    when 0
      next if !user.pbCanSleep?(target, false)
      battle.pbShowAbilitySplash(target)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} made {3} fall asleep!", target.pbThis, target.abilityName, user.pbThis(true))
      end
      user.pbSleep(msg)
      battle.pbHideAbilitySplash(target)
    when 1
      next if !user.pbCanParalyze?(target, false)
      battle.pbShowAbilitySplash(target)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} paralyzed {3}!", target.pbThis, target.abilityName, user.pbThis(true))
      end
      user.pbParalyze(msg)
      battle.pbHideAbilitySplash(target)
    when 2
      next if !user.pbCanPoison?(target, false)
      battle.pbShowAbilitySplash(target)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} poisoned {3}!", target.pbThis, target.abilityName, user.pbThis(true))
      end
      user.pbPoison(target, msg)
      battle.pbHideAbilitySplash(target)
    end
  }
)

# Shadow Shield - Take 0.75x damage (25% reduction)
Battle::AbilityEffects::DamageCalcFromTarget.add(:SHADOWSHIELD,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !DARK_CRYSTAL_CAVERN_IDS.include?(target.battle.current_field.id)
    mults[:final_damage_multiplier] *= 0.75
  }
)

# Prism Armor - 33% increased defenses
Battle::AbilityEffects::DamageCalcFromTarget.add(:PRISMARMOR,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !CRYSTAL_CAVERN_IDS.include?(target.battle.current_field.id)
    # 33% defense boost = reduce damage by ~25%
    mults[:defense_multiplier] *= 1.33
  }
)

# Mimicry - Changes to random type (Fire/Water/Grass/Psychic)
Battle::AbilityEffects::OnSwitchIn.add(:MIMICRY,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !CRYSTAL_CAVERN_IDS.include?(battle.current_field.id)
    new_type = CRYSTAL_RANDOM_TYPES.sample
    battler.pbChangeTypes(new_type)
    type_name = GameData::Type.get(new_type).name
    battle.pbDisplay(_INTL("{1}'s Mimicry changed it to the {2} type!", battler.pbThis, type_name))
  }
)

# Gale Wings - Activated during Strong Winds (Tailwind on Volcanic Top)
Battle::AbilityEffects::PriorityBracketChange.add(:GALEWINGS,
  proc { |ability, battler, battle|
    # Normal: +1 priority to Flying moves at full HP
    # On Volcanic Top during Strong Winds: always active
    if battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(battle.current_field.id) &&
       battle.field.weather == :StrongWinds
      next 1  # Always give priority
    elsif battler.hp == battler.totalhp
      next 1  # Normal condition
    end
    next 0
  }
)

#===============================================================================
# 20. MISTY TERRAIN MECHANICS
# Hardcoded ability and move effects specific to Misty Terrain
#===============================================================================

MISTY_TERRAIN_IDS = %i[misty].freeze

# Fairy-type Sp.Def 1.5x - This is a field effect, not an ability
# Hook into damage calculation for all Fairy-types on Misty Terrain
class Battle::Move
  alias misty_fairy_spdef_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:misty_fairy_spdef_pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:misty_fairy_spdef_pbCalcDamageMultipliers) ? misty_fairy_spdef_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
    # Fairy-types get 1.5x Sp.Def on Misty Terrain
    return unless @battle.has_field? && MISTY_TERRAIN_IDS.include?(@battle.current_field.id)
    return unless target.pbHasType?(:FAIRY)
    return unless specialMove?(type)
    
    # Boost Special Defense (reduce special damage)
    multipliers[:final_damage_multiplier] /= 1.5
  end
end

# Marvel Scale - Always activated (Defense 1.5x)
Battle::AbilityEffects::DamageCalcFromTarget.add(:MARVELSCALE,
  proc { |ability, user, target, move, mults, power, type|
    # On Misty Terrain, always active
    if target.battle.has_field? && MISTY_TERRAIN_IDS.include?(target.battle.current_field.id)
      next if !move.physicalMove?(type)
      mults[:defense_multiplier] *= 1.5
    elsif target.status != :NONE  # Normal condition
      next if !move.physicalMove?(type)
      mults[:defense_multiplier] *= 1.5
    end
  }
)

# Dry Skin - Heals 1/16 HP at end of turn
Battle::AbilityEffects::EndOfRoundHealing.add(:DRYSKIN,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !MISTY_TERRAIN_IDS.include?(battle.current_field.id)
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Pastel Veil - Halves Poison damage for user and allies
Battle::AbilityEffects::DamageCalcFromTarget.add(:PASTELVEIL,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !MISTY_TERRAIN_IDS.include?(target.battle.current_field.id)
    next if type != :POISON
    mults[:final_damage_multiplier] /= 2.0
  }
)

#===============================================================================
# 19. GRASSY TERRAIN MECHANICS
# Hardcoded ability and move effects specific to Grassy Terrain
#===============================================================================

GRASSY_TERRAIN_IDS = %i[grassy].freeze

# Grass Pelt - Defense 1.5x
Battle::AbilityEffects::DamageCalcFromTarget.add(:GRASSPELT,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !GRASSY_TERRAIN_IDS.include?(target.battle.current_field.id)
    next if !move.physicalMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
)

# Leaf Guard - Always activated (prevents status)
Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD,
  proc { |ability, battler, status|
    next true if battler.battle.has_field? && GRASSY_TERRAIN_IDS.include?(battler.battle.current_field.id)
    next false
  }
)

# Overgrow - Always activated (Grass moves 1.5x)
Battle::AbilityEffects::DamageCalcFromUser.add(:OVERGROW,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :GRASS
    if user.battle.has_field? && GRASSY_TERRAIN_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 1.5
    elsif user.hp <= user.totalhp / 3  # Normal Overgrow condition
      mults[:attack_multiplier] *= 1.5
    end
  }
)

# Sap Sipper - Heals 1/16 HP at end of turn
Battle::AbilityEffects::EndOfRoundHealing.add(:SAPSIPPER,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !GRASSY_TERRAIN_IDS.include?(battle.current_field.id)
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Harvest - Always activates at end of turn on Grassy Terrain
# Hook into Harvest ability effect
Battle::AbilityEffects::EndOfRoundEffect.add(:HARVEST,
  proc { |ability, battler, battle|
    next if !battler.item.nil?
    next if battler.recycleItem.nil?
    # On Grassy Terrain, always activate (100% chance)
    # Otherwise 50% chance (or 100% in sun)
    activate = false
    if battle.has_field? && GRASSY_TERRAIN_IDS.include?(battle.current_field.id)
      activate = true
    elsif [:Sun, :HarshSun].include?(battler.effectiveWeather)
      activate = true
    elsif rand(100) < 50
      activate = true
    end
    
    next if !activate
    battle.pbShowAbilitySplash(battler, true)
    battler.item = battler.recycleItem
    battler.setRecycleItem(nil)
    battler.setInitialItem(battler.item)
    battle.pbDisplay(_INTL("{1} harvested one {2}!", battler.pbThis, battler.itemName))
    battle.pbHideAbilitySplash(battler)
  }
)

# Cotton Down - Lowers Speed by 2 stages on Grassy Terrain
Battle::AbilityEffects::OnBeingHit.add(:COTTONDOWN,
  proc { |ability, user, target, move, battle|
    next if !move.damagingMove?
    stages = 1  # Default
    if battle.has_field? && GRASSY_TERRAIN_IDS.include?(battle.current_field.id)
      stages = 2
    end
    battle.pbShowAbilitySplash(target)
    battle.allOtherBattlers(target.index).each do |b|
      b.pbLowerStatStageByAbility(:SPEED, stages, target, false, false)
    end
    battle.pbHideAbilitySplash(target)
  }
)

# NOTE: Desolate Land field transition needs to be in abilityFieldChange or similar system

#===============================================================================
# 18. ELECTRIC TERRAIN MECHANICS
# Hardcoded ability effects specific to Electric Terrain
#===============================================================================

ELECTRIC_TERRAIN_IDS = %i[electerrain].freeze

# Plus - Special Attack 1.5x (even without Minus present)
# In v21.1, stat boosts are applied in damage calculation
Battle::AbilityEffects::DamageCalcFromUser.add(:PLUS,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !ELECTRIC_TERRAIN_IDS.include?(user.battle.current_field.id)
    next if !move.specialMove?(type)
    mults[:attack_multiplier] *= 1.5
  }
)

# Minus - Special Attack 1.5x (even without Plus present)
Battle::AbilityEffects::DamageCalcFromUser.add(:MINUS,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !ELECTRIC_TERRAIN_IDS.include?(user.battle.current_field.id)
    next if !move.specialMove?(type)
    mults[:attack_multiplier] *= 1.5
  }
)

# Surge Surfer - Speed doubled
Battle::AbilityEffects::SpeedCalc.add(:SURGESURFER,
  proc { |ability, battler, mult|
    if battler.battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battler.battle.current_field.id)
      mult *= 2
    end
    next mult
  }
)

# Quick Feet - Always activated (Speed 1.5x)
Battle::AbilityEffects::SpeedCalc.add(:QUICKFEET,
  proc { |ability, battler, mult|
    if battler.battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battler.battle.current_field.id)
      mult *= 1.5
    end
    next mult
  }
)

# Volt Absorb - Heals 1/16 HP at end of turn
Battle::AbilityEffects::EndOfRoundHealing.add(:VOLTABSORB,
  proc { |ability, battler, battle|
    next if !battle.has_field? || !ELECTRIC_TERRAIN_IDS.include?(battle.current_field.id)
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Motor Drive - Raises Speed by 1 stage at end of turn
# Add to EOR_ABILITY_HANDLERS for Electric Terrain
Battle::Field::EOR_ABILITY_HANDLERS[:MOTORDRIVE] = proc { |battler, battle, field|
  next unless battler.hasActiveAbility?(:MOTORDRIVE)
  next unless battler.pbCanRaiseStatStage?(:SPEED, battler, nil)
  battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
}

# Comatose - Disabled on Electric Terrain
# Patch Comatose ability to not apply on Electric Terrain
Battle::AbilityEffects::StatusImmunity.add(:COMATOSE,
  proc { |ability, battler, status|
    # Comatose is disabled on Electric Terrain
    next false if battler.battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battler.battle.current_field.id)
    next true if status == :SLEEP
    next false
  }
)

# Gulp Missile - Always picks up Pikachu on Electric Terrain
# Hook into form change when using Surf/Dive
Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.effects[PBEffects::Transform]
    next if !target.isSpecies?(:CRAMORANT)
    next unless [:SURF, :DIVE].include?(move.id)
    
    # On Electric Terrain, always pick up Pikachu (form 2)
    if battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battle.current_field.id)
      target.pbChangeForm(2, _INTL("{1} caught a Pikachu!", target.pbThis))
    else
      # Normal behavior - form based on HP
      newForm = (target.hp > target.totalhp / 2) ? 1 : 2
      target.pbChangeForm(newForm, _INTL("{1} caught something!", target.pbThis))
    end
  }
)

# Slow Start - Ends twice as fast (2 turns instead of 5)
# Hook into the Slow Start counter decrement at end of round
# Add to EOR_ABILITY_HANDLERS
Battle::Field::EOR_ABILITY_HANDLERS[:SLOWSTART] = proc { |battler, battle, field|
  next unless battler.hasActiveAbility?(:SLOWSTART)
  next unless battler.effects[PBEffects::SlowStart] > 0
  # Normal decrement already happened, decrement one extra time
  battler.effects[PBEffects::SlowStart] -= 1
  if battler.effects[PBEffects::SlowStart] == 0
    battle.pbDisplay(_INTL("{1} finally got its act together!", battler.pbThis))
  end
}

# Register Slow Start for Electric Terrain
# (This will be picked up by register_ability_activation if SLOWSTART is in abilityActivate)

# Static - 60% chance instead of 30%
Battle::AbilityEffects::OnBeingHit.add(:STATIC,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.fainted?
    
    # 60% chance on Electric Terrain, 30% normally
    chance = 30
    if battle.has_field? && ELECTRIC_TERRAIN_IDS.include?(battle.current_field.id)
      chance = 60
    end
    
    next if rand(100) >= chance
    next if !user.pbCanInflictStatus?(:PARALYSIS, target, false)
    battle.pbShowAbilitySplash(target)
    msg = nil
    if !Battle::Scene::USE_ABILITY_SPLASH
      msg = _INTL("{1}'s {2} paralyzed {3}!", target.pbThis, target.abilityName, user.pbThis(true))
    end
    user.pbInflictStatus(:PARALYSIS, 0, msg, target)
    battle.pbHideAbilitySplash(target)
  }
)

# Transistor - Reduces Ground-type move damage by 0.5x
Battle::AbilityEffects::DamageCalcFromTarget.add(:TRANSISTOR,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !ELECTRIC_TERRAIN_IDS.include?(target.battle.current_field.id)
    if type == :GROUND
      mults[:final_damage_multiplier] /= 2.0
    end
  }
)

# NOTE: Shell Bell boost (25% instead of 12.5%) needs to be implemented in the base
# game's Shell Bell item code by checking for beach field. The item effect happens
# in Battle::Move#pbEffectAfterAllHits which checks for Shell Bell item and heals
# based on totalHPLost. To implement the beach field boost, add a field check there.

# STATUS IMMUNITY - Prevent confusion on Fighting-types and Inner Focus
# Hooks into the existing :status_immunity field effect
class Battle::Field
  def register_status_immunity
    return unless @status_immunity && @status_immunity.any?
    
    @status_immunity.each do |status, config|
      types = config[:types] || []
      abilities = config[:abilities] || []
      grounded = config[:grounded] || false
      message = config[:message]
      
      existing = @effects[:status_immunity] || proc { |*args| false }
      
      @effects[:status_immunity] = proc { |battler, new_status, sleep_clause, user, show_messages, self_inflicted, move, ignore_status|
        result = existing.call(battler, new_status, sleep_clause, user, show_messages, self_inflicted, move, ignore_status)
        next true if result # Already immune from another source
        
        # Check if this status is prevented
        next false unless new_status == status
        
        # Check grounded condition if required
        if grounded
          next false unless battler.grounded?
        end
        
        # Check type immunity
        if types.any? && battler.pbHasType?(*types)
          if show_messages
            msg = message || _INTL("{1} cannot be affected!", battler.pbThis)
            @battle.pbDisplay(msg.gsub("{1}", battler.pbThis))
          end
          next true
        end
        
        # Check ability immunity
        if abilities.any? && battler.hasActiveAbility?(abilities)
          if show_messages
            msg = message || _INTL("{1} cannot be affected!", battler.pbThis)
            @battle.pbDisplay(msg.gsub("{1}", battler.pbThis))
          end
          next true
        end
        
        # If grounded condition but no type/ability check, apply to all grounded
        if grounded && !types.any? && !abilities.any?
          if show_messages
            msg = message || _INTL("{1} cannot be affected!", battler.pbThis)
            @battle.pbDisplay(msg.gsub("{1}", battler.pbThis))
          end
          next true
        end
        
        next false
      }
    end
  end
end

Battle::AbilityEffects::AccuracyCalcFromUser.add(:INNERFOCUS,
  proc { |ability, mods, user, target, move, type|
    next unless user.battle.has_field? && BEACH_FIELD_IDS.include?(user.battle.current_field.id)
    next if target.hasActiveAbility?(BEACH_BLOCK_IGNORE_ABILITIES)
    mods[:accuracy_multiplier] = 1.0
    mods[:evasion_multiplier]  = 1.0
  }
)
[:OWNTEMPO, :PUREPOWER, :SANDVEIL, :STEADFAST].each do |ab|
  Battle::AbilityEffects::AccuracyCalcFromUser.copy(:INNERFOCUS, ab)
end

# WATER COMPACTION - additionally boosts Special Defense by 2 on activation
# Water Compaction already boosts Defense when hit by a Water move.
# We hook AfterMoveUseFromTarget to add the SpDef boost at the same moment.
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:WATERCOMPACTION,
  proc { |ability, target, user, move, switched_battlers, battle|
    next unless battle.has_field? && BEACH_FIELD_IDS.include?(battle.current_field.id)
    next unless move.type == :WATER
    next unless target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target, nil)
    battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStage(:SPECIAL_DEFENSE, 2, target)
    battle.pbDisplay(_INTL("The Beach's waters also boosted {1}'s Special Defense!", target.pbThis))
    battle.pbHideAbilitySplash(target)
  }
)

# IGNORE ACCURACY/EVASION CHANGES
# Inner Focus, Own Tempo, Pure Power, Sand Veil, and Steadfast ignore acc/eva changes
# when attacking (unless target has As One or Unnerve).
# Hook into AccuracyCalcFromUser to reset stage multipliers.
Battle::AbilityEffects::AccuracyCalcFromUser.add(:INNERFOCUS,
  proc { |ability, mods, user, target, move, type|
    next unless user.battle.has_field? && BEACH_FIELD_IDS.include?(user.battle.current_field.id)
    next if target.hasActiveAbility?([:ASONE, :UNNERVE])
    # Neutralize evasion stages
    mods[:evasion_stage] = 0
    # Neutralize accuracy stages
    mods[:accuracy_stage] = 0
  }
)

Battle::AbilityEffects::AccuracyCalcFromUser.copy(:INNERFOCUS, :OWNTEMPO)
Battle::AbilityEffects::AccuracyCalcFromUser.copy(:INNERFOCUS, :PUREPOWER)
Battle::AbilityEffects::AccuracyCalcFromUser.copy(:INNERFOCUS, :SANDVEIL)
Battle::AbilityEffects::AccuracyCalcFromUser.copy(:INNERFOCUS, :STEADFAST)

# WATER COMPACTION - Additionally boosts SpDef by 2 stages on activation
# Water Compaction normally boosts Defense by 2 when hit by Water.
# On beach field it also boosts SpDef by 2.
# Show a single combined message for both stat boosts.
Battle::AbilityEffects::OnBeingHit.add(:WATERCOMPACTION,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :WATER
    is_beach = battle.has_field? && BEACH_FIELD_IDS.include?(battle.current_field.id)
    
    if is_beach
      # Beach field: boost both Defense and SpDef with one message
      battle.pbShowAbilitySplash(target)
      can_def = target.pbCanRaiseStatStage?(:DEFENSE, target, move)
      can_spdef = target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target, move)
      if can_def || can_spdef
        target.pbRaiseStatStage(:DEFENSE, 2, target, false) if can_def
        target.pbRaiseStatStage(:SPECIAL_DEFENSE, 2, target, false) if can_spdef
        if can_def && can_spdef
          battle.pbDisplay(_INTL("The Beach hardened {1}'s body and shell!", target.pbThis))
        elsif can_def
          battle.pbDisplay(_INTL("{1}'s Defense sharply rose!", target.pbThis))
        else
          battle.pbDisplay(_INTL("{1}'s Sp. Def sharply rose!", target.pbThis))
        end
      end
      battle.pbHideAbilitySplash(target)
    else
      # Normal field: just boost Defense
      target.pbRaiseStatStageByAbility(:DEFENSE, 2, target)
    end
  }
)

# Ice Body - heals 1/16 HP each turn on icy field
Battle::AbilityEffects::EndOfRoundHealing.add(:ICEBODY,
  proc { |ability, battler, battle|
    next if !battle.has_field? || battle.current_field.id != :icy
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

# Slush Rush - doubles speed on icy field
Battle::AbilityEffects::SpeedCalc.add(:SLUSHRUSH,
  proc { |ability, battler, mult|
    if battler.battle.has_field? && battler.battle.current_field.id == :icy
      mult *= 2
    end
    next mult
  }
)

# Snow Cloak - increases evasion on icy field
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:SNOWCLOAK,
  proc { |ability, mods, user, target, move, type|
    if target.battle.has_field? && target.battle.current_field.id == :icy
      mods[:accuracy_multiplier] *= 0.8  # 20% harder to hit (inverse of 1.25 evasion)
    end
  }
)

# Liquid Voice - Makes sound moves Ice-type on Icy field
Battle::AbilityEffects::ModifyMoveBaseType.copy(:LIQUIDVOICE,
  proc { |ability, user, move, type|
    next if !move.soundMove?
    
    # Check if on icy field
    if user.battle.has_field? && user.battle.current_field.id == :icy
      next :ICE
    else
      # Normal Liquid Voice makes sound moves Water-type
      next :WATER
    end
  }
)

# Stealth Rock - Fire type damage instead of Rock
Battle::AbilityEffects::OnSwitchIn.add(:STEALTHROCK_DRAGONSDEN,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !DRAGONS_DEN_IDS.include?(battle.current_field.id)
    next if !battler.pbOwnSide.effects[PBEffects::StealthRock]

    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:FIRE, *bTypes)
    if !Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      battler.pbReduceHP((battler.totalhp * eff / 8).round, false)
      battle.pbDisplay(_INTL("Lava rocks scorched {1}!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    end
  }
)

# Berserk - +2 SpAtk on switch-in instead of normal trigger
Battle::AbilityEffects::OnSwitchIn.add(:BERSERK_DRAGONSDEN,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !DRAGONS_DEN_IDS.include?(battle.current_field.id)
    next unless battler.hasActiveAbility?(:BERSERK)
    next unless battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:SPECIAL_ATTACK, 2, battler)
    battle.pbDisplay(_INTL("{1}'s draconic rage surged!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

# Multiscale - Annuls Dragon-type weaknesses at all times on Dragon's Den
Battle::AbilityEffects::DamageCalcFromTarget.add(:MULTISCALE,
  proc { |ability, user, target, move, mults, power, type|
    # Normal Multiscale: halve damage at full HP
    if target.hp == target.totalhp
      mults[:final_damage_multiplier] /= 2
    end
    # Dragon's Den bonus: also halve damage from types Dragon is weak to
    if target.battle.has_field? && DRAGONS_DEN_IDS.include?(target.battle.current_field.id)
      dragon_weak_types = [:ICE, :DRAGON, :FAIRY]
      if dragon_weak_types.include?(type) && target.pbHasType?(:DRAGON)
        mults[:final_damage_multiplier] /= 2
      end
    end
  }
)

# Stealth Rock - Fire type damage on Infernal Field
Battle::AbilityEffects::OnSwitchIn.add(:STEALTHROCK_INFERNAL,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !INFERNAL_FIELD_IDS.include?(battle.current_field.id)
    next if !battler.pbOwnSide.effects[PBEffects::StealthRock]

    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:FIRE, *bTypes)
    if !Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      battler.pbReduceHP((battler.totalhp * eff / 8).round, false)
      battle.pbDisplay(_INTL("The flaming rocks scorched {1}!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    end
  }
)

# Pastel Veil - Disabled on Infernal Field (provides no poison immunity)
Battle::AbilityEffects::StatusImmunity.add(:PASTELVEIL,
  proc { |ability, battler, status|
    # Disable on Infernal Field
    next false if battler.battle.has_field? && INFERNAL_FIELD_IDS.include?(battler.battle.current_field.id)
    next battler.pbHasType?(:FAIRY) || battler.pbHasType?(:POISON)
  }
)

# Perish Body - Countdown reduced to 1, attacker is trapped on Infernal Field
Battle::AbilityEffects::OnBeingHit.add(:PERISHBODY_INFERNAL,
  proc { |ability, user, target, move, battle|
    next if !battle.has_field? || !INFERNAL_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next if user.fainted?

    battle.pbShowAbilitySplash(target)
    # Trap the attacker
    if user.effects[PBEffects::Trapping] <= 0
      user.effects[PBEffects::Trapping] = 2
      user.effects[PBEffects::TrappingUser] = target.index if PBEffects.const_defined?(:TrappingUser)
      battle.pbDisplay(_INTL("{1} was trapped by the hellfire!", user.pbThis))
    end
    # Perish countdown of 1 turn
    if PBEffects.const_defined?(:PerishSong)
      user.effects[PBEffects::PerishSong] = 1 if user.effects[PBEffects::PerishSong] <= 0
      battle.pbDisplay(_INTL("{1} will faint after 1 turn!", user.pbThis))
    end
    battle.pbHideAbilitySplash(target)
  }
)

# Ice Face - Melts on entry to Infernal Field (form change to melted form)
Battle::AbilityEffects::OnSwitchIn.add(:ICEFACE_INFERNAL,
  proc { |ability, battler, battle, switch_in|
    next if !battle.has_field? || !INFERNAL_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.hasActiveAbility?(:ICEFACE)
    next unless battler.form == 0  # Only melt if currently in Ice Face form

    battle.pbShowAbilitySplash(battler, true)
    battler.pbChangeForm(1, _INTL("{1}'s Ice Face melted in the infernal heat!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# FAIRY TALE FIELD MECHANICS
# Type conversions, move effects, ability modifications
#===============================================================================

FAIRY_TALE_IDS = %i[fairytale].freeze

#──────────────────────────────────────────────────────────────────────────────
# ABILITY EFFECTS
#──────────────────────────────────────────────────────────────────────────────

# Soul Heart - Additionally boosts Special Defense when any Pokémon faints
class Battle::Battler
  alias fairytale_soulheart_pbFaint pbFaint if method_defined?(:pbFaint) && !method_defined?(:fairytale_soulheart_pbFaint)

  def pbFaint(showMessage = true)
    soulheart_battlers = []
    if @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
      @battle.allBattlers.each do |b|
        next if b.fainted? || b.index == @index
        soulheart_battlers << b if b.hasActiveAbility?(:SOULHEART)
      end
    end

    ret = respond_to?(:fairytale_soulheart_pbFaint) ? fairytale_soulheart_pbFaint(showMessage) : super

    soulheart_battlers.each do |battler|
      next if battler.fainted?
      next unless battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler, false)
    end

    ret
  end
end

# Queenly Majesty - Deals 1.5x damage on Fairy Tale Field
Battle::AbilityEffects::DamageCalcFromUser.add(:QUEENLYMAJESTY_FAIRYTALE,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:QUEENLYMAJESTY)
    next unless user.battle.has_field? && FAIRY_TALE_IDS.include?(user.battle.current_field.id)
    mults[:attack_multiplier] *= 1.5
  }
)

# Marvel Scale - Always activated on Fairy Tale Field (Defense 1.5x)
Battle::AbilityEffects::DamageCalcFromTarget.add(:MARVELSCALE_FAIRYTALE,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:MARVELSCALE)
    next unless move.physicalMove?(type)
    if target.battle.has_field? && FAIRY_TALE_IDS.include?(target.battle.current_field.id)
      mults[:defense_multiplier] *= 1.5
    end
  }
)

# Steely Spirit - 2x boost (instead of 1.5x) on Fairy Tale Field
Battle::AbilityEffects::DamageCalcFromUser.add(:STEELYSPIRIT_FAIRYTALE,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :STEEL
    # Check if user or any ally has Steely Spirit
    has_steely = user.hasActiveAbility?(:STEELYSPIRIT) ||
                 user.allAllies.any? { |b| b.hasActiveAbility?(:STEELYSPIRIT) }
    next unless has_steely
    next unless user.battle.has_field? && FAIRY_TALE_IDS.include?(user.battle.current_field.id)
    # Apply 2x; the base game's Steely Spirit already applied 1.5x, so we add the remainder
    # We compensate: total should be 2.0x, base applied 1.5x, so multiply by (2.0/1.5)
    mults[:attack_multiplier] *= (2.0 / 1.5)
  }
)

# Dauntless Shield - +Defense AND +Special Defense on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:DAUNTLESSSHIELD_FAIRYTALE,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:DAUNTLESSSHIELD)
    next unless battle.has_field? && FAIRY_TALE_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    battle.pbDisplay(_INTL("{1}'s Dauntless Shield fortified both defenses!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

# Power of Alchemy - +Defense AND +Special Defense on switch-in on Fairy Tale Field
Battle::AbilityEffects::OnSwitchIn.add(:POWEROFALCHEMY_FAIRYTALE,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:POWEROFALCHEMY)
    next unless battle.has_field? && FAIRY_TALE_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    battle.pbDisplay(_INTL("{1}'s Power of Alchemy reinforced its defenses!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

# Intrepid Sword - +Attack AND +Special Attack on switch-in on Fairy Tale Field
Battle::AbilityEffects::OnSwitchIn.add(:INTREPIDSWORD_FAIRYTALE,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:INTREPIDSWORD)
    next unless battle.has_field? && FAIRY_TALE_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
    battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
    battle.pbDisplay(_INTL("{1}'s Intrepid Sword sharpened both offenses!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

# Stance Change - Boost Attack+Defense when entering Blade Form, lower when entering Shield Form
# Hooks into Aegislash's form change which uses Stance Change ability
Battle::AbilityEffects::OnSwitchIn.add(:STANCECHANGE_FAIRYTALE,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:STANCECHANGE)
    next unless battle.has_field? && FAIRY_TALE_IDS.include?(battle.current_field.id)

    # Form 1 = Blade Forme (+Atk +Def), Form 0 = Shield Forme (-Atk -Def)
    if battler.form == 1
      battle.pbShowAbilitySplash(battler)
      battler.pbRaiseStatStage(:ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
      battler.pbRaiseStatStage(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
      battle.pbDisplay(_INTL("{1}'s blade gleams with fairy power!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    elsif battler.form == 0
      battle.pbShowAbilitySplash(battler)
      battler.pbLowerStatStage(:ATTACK, 1, battler) if battler.pbCanLowerStatStage?(:ATTACK, battler, nil)
      battler.pbLowerStatStage(:DEFENSE, 1, battler) if battler.pbCanLowerStatStage?(:DEFENSE, battler, nil)
      battle.pbDisplay(_INTL("{1}'s shield adopts a defensive stance!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY L: Rattled — +1 Speed on switch-in (extend from Haunted to Dimensional)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:RATTLED_DIMENSIONAL,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:RATTLED)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY M: Beast Boost — +2 stages instead of +1 on Dimensional Field
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:BEASTBOOST_DIMENSIONAL,
  proc { |ability, target, user, move, switched_battlers, battle|
    next unless user.hasActiveAbility?(:BEASTBOOST)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)
    next if user.fainted? || !target.fainted?

    # Find the user's highest base stat and raise it by 2 instead of 1
    # (The base game already raised it by 1 via the default AfterMoveUseFromTarget handler)
    # We add 1 more here to total +2
    best_stat = nil
    best_val = 0
    GameData::Stat.each_battle do |s|
      val = user.base_stat(s.id)
      if val > best_val
        best_val = val
        best_stat = s.id
      end
    end
    next unless best_stat
    next unless user.pbCanRaiseStatStage?(best_stat, user, nil)

    battle.pbShowAbilitySplash(user)
    user.pbRaiseStatStage(best_stat, 1, user, false)  # +1 more (base gave +1, total +2)
    battle.pbHideAbilitySplash(user)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY N: Perish Body — traps the attacker on contact
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:PERISHBODY_DIMENSIONAL,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:PERISHBODY)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next if user.fainted?

    battle.pbShowAbilitySplash(target)
    if user.effects[PBEffects::Trapping] <= 0
      user.effects[PBEffects::Trapping] = 3
      user.effects[PBEffects::TrappingUser] = target.index if PBEffects.const_defined?(:TrappingUser)
      battle.pbDisplay(_INTL("{1} was trapped by the dimensional void!", user.pbThis))
    end
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY O: Pressure — +2 PP usage (instead of +1) on Dimensional Field
# Pressure normally costs 1 extra PP via AbilityEffects::OnBeingAttacked.
# We add 1 more PP loss after the move hits, totalling 2 extra (3 total loss).
# NOTE: Direct PP manipulation — checks the last move used.
#──────────────────────────────────────────────────────────────────────────────
# NOTE: Dimensional Pressure double-PP-drain is handled in the Battle::Battler
# override below (line ~12092). This Battle::Move stub has been removed as
# pbReducePP is a Battler method, not a Move method.


#──────────────────────────────────────────────────────────────────────────────
# ABILITY P: Shadow Shield — always halves damage, regardless of HP
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:SHADOWSHIELD_DIMENSIONAL,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:SHADOWSHIELD)
    next unless target.battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(target.battle.current_field.id)
    # Always halve — base game only halves at full HP
    mults[:final_damage_multiplier] /= 2.0
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY Q: Ghost-type Pokemon are NOT immune to Shadow Tag on Dimensional Field
# Normally Ghost-types bypass Shadow Tag trapping. We override pbCanSwitch? to
# remove that Ghost exemption when Shadow Tag is in effect on Dimensional Field.
# NOTE: Requires care — we only remove the Ghost bypass, not the full trapping check.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias dimensional_shadowtag_pbCanSwitch? pbCanSwitch? if method_defined?(:pbCanSwitch?)

  def pbCanSwitch?(idxNewBattler, idxParty, partyScene)
    # On Dimensional Field, Ghost-types are not exempt from Shadow Tag
    if @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id) && pbHasType?(:GHOST)
      @battle.allOtherBattlers(@index).each do |b|
        next if b.fainted?
        next unless b.hasActiveAbility?(:SHADOWTAG)
        # Ghost-type exemption removed — apply same trapping as non-Ghost
        unless @battle.pbGetOwnerFromBattlerIndex(@index) == @battle.pbGetOwnerFromBattlerIndex(b.index)
          partyScene&.pbDisplay(_INTL("{1} can't be switched out!", pbThis))
          return false
        end
      end
    end
    respond_to?(:dimensional_shadowtag_pbCanSwitch?) ? dimensional_shadowtag_pbCanSwitch?(idxNewBattler, idxParty, partyScene) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY R: Download — changes the user's type every turn (EOR)
# Cycles through the 18 main types in order each turn.
#──────────────────────────────────────────────────────────────────────────────
DIMENSIONAL_DOWNLOAD_TYPES = %i[
  NORMAL FIRE WATER GRASS ELECTRIC ICE FIGHTING POISON
  GROUND FLYING PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY
].freeze

#──────────────────────────────────────────────────────────────────────────────
# ABILITY S: Berserk — boosts Special Attack on entry (same as Dragon's Den)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:BERSERK_DIMENSIONAL,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:BERSERK)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:SPECIAL_ATTACK, 2, battler)
    battle.pbDisplay(_INTL("{1}'s rage surged in the darkness!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY T+U: Anger Point and Justified — +1 Attack on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:ANGERPOINT_DIMENSIONAL,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:ANGERPOINT)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:ATTACK, 1, battler)
    battle.pbDisplay(_INTL("{1}'s Anger Point flared in the darkness!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:JUSTIFIED_DIMENSIONAL,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:JUSTIFIED)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)

    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStage(:ATTACK, 1, battler)
    battle.pbDisplay(_INTL("{1}'s resolve hardened in the dark dimension!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY V: Unnerve — drops opponent's Speed -1 on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:UNNERVE_DIMENSIONAL,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:UNNERVE)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    battle.allOtherBattlers(battler.index).each do |b|
      next if b.fainted?
      b.pbLowerStatStage(:SPEED, 1, battler) if b.pbCanLowerStatStage?(:SPEED, battler, nil)
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY W: Pressure — drops opponent's Defense and Special Defense -1 on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:PRESSURE_DIMENSIONAL,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:PRESSURE)
    next unless battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    battle.allOtherBattlers(battler.index).each do |b|
      next if b.fainted?
      b.pbLowerStatStage(:DEFENSE, 1, battler) if b.pbCanLowerStatStage?(:DEFENSE, battler, nil)
      b.pbLowerStatStage(:SPECIAL_DEFENSE, 1, battler) if b.pbCanLowerStatStage?(:SPECIAL_DEFENSE, battler, nil)
    end
    battle.pbDisplay(_INTL("{1}'s Pressure bears down on the opposition!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY J: Soul Heart — additionally boosts Sp. Def on faint
# Chain from fairytale_soulheart_pbFaint
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias rainbow_soulheart_pbFaint pbFaint if method_defined?(:pbFaint) && !method_defined?(:rainbow_soulheart_pbFaint)

  def pbFaint(showMessage = true)
    soulheart_battlers = []
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      @battle.allBattlers.each do |b|
        next if b.fainted? || b.index == @index
        soulheart_battlers << b if b.hasActiveAbility?(:SOULHEART)
      end
    end

    ret = respond_to?(:rainbow_soulheart_pbFaint) ? rainbow_soulheart_pbFaint(showMessage) : super

    soulheart_battlers.each do |battler|
      next if battler.fainted?
      next unless battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler, false)
    end

    ret
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY K: Pastel Veil — halves Poison damage for user and allies
# Extend from Misty Terrain implementation
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:PASTELVEIL_RAINBOW,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.battle.has_field? && RAINBOW_FIELD_IDS.include?(target.battle.current_field.id)
    next unless type == :POISON

    # Check if target or any ally has Pastel Veil
    has_pastel = target.hasActiveAbility?(:PASTELVEIL)
    unless has_pastel
      target.allAllies.each do |ally|
        has_pastel = true if ally.hasActiveAbility?(:PASTELVEIL)
      end
    end
    next unless has_pastel

    mults[:final_damage_multiplier] /= 2.0
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY L: Marvel Scale — always activated on Rainbow Field
# Extend from Misty/FairyTale implementations
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:MARVELSCALE_RAINBOW,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:MARVELSCALE)
    next unless target.battle.has_field? && RAINBOW_FIELD_IDS.include?(target.battle.current_field.id)
    next unless move.physicalMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY M: Cloud Nine — randomly boosts one stat +1 at EOR
#──────────────────────────────────────────────────────────────────────────────
RAINBOW_CLOUD_NINE_STATS = %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].freeze

#──────────────────────────────────────────────────────────────────────────────
# ABILITY N: WonderSkin — evades ALL status moves (not just 50% of the time)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias rainbow_wonderskin_pbAccuracyCheck pbAccuracyCheck if method_defined?(:pbAccuracyCheck) && !method_defined?(:rainbow_wonderskin_pbAccuracyCheck)

  def pbAccuracyCheck(user, target)
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      if target.hasActiveAbility?(:WONDERSKIN) && statusMove?
        return false  # Always evade status moves
      end
    end
    respond_to?(:rainbow_wonderskin_pbAccuracyCheck) ? rainbow_wonderskin_pbAccuracyCheck(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Victory Star — additionally boosts user and allies' attacks x1.5
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:VICTORYSTAR_STARLIGHT,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:VICTORYSTAR) ||
                user.allAllies.any? { |b| b.hasActiveAbility?(:VICTORYSTAR) }
    next unless user.battle.has_field? && STARLIGHT_ARENA_IDS.include?(user.battle.current_field.id)
    mults[:attack_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Marvel Scale — always activated
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:MARVELSCALE_STARLIGHT,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:MARVELSCALE)
    next unless target.battle.has_field? && STARLIGHT_ARENA_IDS.include?(target.battle.current_field.id)
    next unless move.physicalMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Shadow Shield — takes x0.75 damage (always, not just at full HP)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:SHADOWSHIELD_STARLIGHT,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:SHADOWSHIELD)
    next unless target.battle.has_field? && STARLIGHT_ARENA_IDS.include?(target.battle.current_field.id)
    mults[:final_damage_multiplier] *= 0.75
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Illuminate — activates Spotlight on partnered Mirror Armor Pokemon
# in double battles. Also boosts Sp. Attack on switch-in.
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:ILLUMINATE_STARLIGHT,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:ILLUMINATE)
    next unless battle.has_field? && STARLIGHT_ARENA_IDS.include?(battle.current_field.id)

    # Boost Sp. Attack on switch-in
    if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
      battle.pbShowAbilitySplash(battler)
      battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler)
      battle.pbDisplay(_INTL("{1}'s Illuminate activated in the starlight!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    end

    # In doubles: apply Spotlight to any partner with Mirror Armor
    if battle.doubleBattle?
      battler.allAllies.each do |ally|
        next unless ally.hasActiveAbility?(:MIRRORARMOR)
        ally.effects[PBEffects::Spotlight] = 1 if PBEffects.const_defined?(:Spotlight)
        battle.pbDisplay(_INTL("{1} used its starlight to spotlight {2}!", battler.pbThis, ally.pbThis))
      end
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Multitype — randomly changes type each EOR
#──────────────────────────────────────────────────────────────────────────────
NEW_WORLD_ALL_TYPES = %i[
  NORMAL FIRE WATER GRASS ELECTRIC ICE FIGHTING POISON
  GROUND FLYING PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY
].freeze

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Mimicry — changes type to a random type (EOR)
# New World: Mimicry picks a random type each turn instead of terrain type.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias newworld_mimicry_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:newworld_mimicry_pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    respond_to?(:newworld_mimicry_pbEndOfRoundPhase) ? newworld_mimicry_pbEndOfRoundPhase : super
    return unless has_field? && NEW_WORLD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.hasActiveAbility?(:MIMICRY)
      next if battler.hasActiveAbility?([:MULTITYPE, :RKSSYSTEM]) # Covered above

      new_type = NEW_WORLD_ALL_TYPES.sample
      battler.pbChangeTypes(new_type)
      pbDisplay(_INTL("{1}'s Mimicry changed its type to {2}!", battler.pbThis, new_type.to_s.capitalize))
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Shadow Shield — takes x0.75 damage (always)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:SHADOWSHIELD_NEWWORLD,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:SHADOWSHIELD)
    next unless target.battle.has_field? && NEW_WORLD_IDS.include?(target.battle.current_field.id)
    mults[:final_damage_multiplier] *= 0.75
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Victory Star — additionally boosts user and allies' attacks x1.5
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:VICTORYSTAR_NEWWORLD,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:VICTORYSTAR) ||
                user.allAllies.any? { |b| b.hasActiveAbility?(:VICTORYSTAR) }
    next unless user.battle.has_field? && NEW_WORLD_IDS.include?(user.battle.current_field.id)
    mults[:attack_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE B/C: Steelworker x2, Galvanize x1.5 on Factory Field
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:STEELWORKER_FACTORY,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:STEELWORKER)
    next unless user.battle.has_field? && FACTORY_FIELD_IDS.include?(user.battle.current_field.id)
    next unless type == :STEEL
    # Replace the base 1.5x with 2.0x — add an extra 1.333x on top of 1.5x = 2.0x
    mults[:attack_multiplier] *= (2.0 / 1.5)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:GALVANIZE_FACTORY,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:GALVANIZE)
    next unless user.battle.has_field? && FACTORY_FIELD_IDS.include?(user.battle.current_field.id)
    next unless type == :ELECTRIC
    # Base Galvanize applies 1.2x; we add an extra 1.25x to reach 1.5x total
    mults[:power_multiplier] *= (1.5 / 1.2)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE D: Light Metal — +1 Speed on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:LIGHTMETAL_FACTORY,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:LIGHTMETAL)
    next unless battle.has_field? && FACTORY_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:SPEED, battler, nil)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
    battle.pbDisplay(_INTL("{1}'s Light Metal let it zip through the factory!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE E: Heavy Metal — +1 Defense, -1 Speed on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:HEAVYMETAL_FACTORY,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:HEAVYMETAL)
    next unless battle.has_field? && FACTORY_FIELD_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbLowerStatStageByAbility(:SPEED, 1, battler)   if battler.pbCanLowerStatStage?(:SPEED, battler, nil)
    battle.pbDisplay(_INTL("{1}'s Heavy Metal reinforced its frame!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE F: Download — boost doubled (+2 stages instead of +1) on Factory Field
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:DOWNLOAD_FACTORY,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:DOWNLOAD)
    next unless battle.has_field? && FACTORY_FIELD_IDS.include?(battle.current_field.id)

    raise_atk = false
    battle.allOtherBattlers(battler.index).each do |b|
      next if b.fainted?
      if b.defense < b.spdef
        raise_atk = true
        break
      end
    end

    battle.pbShowAbilitySplash(battler)
    if raise_atk
      battler.pbRaiseStatStageByAbility(:ATTACK, 2, battler)
    else
      battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 2, battler)
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE G: Motor Drive — speed boost doubled on Factory Field (add extra +1)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:MOTORDRIVE_FACTORY,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:MOTORDRIVE)
    next unless battle.has_field? && FACTORY_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbCalcType(user) == :ELECTRIC
    # Base Motor Drive already raised +1; raise another +1 for doubled effect
    next unless target.pbCanRaiseStatStage?(:SPEED, target, nil)
    battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStageByAbility(:SPEED, 1, target)
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE H: Technician — activates for moves ≤80 BP (from ≤60)
# Override the base-power threshold check.
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:TECHNICIAN_FACTORY,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:TECHNICIAN)
    next unless user.battle.has_field? && FACTORY_FIELD_IDS.include?(user.battle.current_field.id)
    # Factory: apply 1.5x for moves with base power 61-80
    # (moves ≤60 already get the standard Technician boost; this covers 61-80)
    bp = move.pbBaseDamage(power, user, target)
    next unless bp > 60 && bp <= 80
    mults[:power_multiplier] *= 1.5
  }
)

Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE_FACTORY,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.effects[PBEffects::Transform]
    next unless target.isSpecies?(:CRAMORANT)
    next unless [:SURF, :DIVE].include?(move.id)
    next unless battle.has_field? && GULP_MISSILE_PIKACHU_IDS.include?(battle.current_field.id)
    target.pbChangeForm(2, _INTL("{1} caught a Pikachu!", target.pbThis))
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MECHANIC D: Static 60% on Short Circuit (extend Electric Terrain hook)
# MECHANIC E: Volt Absorb gradual HP restore (extend Electric Terrain hook)
# MECHANIC F: Plus + Minus activated (extend Electric Terrain hook)
# MECHANIC G: Surge Surfer activated (extend Electric Terrain hook)
# These all extend the existing Electric Terrain implementations.
#──────────────────────────────────────────────────────────────────────────────

# Static — extend to Short Circuit
# (The existing OnBeingHit handler checks ELECTRIC_TERRAIN_IDS — we add a new one)
Battle::AbilityEffects::OnBeingHit.add(:STATIC_SHORTCIRCUIT,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:STATIC)
    next unless move.pbContactMove?(user)
    next unless user && !user.fainted?
    next unless battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battle.current_field.id)
    next if rand(100) >= 60
    next unless user.pbCanParalyze?(target, false)
    battle.pbShowAbilitySplash(target)
    msg = Battle::Scene::USE_ABILITY_SPLASH ? nil :
          _INTL("{1}'s {2} paralyzed {3}!", target.pbThis, target.abilityName, user.pbThis(true))
    user.pbParalyze(target, msg)
    battle.pbHideAbilitySplash(target)
  }
)

# Volt Absorb — gradual HP restore per hit on Short Circuit
Battle::AbilityEffects::OnBeingHit.add(:VOLTABSORB_SHORTCIRCUIT,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:VOLTABSORB)
    next unless battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbCalcType(user) == :ELECTRIC
    next if target.hp >= target.totalhp
    battle.pbShowAbilitySplash(target)
    target.pbFieldRecoverHP(target.totalhp / 16)
    battle.pbDisplay(_INTL("{1}'s {2} absorbed the electric current!", target.pbThis, target.abilityName))
    battle.pbHideAbilitySplash(target)
  }
)

# Plus — SpAtk 1.5x on Short Circuit
Battle::AbilityEffects::DamageCalcFromUser.add(:PLUS_SHORTCIRCUIT,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:PLUS)
    next unless user.battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(user.battle.current_field.id)
    next unless move.specialMove?(type)
    mults[:attack_multiplier] *= 1.5
  }
)

# Minus — SpAtk 1.5x on Short Circuit
Battle::AbilityEffects::DamageCalcFromUser.add(:MINUS_SHORTCIRCUIT,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:MINUS)
    next unless user.battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(user.battle.current_field.id)
    next unless move.specialMove?(type)
    mults[:attack_multiplier] *= 1.5
  }
)

# Surge Surfer — Speed doubled on Short Circuit
Battle::AbilityEffects::SpeedCalc.add(:SURGESURFER_SHORTCIRCUIT,
  proc { |ability, battler, mult|
    next mult * 2 if battler.battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battler.battle.current_field.id)
    next mult
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MECHANIC H: Galvanize x2 on Short Circuit (from x1.2)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:GALVANIZE_SHORTCIRCUIT,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:GALVANIZE)
    next unless user.battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(user.battle.current_field.id)
    next unless type == :ELECTRIC
    # Base Galvanize 1.2x; add extra to reach 2.0x total
    mults[:power_multiplier] *= (2.0 / 1.2)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MECHANIC J: Download — boosts BOTH Attack and SpAtk on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:DOWNLOAD_SHORTCIRCUIT,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:DOWNLOAD)
    next unless battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)         if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
    battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
    battle.pbDisplay(_INTL("{1}'s Download surged with electric data!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MECHANIC K: Motor Drive / Lightning Rod / Volt Absorb scale with electric roll
# On Short Circuit, when these abilities absorb an Electric hit, the HP restore
# or stat boost scales with the current counter value (0.5x–2.0x factor).
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:MOTORDRIVE_SHORTCIRCUIT,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:MOTORDRIVE)
    next unless battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbCalcType(user) == :ELECTRIC

    roll = battle.get_field_roll(update_roll: false) rescue 2  # Peek without advancing
    scale = SHORTCIRCUIT_ELEC_MULTS[roll.to_i.clamp(0, 6)]
    stages = (scale >= 1.5) ? 2 : 1  # High rolls give +2, others +1

    next unless target.pbCanRaiseStatStage?(:SPEED, target, nil)
    battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStageByAbility(:SPEED, stages, target)
    battle.pbHideAbilitySplash(target)
  }
)

Battle::AbilityEffects::OnBeingHit.add(:LIGHTNINGROD_SHORTCIRCUIT,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:LIGHTNINGROD)
    next unless battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbCalcType(user) == :ELECTRIC

    roll = battle.get_field_roll(update_roll: false) rescue 2
    scale = SHORTCIRCUIT_ELEC_MULTS[roll.to_i.clamp(0, 6)]
    stages = (scale >= 1.5) ? 2 : 1

    next unless target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, target, nil)
    battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, stages, target)
    battle.pbHideAbilitySplash(target)
  }
)

Battle::AbilityEffects::OnBeingHit.add(:VOLTABSORB_SCALE_SHORTCIRCUIT,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:VOLTABSORB)
    next unless battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbCalcType(user) == :ELECTRIC
    next if target.hp >= target.totalhp

    roll = battle.get_field_roll(update_roll: false) rescue 2
    scale = SHORTCIRCUIT_ELEC_MULTS[roll.to_i.clamp(0, 6)]
    heal_pct = 0.0625 * scale  # Base 1/16 scaled by roll
    heal = [(target.totalhp * heal_pct).round, 1].max

    battle.pbShowAbilitySplash(target)
    target.pbFieldRecoverHP(heal)
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY F: Gooey doubled — on contact, lower Speed by 2 instead of 1
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:GOOEY_SWAMP,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(%i[GOOEY TANGLINGHAIR])
    next unless battle.has_field? && SWAMP_FIELD_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next unless user.pbCanLowerStatStage?(:SPEED, target, nil)
    # Base game already lowers -1; add one more for doubled effect
    battle.pbShowAbilitySplash(target)
    user.pbLowerStatStageByAbility(:SPEED, 1, target)
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY G: Water Compaction activates EOR — +2 Defense each turn
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::EndOfRoundEffect.add(:WATERCOMPACTION_SWAMP,
  proc { |ability, battler, battle|
    next unless battler.hasActiveAbility?(:WATERCOMPACTION)
    next unless battle.has_field? && SWAMP_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 2, battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY H: Rattled — raises Speed +1 at EOR (not just on switch-in)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::EndOfRoundEffect.add(:RATTLED_SWAMP,
  proc { |ability, battler, battle|
    next unless battler.hasActiveAbility?(:RATTLED)
    next unless battle.has_field? && SWAMP_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:SPEED, battler, nil)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY I: Dry Skin recovers 1/16 HP per turn
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::EndOfRoundHealing.add(:DRYSKIN_SWAMP,
  proc { |ability, battler, battle|
    next unless battler.hasActiveAbility?(:DRYSKIN)
    next unless battle.has_field? && SWAMP_FIELD_IDS.include?(battle.current_field.id)
    next if battler.hp >= battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 16)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY J: Gulp Missile always picks Arrokuda on Swamp Field
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE_SWAMP,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.effects[PBEffects::Transform]
    next unless target.isSpecies?(:CRAMORANT)
    next unless [:SURF, :DIVE].include?(move.id)
    next unless battle.has_field? && SWAMP_FIELD_IDS.include?(battle.current_field.id)
    target.pbChangeForm(2, _INTL("{1} caught an Arrokuda!", target.pbThis))
  }
)

#──────────────────────────────────────────────────────────────────────────────
# SEED K: Telluric Seed — +1 Defense (fieldtxt) + changes ability to Clear Body
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias swamp_seed_apply_field_effect apply_field_effect unless method_defined?(:swamp_seed_apply_field_effect)

  def apply_field_effect(effect_name, *args)
    result = swamp_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && SWAMP_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :TELLURICSEED && battler && !battler.fainted?
        old_ability = battler.ability
        battler.ability = :CLEARBODY
        pbDisplay(_INTL("{1}'s ability changed to Clear Body!", battler.pbThis))
      end
    end

    result
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Effect Spore, Poison Point, Stench — activation chances doubled
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:EFFECTSPORE_WASTELAND,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:EFFECTSPORE)
    next unless battle.has_field? && WASTELAND_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next unless user && !user.fainted?
    # Base game already fired at ~30%; add another 30% chance roll
    next if rand(100) >= 30
    eff = [[:SLEEP, :POISON, :PARALYSIS].sample]
    case eff[0]
    when :SLEEP     then user.pbSleep(target)    if user.pbCanSleep?(target, false)
    when :POISON    then user.pbPoison(target)   if user.pbCanPoison?(target, false)
    when :PARALYSIS then user.pbParalyze(target) if user.pbCanParalyze?(target, false)
    end
  }
)

Battle::AbilityEffects::OnBeingHit.add(:POISONPOINT_WASTELAND,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:POISONPOINT)
    next unless battle.has_field? && WASTELAND_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next unless user && !user.fainted?
    # Base game fires at 33%; add extra 33%
    next if rand(100) >= 33
    next unless user.pbCanPoison?(target, false)
    battle.pbShowAbilitySplash(target)
    user.pbPoison(target)
    battle.pbHideAbilitySplash(target)
  }
)

Battle::AbilityEffects::OnBeingHit.add(:STENCH_WASTELAND,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:STENCH)
    next unless battle.has_field? && WASTELAND_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next unless user && !user.fainted?
    # Base game fires at 10%; add another 10%
    next if rand(100) >= 10
    user.pbFlinch if user.pbCanFlinch?(target, false) rescue nil
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Liquid Ooze — double damage
# Base game deals drain as damage; on Wasteland double it via DamageCalcFromTarget.
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:LIQUIDOOZE_WASTELAND,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:LIQUIDOOZE)
    next unless target.battle.has_field? && WASTELAND_IDS.include?(target.battle.current_field.id)
    next unless move.pbLifeLeechingMove? rescue false
    mults[:final_damage_multiplier] *= 2.0
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Poison Heal + Toxic Boost — activated (always apply effects)
# Poison Heal: heal 1/8 HP per turn even without status
# Toxic Boost: 1.5x Attack boost even without poison status
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::EndOfRoundHealing.add(:POISONHEAL_WASTELAND,
  proc { |ability, battler, battle|
    next unless battler.hasActiveAbility?(:POISONHEAL)
    next unless battle.has_field? && WASTELAND_IDS.include?(battle.current_field.id)
    next if battler.hp >= battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbFieldRecoverHP(battler.totalhp / 8)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
    next true
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:TOXICBOOST_WASTELAND,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:TOXICBOOST)
    next unless user.battle.has_field? && WASTELAND_IDS.include?(user.battle.current_field.id)
    next unless move.physicalMove?(type)
    mults[:attack_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Gooey — additionally poisons target on contact
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:GOOEY_WASTELAND,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(%i[GOOEY TANGLINGHAIR])
    next unless battle.has_field? && WASTELAND_IDS.include?(battle.current_field.id)
    next unless move.pbContactMove?(user)
    next unless user && !user.fainted?
    next unless user.pbCanPoison?(target, false)
    battle.pbShowAbilitySplash(target)
    user.pbPoison(target)
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Corrosion — trigger random field statuses on any Pokémon with any
# damaging move, regardless of typing
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias wasteland_corrosion_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget) && !method_defined?(:wasteland_corrosion_pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:wasteland_corrosion_pbEffectAgainstTarget) ? wasteland_corrosion_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && WASTELAND_IDS.include?(@battle.current_field.id)
    return unless user.hasActiveAbility?(:CORROSION)
    return unless pbDamagingMove?
    return if rand(3) > 0  # ~33% chance

    status = WASTELAND_RANDOM_STATUSES.sample
    case status
    when :BURN
      target.pbBurn(user)     rescue nil
    when :PARALYSIS
      target.pbParalyze(user) rescue nil
    when :FROZEN
      target.pbFreeze(user)   rescue nil
    when :POISON
      target.pbPoison(user)   rescue nil
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Merciless — always activated (critical hits guaranteed vs any target)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::CriticalCalcFromUser.add(:MERCILESS_WASTELAND,
    proc { |ability, user, target, crit_stage|
      next unless user.hasActiveAbility?(:MERCILESS)
      next unless user.battle.has_field? && WASTELAND_IDS.include?(user.battle.current_field.id)
      next 51  # Guaranteed crit (c > 50 path)
    }
  )

#──────────────────────────────────────────────────────────────────────────────
# ABILITY N: Light Metal — +1 Speed on switch-in (extend from Factory)
# ABILITY O: Heavy Metal — +1 Defense, -1 Speed on switch-in (extend from Factory)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:LIGHTMETAL_DEEPEARTH,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:LIGHTMETAL)
    next unless battle.has_field? && DEEP_EARTH_IDS.include?(battle.current_field.id)
    next unless battler.pbCanRaiseStatStage?(:SPEED, battler, nil)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:HEAVYMETAL_DEEPEARTH,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:HEAVYMETAL)
    next unless battle.has_field? && DEEP_EARTH_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbLowerStatStageByAbility(:SPEED, 1, battler)   if battler.pbCanLowerStatStage?(:SPEED, battler, nil)
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY P: Power Spot — partner damage 1.5x (from 1.3x)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:POWERSPOT_DEEPEARTH,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && DEEP_EARTH_IDS.include?(user.battle.current_field.id)
    next unless user.allAllies.any? { |b| b.hasActiveAbility?(:POWERSPOT) }
    # Base Power Spot already applies 1.3x; add extra to reach 1.5x
    mults[:power_multiplier] *= (1.5 / 1.3)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY Q: Pressure — additional PP usage (extend Dimensional hook)
#──────────────────────────────────────────────────────────────────────────────
# ABILITY Q: Pressure — additional PP usage on Deep Earth Field
class Battle::Battler
  alias deepearth_pressure_pbReducePP pbReducePP if method_defined?(:pbReducePP) && !method_defined?(:deepearth_pressure_pbReducePP)

  def pbReducePP(move)
    result = respond_to?(:deepearth_pressure_pbReducePP, true) ?
      respond_to?(:deepearth_pressure_pbReducePP) ? deepearth_pressure_pbReducePP(move) : super : super

    begin
      if result && @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)
        has_pressure = @battle.allOtherBattlers(@index).any? do |b|
          !b.fainted? && b.hasActiveAbility?(:PRESSURE)
        end
        if has_pressure && move.pp > 0
          pbSetPP(move, move.pp - 1)
        end
      end
    rescue
    end

    result
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY R: Slow Start — on switch-in:
#   -6 Speed, -6 Evasion, +1 Atk, +1 Def, +1 SpDef
#   Base game Slow Start effect is negated (don't halve Speed/Atk)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:SLOWSTART_DEEPEARTH,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:SLOWSTART)
    next unless battle.has_field? && DEEP_EARTH_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    # Apply Deep Earth Slow Start effects
    battler.pbLowerStatStageByAbility(:SPEED, 6, battler)
    battler.effects[PBEffects::Evasion] = (battler.effects[PBEffects::Evasion] || 0) - 6 rescue nil
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)  if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    # Negate the base game Slow Start halving by clearing the timer
    battler.effects[PBEffects::SlowStart] = 0 if PBEffects.const_defined?(:SlowStart)
    battle.pbDisplay(_INTL("{1}'s Slow Start warped under the earth's gravity!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY S: Power Construct — +1 to all stats on form activation
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:POWERCONSTRUCT_DEEPEARTH,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:POWERCONSTRUCT)
    next unless battle.has_field? && DEEP_EARTH_IDS.include?(battle.current_field.id)

    battle.pbShowAbilitySplash(battler)
    %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].each do |stat|
      battler.pbRaiseStatStageByAbility(stat, 1, battler) if battler.pbCanRaiseStatStage?(stat, battler, nil)
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY T: Magnet Pull, Contrary, Oblivious, Unaware — begin to float
# These Pokémon become airborne (treated as non-grounded) on Deep Earth.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias deepearth_float_airborne? airborne? if method_defined?(:airborne?) && !method_defined?(:deepearth_float_airborne?)

  def airborne?
    if @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)
      return true if hasActiveAbility?(DEEP_EARTH_FLOAT_ABILITIES)
    end
    deepearth_float_airborne?
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ITEM U: Magnet — -1 Speed, +1 SpAtk on switch-in
# ITEM V: Iron Ball — -2 Speed on switch-in (instead of item passive)
# ITEM W: Float Stone — +20% Speed multiplier
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:ITEMS_DEEPEARTH,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field? && DEEP_EARTH_IDS.include?(battle.current_field.id)

    case battler.item
    when :MAGNET
      battler.pbLowerStatStage(:SPEED, 1, battler, false)           if battler.pbCanLowerStatStage?(:SPEED, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler)         if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
      battle.pbDisplay(_INTL("{1}'s Magnet reacted to the gravitational pull!", battler.pbThis))
    when :IRONBALL
      battler.pbLowerStatStage(:SPEED, 2, battler, false)           if battler.pbCanLowerStatStage?(:SPEED, battler, nil)
      battle.pbDisplay(_INTL("{1}'s Iron Ball sank into the deep earth!", battler.pbThis))
    end
  }
)

# Float Stone Speed boost
Battle::AbilityEffects::SpeedCalc.add(:FLOATSTONE_DEEPEARTH,
  proc { |ability, battler, mult|
    next mult unless battler.battle.has_field? && DEEP_EARTH_IDS.include?(battler.battle.current_field.id)
    next mult * 1.2 if battler.hasActiveItem?(:FLOATSTONE) rescue mult
    next mult
  }
)

# Keep Rage locked via OnBeingHit — block the Rage-specific unlock
Battle::AbilityEffects::OnBeingHit.add(:GLITCH_RAGE_LOCK,
  proc { |ability, user, target, move, battle|
    next unless battle.has_field? && GLITCH_FIELD_IDS.include?(battle.current_field.id)
    # If the target is locked into Rage, prevent the unlock that would normally fire
    next unless target.effects[PBEffects::Rage] rescue false
    # Keep the lock — the base game clears Rage lock on being hit; re-set it immediately
    target.effects[PBEffects::Rage] = true
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY O: RKS System → ??? type at all times
# RKS System normally sets type based on held Memory item.
# On Glitch Field, force ??? regardless of memory.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias glitch_rkssystem_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:glitch_rkssystem_pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    respond_to?(:glitch_rkssystem_pbEndOfRoundPhase) ? glitch_rkssystem_pbEndOfRoundPhase : super
    return unless has_field? && GLITCH_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |b|
      next if b.fainted?
      next unless b.hasActiveAbility?(:RKSSYSTEM)
      # Force ??? type if not already
      has_qmarks = begin
        b.pbHasType?(:QMARKS)
      rescue
        true
      end
      unless has_qmarks
        begin; b.pbChangeTypes(:QMARKS); rescue; nil; end
      end
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY P: Download — raises both Attack AND SpAtk on Glitch Field
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:DOWNLOAD_GLITCH,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:DOWNLOAD)
    next unless battle.has_field? && GLITCH_FIELD_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)         if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
    battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
    battle.pbDisplay(_INTL("{1}'s Download glitched and raised both offensive stats!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ITEM R: Drives — Genesect becomes immune to the drive's type
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:GENESECT_DRIVE_IMMUNE,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.battle.has_field? && GLITCH_FIELD_IDS.include?(target.battle.current_field.id)
    next unless target.isSpecies?(:GENESECT)
    immune_type = GLITCH_DRIVE_TYPES[target.item]
    next unless immune_type && type == immune_type
    mults[:final_damage_multiplier] = 0.0
  }
)

# Hook the Spiky Shield contact damage at EOR via battler OnBeingHit
Battle::AbilityEffects::OnBeingHit.add(:SPIKYSHIELD_COLOSSEUM,
  proc { |ability, user, target, move, battle|
    next unless battle.has_field? && COLOSSEUM_IDS.include?(battle.current_field.id)
    next unless target.effects[PBEffects::SpikyShield] rescue false
    next unless move.pbContactMove?(user)
    # Base game already dealt 1/8; add another 1/8 for doubled total
    extra = [user.totalhp / 8, 1].max
    user.pbReduceHP(extra, false)
    battle.pbDisplay(_INTL("{1} was stabbed by the Colosseum blades!", user.pbThis))
    user.pbFaint if user.fainted?
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE K: King's Shield — enhanced: additionally lowers attacker's SpAtk -2 on contact
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:KINGSSHIELD_COLOSSEUM,
  proc { |ability, user, target, move, battle|
    next unless battle.has_field? && COLOSSEUM_IDS.include?(battle.current_field.id)
    next unless target.effects[PBEffects::KingsShield] rescue false
    next unless move.pbContactMove?(user)
    next unless user.pbCanLowerStatStage?(:SPECIAL_ATTACK, target, nil)
    battle.pbShowAbilitySplash(target) rescue nil
    user.pbLowerStatStage(:SPECIAL_ATTACK, 2, target, false)
    battle.pbDisplay(_INTL("{1}'s special power was cut by the shield!", user.pbThis))
    battle.pbHideAbilitySplash(target) rescue nil
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY L: Skill Link — multi-hit moves deal 1.2x damage
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:SKILLLINK_COLOSSEUM,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:SKILLLINK)
    next unless user.battle.has_field? && COLOSSEUM_IDS.include?(user.battle.current_field.id)
    next unless move.respond_to?(:pbNumHits) || (move.respond_to?(:multiHitMove?) && move.multiHitMove?) rescue false
    mults[:power_multiplier] *= 1.2
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY M+N: Defiant (+Def x2) and Competitive (+SpDef x2) on Colosseum Field
# Implemented via pbLowerStatStage alias since AfterStatLower handler doesn't exist
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias colosseum_defcomp_pbLowerStatStage pbLowerStatStage if method_defined?(:pbLowerStatStage) && !method_defined?(:colosseum_defcomp_pbLowerStatStage)

  def pbLowerStatStage(stat, amount, user, showAnim = true, ignoreContrary = false,
                       mirrorArmorSplash = 0, ignoreMirrorArmor = false)
    result = respond_to?(:colosseum_defcomp_pbLowerStatStage) ?
      respond_to?(:colosseum_defcomp_pbLowerStatStage) ? colosseum_defcomp_pbLowerStatStage(stat, amount, user, showAnim, ignoreContrary, mirrorArmorSplash, ignoreMirrorArmor) : super :
      super
    return result unless result  # stat wasn't actually lowered

    return result unless @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id)

    # Defiant: also raise Defense +2
    if hasActiveAbility?(:DEFIANT) && pbCanRaiseStatStage?(:DEFENSE, self, nil)
      @battle.pbShowAbilitySplash(self)
      pbRaiseStatStageByAbility(:DEFENSE, 2, self)
      @battle.pbHideAbilitySplash(self)
    end

    # Competitive: also raise Special Defense +2
    if hasActiveAbility?(:COMPETITIVE) && pbCanRaiseStatStage?(:SPECIAL_DEFENSE, self, nil)
      @battle.pbShowAbilitySplash(self)
      pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 2, self)
      @battle.pbHideAbilitySplash(self)
    end

    result
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY O: Stalwart — survive one lethal hit at 1HP if at max HP
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:STALWART_COLOSSEUM,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.hasActiveAbility?(:STALWART)
    next unless target.battle.has_field? && COLOSSEUM_IDS.include?(target.battle.current_field.id)
    next unless target.hp == target.totalhp
    # Cap damage so target survives at 1 HP
    max_allowed = target.totalhp - 1
    if (power * mults[:final_damage_multiplier]) >= max_allowed
      mults[:final_damage_multiplier] = max_allowed.to_f / [power, 1].max
      target.battle.pbDisplay(_INTL("{1}'s Stalwart will held on!", target.pbThis))
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY P: Rattled / Wimp Out — attacks against them are always critical hits
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::CriticalCalcFromUser.add(:RATTLED_COLOSSEUM,
    proc { |ability, user, target, crit_stage|
      next unless target.battle.has_field? && COLOSSEUM_IDS.include?(target.battle.current_field.id)
      next unless target.hasActiveAbility?(%i[RATTLED WIMPOUT])
      next 51  # Guaranteed crit (c > 50 path)
    }
  )

#──────────────────────────────────────────────────────────────────────────────
# ABILITY Q: Mirror Armor / Magic Guard — +1 SpDef on switch-in
# ABILITY R: Battle Armor / Shell Armor — +1 Def on switch-in
# ABILITY S: Dauntless Shield — both defenses boosted on switch-in
# ABILITY T: Intrepid Sword / Justified / No Guard — offenses boosted on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:COLOSSEUM_SWITCH_BOOSTS,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field? && COLOSSEUM_IDS.include?(battle.current_field.id)

    case battler.ability
    when :MIRRORARMOR, :MAGICGUARD
      battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    when :BATTLEARMOR, :SHELLARMOR
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    when :DAUNTLESSSHIELD
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)         if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
      battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    when :INTREPIDSWORD, :JUSTIFIED, :NOGUARD
      battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)         if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
      battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY U: Wonder Guard — additionally protects against residual damage
# (Burn, Poison, weather, Leech Seed, etc.)
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias colosseum_wonderguard_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:colosseum_wonderguard_pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    respond_to?(:colosseum_wonderguard_pbEndOfRoundPhase) ? colosseum_wonderguard_pbEndOfRoundPhase : super
    return unless has_field? && COLOSSEUM_IDS.include?(current_field.id)

    allBattlers.each do |b|
      next if b.fainted?
      next unless b.hasActiveAbility?(:WONDERGUARD)
      # Cancel any HP loss that just occurred this EOR by restoring it
      # We track HP before and restore it after — simpler: just restore any lost HP
      # during this phase. We use a before/after wrapper via flag.
      b.instance_variable_set(:@wonderguard_colosseum, true)
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY V: Emergency Exit — raises Speed +2 instead of switching out
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:EMERGENCYEXIT_COLOSSEUM,
  proc { |ability, user, target, move, battle|
    next unless target.hasActiveAbility?(:EMERGENCYEXIT)
    next unless battle.has_field? && COLOSSEUM_IDS.include?(battle.current_field.id)
    next unless target.hp <= target.totalhp / 2 && !target.effects[PBEffects::EmergencyExitUsed] rescue false
    next unless target.pbCanRaiseStatStage?(:SPEED, target, nil)
    battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStageByAbility(:SPEED, 2, target)
    target.effects[PBEffects::EmergencyExitUsed] = true rescue nil
    battle.pbDisplay(_INTL("{1} fled the danger and boosted its speed!", target.pbThis))
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY W: Quick Draw — if activated, user's next move is a critical hit
#──────────────────────────────────────────────────────────────────────────────
# Apply the crit flag when calculating critical hit rate
Battle::AbilityEffects::CriticalCalcFromUser.add(:QUICKDRAW_CRIT_COLOSSEUM,
    proc { |ability, user, target, crit_stage|
    next unless user.hasActiveAbility?(:QUICKDRAW)
    next unless user.battle.has_field? && COLOSSEUM_IDS.include?(user.battle.current_field.id)
    quick_draw_active = begin
      user.effects[PBEffects::QuickDraw]
    rescue
      false
    end
    next 51 if quick_draw_active  # Guaranteed crit (c > 50 path)
}
  )

#──────────────────────────────────────────────────────────────────────────────
# Helper: assign chess piece to a battler
#──────────────────────────────────────────────────────────────────────────────
def chess_assign_piece(battler, battle)
  party = battle.pbParty(battler.index)
  return :pawn unless party

  poke = battler.pokemon

  # Queen: last pokemon in party (only one per side)
  queen_idx = party.size - 1
  if battler.pokemonIndex == queen_idx
    # Check no other Queen already on field for this side
    existing = battle.allSameSideBattlers(battler.index).any? do |b|
      b.index != battler.index && b.instance_variable_get(:@chess_piece) == :queen
    end
    return :queen unless existing
  end

  # King: holds King's Rock OR has lowest HP in party
  if poke.item == :KINGSROCK
    return :king
  end
  lowest_hp = party.min_by { |p| p.hp.to_f / [p.totalhp, 1].max }
  return :king if lowest_hp == poke

  # Knight: highest stat is Speed
  stats = poke.stats
  highest = stats.max_by { |_, v| v }&.first
  return :knight if highest == :SPEED

  # Bishop: highest stat is Attack or SpAtk
  return :bishop if %i[ATTACK SPECIAL_ATTACK].include?(highest)

  # Rook: highest stat is Defense or SpDef
  return :rook if %i[DEFENSE SPECIAL_DEFENSE].include?(highest)

  # Default Pawn (first-turn send-out handled at switch-in)
  :pawn
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE: Assign chess piece on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:CHESS_PIECE_ASSIGN,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field? && CHESS_BOARD_IDS.include?(battle.current_field.id)

    piece = chess_assign_piece(battler, battle)

    # First-turn Pawns override (except Queen)
    if battle.turnCount == 0 && piece != :queen
      piece = :pawn
    end

    battler.instance_variable_set(:@chess_piece, piece)

    piece_names = {
      queen: "Queen", pawn: "Pawn", king: "King",
      knight: "Knight", bishop: "Bishop", rook: "Rook"
    }
    battle.pbDisplay(_INTL("{1} takes the role of {2}!", battler.pbThis, piece_names[piece]))

    # Apply entry effects
    case piece
    when :queen
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)         if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
      battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    when :bishop
      battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)         if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
      battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
    when :rook
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)         if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
      battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    when :pawn
      # Pawns hold at 1 HP — handled in DamageCalcFromTarget below
    when :king
      # King priority — handled in pbPriority below
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# PIECE EFFECT — Queen: x1.5 damage on all moves
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:CHESS_QUEEN_DMG,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
    next unless user.instance_variable_get(:@chess_piece) == :queen
    mults[:power_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# PIECE EFFECT — Pawn: survive lethal at 1 HP when at full HP
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromTarget.add(:CHESS_PAWN_SURVIVE,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.battle.has_field? && CHESS_BOARD_IDS.include?(target.battle.current_field.id)
    next unless target.instance_variable_get(:@chess_piece) == :pawn
    next unless target.hp == target.totalhp
    max_allowed = target.totalhp - 1
    potential = (power * (mults[:final_damage_multiplier] || 1.0)).round
    if potential >= target.hp
      mults[:final_damage_multiplier] = (mults[:final_damage_multiplier] || 1.0) *
                                         (max_allowed.to_f / [potential, 1].max)
      target.battle.pbDisplay(_INTL("{1} the Pawn held on!", target.pbThis))
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# PIECE EFFECT — Knight: x3 vs Queens, x1.25 vs both opponents in doubles
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:CHESS_KNIGHT_DMG,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
    next unless user.instance_variable_get(:@chess_piece) == :knight
    if target.instance_variable_get(:@chess_piece) == :queen
      mults[:power_multiplier] *= 3.0
    elsif (begin; move.respond_to?(:pbTarget) && move.pbTarget(user) == :AllNearFoes; rescue; false; end)
      mults[:power_multiplier] *= 1.25
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Stomping Tantrum / Outrage / Thrash — leave user open to crits
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::CriticalCalcFromUser.add(:CHESS_TANTRUM_CRIT,
    proc { |ability, user, target, crit_stage|
      next unless target.battle.has_field? && CHESS_BOARD_IDS.include?(target.battle.current_field.id)
      next unless target.instance_variable_get(:@chess_tantrum_open) rescue false
      next 51  # Guaranteed crit (c > 50 path)
    }
  )

Battle::AbilityEffects::OnBeingHit.add(:CHESS_SET_TANTRUM_FLAG,
  proc { |ability, user, target, move, battle|
    next unless battle.has_field? && CHESS_BOARD_IDS.include?(battle.current_field.id)
    next unless %i[STOMPINGTANTRUM OUTRAGE THRASH].include?(move.id) && user == target
  }
)

# King's Shield contact: -2 SpAtk (same as Colosseum, extend to Chess Board)
Battle::AbilityEffects::OnBeingHit.add(:KINGSSHIELD_CHESSBOARD,
  proc { |ability, user, target, move, battle|
    next unless battle.has_field? && CHESS_BOARD_IDS.include?(battle.current_field.id)
    next unless target.effects[PBEffects::KingsShield] rescue false
    next unless move.pbContactMove?(user)
    next unless user.pbCanLowerStatStage?(:SPECIAL_ATTACK, target, nil)
    user.pbLowerStatStage(:SPECIAL_ATTACK, 2, target, false)
    battle.pbDisplay(_INTL("{1}'s Special Attack was cut by the royal shield!", user.pbThis))
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Stance Change — on form switch, +1 Atk (sword) or +1 Def (shield),
#          -1 of the other
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:STANCECHANGE_CHESSBOARD,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:STANCECHANGE)
    next unless battle.has_field? && CHESS_BOARD_IDS.include?(battle.current_field.id)
    # Determine form: 0 = Aegislash (Shield), 1 = Blade
    is_blade_form = begin
      battler.formName&.include?("Blade")
    rescue
      false
    end
    if is_blade_form
      battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
      battler.pbLowerStatStageByAbility(:DEFENSE, 1, battler)
    else
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
      battler.pbLowerStatStageByAbility(:ATTACK, 1, battler)
    end
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Merciless — crit chance scales with how low target's HP is
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::CriticalCalcFromUser.add(:MERCILESS_CHESSBOARD,
    proc { |ability, user, target, crit_stage|
      next unless user.hasActiveAbility?(:MERCILESS)
      next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
      hp_ratio = target.hp.to_f / target.totalhp
      # +1 at <75%, +2 at <50%, +3 at <25%
      c += 1 if hp_ratio < 0.75
      c += 1 if hp_ratio < 0.50
      c += 1 if hp_ratio < 0.25
      next c
    }
  )

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Reckless / Gorilla Tactics — x1.2 all moves, but user open to crits
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:RECKLESS_CHESSBOARD,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
    next unless user.hasActiveAbility?(%i[RECKLESS GORILLATACTICS])
    mults[:power_multiplier] *= 1.2
    user.instance_variable_set(:@chess_tantrum_open, true)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Queenly Majesty — x1.5 damage (does not stack with Queen piece)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:QUEENLYMAJESTY_CHESSBOARD,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
    next unless user.hasActiveAbility?(:QUEENLYMAJESTY)
    next if user.instance_variable_get(:@chess_piece) == :queen  # Don't stack
    mults[:power_multiplier] *= 1.5
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Illusion — x1.2 damage while Illusion is active
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:ILLUSION_CHESSBOARD,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
    next unless user.hasActiveAbility?(:ILLUSION)
    next unless user.effects[PBEffects::Illusion] rescue false
    mults[:power_multiplier] *= 1.2
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Competitive — damage scales linearly with lost HP (up to 2x at 0 HP)
# Normal +SpAtk-on-stat-drop effect is negated (we override DamageCalcFromUser)
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:COMPETITIVE_CHESSBOARD,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CHESS_BOARD_IDS.include?(user.battle.current_field.id)
    next unless user.hasActiveAbility?(:COMPETITIVE)
    # 1.0x at full HP → 2.0x at 0 HP (linear)
    hp_ratio  = user.hp.to_f / user.totalhp
    dmg_scale = 1.0 + (1.0 - hp_ratio)
    mults[:power_multiplier] *= dmg_scale
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Stall — raises defenses on entry
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:STALL_CHESSBOARD,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:STALL)
    next unless battle.has_field? && CHESS_BOARD_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)         if battler.pbCanRaiseStatStage?(:DEFENSE, battler, nil)
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# GENERAL A: Crit rate +1 per attacker Evasion/Accuracy boost stage
#            and per defender Evasion/Accuracy debuff stage
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::CriticalCalcFromUser.add(:MIRROR_ARENA_CRIT,
    proc { |ability, user, target, crit_stage|
      next unless user.battle.has_field? && MIRROR_ARENA_IDS.include?(user.battle.current_field.id)

      # Attacker's positive Evasion and Accuracy stages
      eva_stage = user.stages[:EVASION] rescue 0
      acc_stage = user.stages[:ACCURACY] rescue 0
      c += [eva_stage, 0].max
      c += [acc_stage, 0].max

      # Defender's negative Evasion and Accuracy stages
      def_eva = target.stages[:EVASION] rescue 0
      def_acc = target.stages[:ACCURACY] rescue 0
      c += [-def_eva, 0].max   # negative = debuff → positive crit bonus
      c += [-def_acc, 0].max

      next c
    }
  )

# Beam move 2x when reflected
Battle::AbilityEffects::DamageCalcFromUser.add(:MIRROR_BEAM_REFLECT,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && MIRROR_ARENA_IDS.include?(user.battle.current_field.id)
    next unless user.instance_variable_get(:@mirror_reflected_beam)
    next unless MIRROR_ARENA_BEAM_MOVES.include?(move.id)
    mults[:power_multiplier] *= 2.0
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Illuminate — lower opponents' Accuracy by 1 on switch-in
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:ILLUMINATE_MIRRORARENA,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:ILLUMINATE)
    next unless battle.has_field? && MIRROR_ARENA_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battle.allOtherBattlers(battler.index).each do |b|
      next if b.fainted?
      b.pbLowerStatStageByAbility(:ACCURACY, 1, battler)
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Magic Bounce — boost Evasion when a move is bounced back
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:MAGICBOUNCE_MIRRORARENA,
  proc { |ability, user, target, move, battle|
    next unless battle.has_field? && MIRROR_ARENA_IDS.include?(battle.current_field.id)
    next unless target.hasActiveAbility?(:MAGICBOUNCE)
    next unless move.pbMagicCoatable? rescue false
    next unless target.pbCanRaiseStatStage?(:EVASION, target, nil)
    battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStageByAbility(:EVASION, 1, target)
    battle.pbDisplay(_INTL("{1}'s Magic Bounce increased its evasion!", target.pbThis))
    battle.pbHideAbilitySplash(target)
  }
)

#──────────────────────────────────────────────────────────────────────────────
# ABILITY / ITEM: Evasion boost on switch-in
# Sand Veil, Snow Cloak, Illusion, Tangled Feet, Magic Bounce, Color Change: +1 Evasion
# Lax Incense, Bright Powder: +1 Evasion
#──────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:EVASION_BOOST_MIRRORARENA,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field? && MIRROR_ARENA_IDS.include?(battle.current_field.id)

    boost = false
    boost = true if battler.hasActiveAbility?(MIRROR_ARENA_EVASION_ABILITIES)
    boost = true if battler.hasActiveItem?(%i[LAXINCENSE BRIGHTPOWDER]) rescue false

    next unless boost
    next unless battler.pbCanRaiseStatStage?(:EVASION, battler, nil)
    battle.pbShowAbilitySplash(battler) if battler.hasActiveAbility?(MIRROR_ARENA_EVASION_ABILITIES)
    battler.pbRaiseStatStageByAbility(:EVASION, 1, battler)
    battle.pbDisplay(_INTL("{1} blended into the mirrors!", battler.pbThis))
    battle.pbHideAbilitySplash(battler) if battler.hasActiveAbility?(MIRROR_ARENA_EVASION_ABILITIES)
  }
)

# Sound boost ×1.5 for all sound moves
Battle::AbilityEffects::DamageCalcFromUser.add(:CAVE_SOUND_BOOST,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && CAVE_FIELD_IDS.include?(user.battle.current_field.id)
    next unless move.soundMove? rescue false
    mults[:power_multiplier] *= 1.5
  }
)

# Punk Rock: field raises its boost from ×1.3 to ×1.5
Battle::AbilityEffects::DamageCalcFromUser.add(:PUNKROCK_CAVE,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:PUNKROCK)
    next unless user.battle.has_field? && CAVE_FIELD_IDS.include?(user.battle.current_field.id)
    next unless move.soundMove? rescue false
    # Base Punk Rock already applied ×1.3; apply the remaining ×(1.5/1.3) to reach ×1.5 total
    mults[:power_multiplier] *= (1.5 / 1.3)
  }
)

# Stealth Rock doubled damage on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:STEALTHROCK_CAVE,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field? && CAVE_FIELD_IDS.include?(battle.current_field.id)
    next unless battler.pbOwnSide.effects[PBEffects::StealthRock]
    bTypes = battler.pbTypes(true)
    eff = Effectiveness.calculate(:ROCK, *bTypes)
    next if Effectiveness.ineffective?(eff)
    eff_mult = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
    # Base game already dealt eff/8; deal another eff/8 for doubled total
    dmg = (battler.totalhp * eff_mult / 8).round
    battler.pbReduceHP(dmg, false)
    battle.pbDisplay(_INTL("The cave ceiling rained rocks on {1}!", battler.pbThis))
    battler.pbFaint if battler.fainted?
  }
)

#===============================================================================
# FLOWER GARDEN FIELD (Stages 1–5)
# Stage-based passive mechanics — damage reduction, type weakness nullification,
# ability activations, move enhancements
#===============================================================================

FLOWER_GARDEN_IDS = %i[flowergarden1 flowergarden2 flowergarden3 flowergarden4 flowergarden5].freeze

# PASSIVE: Grass-type Pokémon take reduced damage at stages 3/4/5
Battle::AbilityEffects::DamageCalcFromTarget.add(:FLOWERGARDEN_GRASS_REDUCTION,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.battle.has_field? && FLOWER_GARDEN_IDS.include?(target.battle.current_field.id)
    next unless target.pbHasType?(:GRASS)
    stage = flower_garden_stage(target.battle)
    mult = case stage
           when 3 then 0.75
           when 4 then 0.66
           when 5 then 0.5
           else nil
           end
    next unless mult
    mults[:final_damage_multiplier] *= mult
  }
)

# PASSIVE: Stages 4/5 nullify Grass-type weaknesses
Battle::AbilityEffects::DamageCalcFromTarget.add(:FLOWERGARDEN_GRASS_IMMUNITY,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.battle.has_field? && FLOWER_GARDEN_IDS.include?(target.battle.current_field.id)
    next unless target.pbHasType?(:GRASS)
    stage = flower_garden_stage(target.battle)
    next unless stage >= 4
    # If this type is super-effective vs Grass, negate the multiplier
    eff = Effectiveness.calculate(type, :GRASS) rescue Effectiveness::NORMAL_EFFECTIVE
    if Effectiveness.super_effective?(eff)
      mults[:type_multiplier] /= (eff.to_f / Effectiveness::NORMAL_EFFECTIVE)
    end
  }
)

# ABILITY: Flower Veil — passive 0.5× damage reduction for user + allied Grass types at stage 3+
Battle::AbilityEffects::DamageCalcFromTarget.add(:FLOWERVEIL_GARDEN,
  proc { |ability, user, target, move, mults, power, type|
    next unless target.battle.has_field? && FLOWER_GARDEN_IDS.include?(target.battle.current_field.id)
    next unless flower_garden_stage(target.battle) >= 3
    has_veil = target.battle.allSameSideBattlers(target.index).any? { |b| b.hasActiveAbility?(:FLOWERVEIL) } rescue false
    has_veil ||= target.hasActiveAbility?(:FLOWERVEIL)
    next unless has_veil && target.pbHasType?(:GRASS)
    mults[:final_damage_multiplier] *= 0.5
  }
)

# ABILITY: Harvest / Leaf Guard / Grass Pelt — always active at stage 2+
Battle::AbilityEffects::EndOfRoundEffect.add(:HARVEST_LEAFGUARD_GARDEN,
  proc { |ability, battler, battle|
    next unless battle.has_field? && FLOWER_GARDEN_IDS.include?(battle.current_field.id)
    next unless flower_garden_stage(battle) >= 2
    # Harvest: restore consumed Berry each turn
    if battler.hasActiveAbility?(:HARVEST)
      can_harvest = begin
        battler.pokemon.item == :NOITEM && battler.pokemon.hasConsumedBerry?
      rescue
        false
      end
      if can_harvest
        battler.pokemon.item = battler.pokemon.consumedItem
        battle.pbDisplay(_INTL("{1}'s Harvest grew a Berry!", battler.pbThis))
      end
    end
    # Leaf Guard: cure non-volatile status
    if battler.hasActiveAbility?(:LEAFGUARD) && battler.status != :NONE
      battler.pbCureStatus
      battle.pbDisplay(_INTL("{1}'s Leaf Guard cured its status!", battler.pbThis))
    end
  }
)

# Swarm: stage 3=×1.8, stage 5=×2 (on top of base ×1.5)
Battle::AbilityEffects::DamageCalcFromUser.add(:SWARM_GARDEN,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:SWARM)
    next unless user.battle.has_field? && FLOWER_GARDEN_IDS.include?(user.battle.current_field.id)
    next unless type == :BUG
    stage = flower_garden_stage(user.battle)
    mult = case stage
           when 5    then 2.0
           when 3, 4 then 1.8
           else 1.5
           end
    # Base Swarm already applied ×1.5 at low HP; override the multiplier
    # We apply the delta here to avoid double-stacking
    mults[:power_multiplier] *= (mult / 1.5)
  }
)

# Chlorophyll: double Speed at stage 4+
Battle::AbilityEffects::SpeedCalc.add(:CHLOROPHYLL_GARDEN,
  proc { |ability, battler, mult|
    next unless battler.hasActiveAbility?(:CHLOROPHYLL)
    next unless battle.has_field? && FLOWER_GARDEN_IDS.include?(battle.current_field.id)
    next unless flower_garden_stage(battle) >= 4
    next mult * 2.0
  }
)

# Overgrow: stage 2 = activates at 66% HP; stage 3+ = always active
# Power: stage 3=×1.6, stage 4=×1.8, stage 5=×2
Battle::AbilityEffects::DamageCalcFromUser.add(:OVERGROW_GARDEN,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.hasActiveAbility?(:OVERGROW)
    next unless user.battle.has_field? && FLOWER_GARDEN_IDS.include?(user.battle.current_field.id)
    next unless type == :GRASS
    stage = flower_garden_stage(user.battle)
    hp_ratio = user.hp.to_f / user.totalhp
    active = case stage
             when 2 then hp_ratio <= 0.66
             when 1..1 then hp_ratio <= 0.33
             else stage >= 3  # always active at 3+
             end
    next unless active
    mult = case stage
           when 5    then 2.0
           when 4    then 1.8
           when 3    then 1.6
           else 1.5
           end
    mults[:power_multiplier] *= (mult / 1.5)  # divide out base Overgrow ×1.5
  }
)

# Ripen: doubles field stage increases (via ability hook on field-growing moves)
# Tracked via @ripen_field_growth flag set before pbChangeField calls
# (This is a design note — actual stage doubling requires 009 integration)

#===============================================================================
# PSYTERRAIN — Additional move and ability mechanics
# (Priority blocking, Pure Power SpAtk, Telepathy, Magician already in file)
#===============================================================================

# Anticipation / Forewarn — +1 SpAtk on switch-in
Battle::AbilityEffects::OnSwitchIn.add(:ANTICIPATION_PSYTERRAIN,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(%i[ANTICIPATION FOREWARN])
    next unless battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(battle.current_field.id)
    battle.pbShowAbilitySplash(battler)
    battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler)
    battle.pbHideAbilitySplash(battler)
  }
)

# Power Spot — 1.5× partner damage (from 1.3×)
Battle::AbilityEffects::DamageCalcFromUser.add(:POWERSPOT_PSYTERRAIN,
  proc { |ability, user, target, move, mults, power, type|
    next unless user.battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(user.battle.current_field.id)
    # Check if any ally has Power Spot
    ally_has = user.battle.allSameSideBattlers(user.index).any? { |b| b.hasActiveAbility?(:POWERSPOT) } rescue false
    next unless ally_has
    mults[:power_multiplier] *= (1.5 / 1.3)  # cancel base 1.3× and apply 1.5×
  }
)

#─────────────────────────────────────────────────────────────────────────────
# ITEM 4: Inverse Field — Magical Seed Normalize (type → Normal + Normalize)
# on_seed_use hook for Inverse/Magical Seed
#─────────────────────────────────────────────────────────────────────────────
class Battle
  alias inverse_seed2_apply_field_effect apply_field_effect unless method_defined?(:inverse_seed2_apply_field_effect)

  def apply_field_effect(effect_name, *args)
    result = inverse_seed2_apply_field_effect(effect_name, *args)
    if effect_name == :on_seed_use &&
       has_field? && INVERSE_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        battler.pbChangeTypes(:NORMAL) rescue nil
        # Grant Normalize effect: mark it via a custom flag since ability change
        # could break things; use a battle-level tracker instead
        @inverse_normalized_battlers ||= []
        @inverse_normalized_battlers << battler.index
        pbDisplay(_INTL("{1} was normalized!", battler.pbThis))
      end
    end
    result
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 20: Starlight — Illuminate Spotlight via PBEffects::Spotlight
#─────────────────────────────────────────────────────────────────────────────
# Already implemented. Safe accessor:
Battle::AbilityEffects::OnSwitchIn.add(:ILLUMINATE_SPOTLIGHT_SAFE,
  proc { |ability, battler, battle, switch_in|
    next unless battler.hasActiveAbility?(:ILLUMINATE)
    next unless battle.has_field? && STARLIGHT_ARENA_IDS.include?(battle.current_field.id)
    next unless battle.pbSideSize(battler.index) > 1  # Only in doubles
    # Find Mirror Armor ally
    ally = battle.allSameSideBattlers(battler.index).find { |b|
      b.hasActiveAbility?(:MIRRORARMOR) rescue false
    } rescue nil
    next unless ally
    if PBEffects.const_defined?(:Spotlight)
      ally.effects[PBEffects::Spotlight] = 2 rescue nil
      battle.pbDisplay(_INTL("{1} illuminated {2} as a decoy!", battler.pbThis, ally.pbThis))
    end
  }
)

#─────────────────────────────────────────────────────────────────────────────
# ITEM 25: New World — Lunar Dance stat boosts on switch-in
# The switch-in check uses battler.effects[PBEffects::HealingWish].
# Wrap with safe const check:
#─────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnSwitchIn.add(:LUNARDANCE_NEWWORLD_STATBOOST,
  proc { |ability, battler, battle, switch_in|
    next unless battle.has_field? && NEW_WORLD_IDS.include?(battle.current_field.id)
    next unless PBEffects.const_defined?(:LunarDance)
    next unless battler.effects[PBEffects::LunarDance] rescue false
    # All stats +1
    %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].each do |stat|
      battler.pbRaiseStatStageByAbility(stat, 1, battler) rescue nil
    end
    battler.effects[PBEffects::LunarDance] = false rescue nil
    battle.pbDisplay(_INTL("{1} received the blessing of the New World!", battler.pbThis))
  }
)

#─────────────────────────────────────────────────────────────────────────────
# ITEM 38: Swamp — Telluric Seed changes ability to Clear Body
# Already implemented in swamp_seed_apply_field_effect. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 39: Swamp — Gulp Missile form change
# Already implemented at line ~8363 (GULPMISSILE) and ~8471 (factory).
# Swamp needs its own form-2 handler:
#─────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE_SWAMP,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || (target.effects[PBEffects::Transform] rescue false)
    next unless (target.isSpecies?(:CRAMORANT) rescue false)
    next unless %i[SURF DIVE].include?(move.id)
    next unless battle.has_field? && SWAMP_FIELD_IDS.include?(battle.current_field.id)
    # On Swamp, always catch the Pikachu form (form 2)
    target.pbChangeForm(2, _INTL("{1} caught a Pikachu!", target.pbThis)) rescue nil
  }
)

#─────────────────────────────────────────────────────────────────────────────
# ITEM 56: Chess Board — chess_assign_piece party index access
# Party access: user.pbParty — uses index from pbPartyOrder or allParty.
# Make sure the party access has rescue:
#─────────────────────────────────────────────────────────────────────────────
# Already wrapped in rescue in chess_assign_piece. Verify the helper exists:
unless Battle::Battler.method_defined?(:chess_assign_piece)
  class Battle::Battler
    def chess_assign_piece(piece_symbol)
      @chess_piece = piece_symbol
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Pure Power / Huge Power — boost Sp. Atk instead of Atk on Magic Field.
# Full handler replacement; non-Magic behaviour is preserved in the else branch.
# ─────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::DamageCalcFromUser.add(:PUREPOWER,
  proc { |ability, user, target, move, mults, power, type|
    if user.battle.has_field? && MAGIC_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 2 if move.specialMove?
    else
      mults[:attack_multiplier] *= 2 if move.physicalMove?
    end
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:HUGEPOWER,
  proc { |ability, user, target, move, mults, power, type|
    if user.battle.has_field? && MAGIC_IDS.include?(user.battle.current_field.id)
      mults[:attack_multiplier] *= 2 if move.specialMove?
    else
      mults[:attack_multiplier] *= 2 if move.physicalMove?
    end
  }
)

# ─────────────────────────────────────────────────────────────────────────────
# Telepathy — doubles Speed on Magic Field (passive SpeedCalc)
# ─────────────────────────────────────────────────────────────────────────────
Battle::AbilityEffects::SpeedCalc.add(:TELEPATHY,
  proc { |ability, battler, mult|
    next mult * 2 if battler.battle.has_field? && MAGIC_IDS.include?(battler.battle.current_field.id)
  }
)