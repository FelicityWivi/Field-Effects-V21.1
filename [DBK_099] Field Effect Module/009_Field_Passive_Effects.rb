#===============================================================================
# Field-Specific Passive Effects and Special Mechanics
# Converted from Battle_Field.rb
#===============================================================================

#===============================================================================
# Field Passive Damage Handler
# Handles damage from burning fields, underwater, murky water, etc.
#===============================================================================
class Battle
  # Apply passive damage from fields at end of round
  def apply_field_passive_damage
    return unless has_field?
    # Fields that define :healthChanges in their fieldtxt data already apply
    # EOR damage through register_health_changes -> EOR_field_battler, which
    # fires earlier in end_of_round_field_process (001_Battle.rb).  Applying
    # damage here a second time causes the double-hit and the phantom extra
    # turn when a Pokemon faints (the turn runs before the replacement is
    # prompted because faint handling is bypassed in this path).
    return if @current_field.health_changes&.any?

    allBattlers.each do |battler|
      next if battler.fainted?

      damage_amount = field_passive_damage_amount(battler)
      next unless damage_amount && damage_amount > 0

      # Apply the damage and update the HP bar.
      # Play the damage flash animation first (matching PE21.1's pbEORWeatherDamage),
      # then reduce HP with anim=false since the animation already ran.
      @scene.pbDamageAnimation(battler)
      battler.pbReduceHP(damage_amount, false)

      # Display message
      message = field_passive_damage_message(battler)
      pbDisplay(message) if message

      # Item heal check (Sitrus Berry etc.), ability on-damage check
      # (Emergency Exit / Wimp Out), then faint — matching PE21.1's EOR pattern.
      battler.pbItemHPHealCheck
      battler.pbAbilitiesOnDamageTaken
      battler.pbFaint if battler.fainted?
    end
  end
  
  # Calculate passive damage amount
  def field_passive_damage_amount(battler)
    return nil unless battler.should_take_field_passive_damage?
    
    case @current_field.id
    when :volcanic, :superheated, :volcanictop, :infernal, :dragonsden
      # 1/16 HP damage
      return (battler.totalhp / 16.0).round
    when :underwater
      # 1/8 HP damage
      return (battler.totalhp / 8.0).round
    when :murkwatersurface
      # 1/8 HP damage (like poison)
      return (battler.totalhp / 8.0).round
    when :corrosive, :corrosivemist
      # 1/16 HP damage
      return (battler.totalhp / 16.0).round
    # NOTE: :desert sandstorm damage is handled entirely by the Desert Field EOR
    # block in 010_Comprehensive_Field_Mechanics.rb at the correct 1/8 HP rate.
    # NOTE: :icy / :snowymountain hail damage is handled by core pbEORWeatherDamage
    # at the correct 1/16 HP rate.  Do not add them here.
    end
    
    return nil
  end
  
  # Get message for passive damage
  def field_passive_damage_message(battler)
    case @current_field.id
    when :volcanic, :superheated, :volcanictop, :infernal
      return _INTL("{1} was hurt by the scorching heat!", battler.pbThis)
    when :dragonsden
      return _INTL("{1} was hurt by the draconic energy!", battler.pbThis) unless [:Sun, :HarshSun].include?(pbWeather)
    when :underwater
      return _INTL("{1} struggled to breathe!", battler.pbThis)
    when :murkwatersurface
      return _INTL("{1} was poisoned by the murky water!", battler.pbThis)
    when :corrosive, :corrosivemist
      return _INTL("{1} was hurt by the corrosion!", battler.pbThis)
    # NOTE: :desert and :icy/:snowymountain messages are shown by their
    # respective handlers (010 EOR block and core pbEORWeatherDamage).
    end
    
    return _INTL("{1} was hurt by the field!", battler.pbThis)
  end
end

class Battle::Battler
  # Check if battler should take field passive damage
  def should_take_field_passive_damage?
    return false if fainted?
    # Fields with :healthChanges registered handle their own EOR damage via
    # register_health_changes. Don't double-count them here.
    return false if @battle.current_field&.health_changes&.any?

    case @battle.current_field&.id
    when :volcanic, :superheated, :volcanictop, :infernal
      return burning_field_passive_damage?
    when :underwater
      return underwater_field_passive_damage?
    when :murkwatersurface
      return murky_water_surface_passive_damage?
    when :corrosive, :corrosivemist
      return corrosive_field_passive_damage?
    when :dragonsden
      return dragons_den_passive_damage?
    end
    # NOTE: :desert sandstorm damage is handled entirely by the Desert Field EOR
    # block in 010_Comprehensive_Field_Mechanics.rb at the correct 1/8 HP rate
    # with a single message.  Do NOT add it here — doing so caused a double-hit
    # (two "buffeted" messages, three separate 1/16 damage applications).
    #
    # NOTE: :icy / :snowymountain hail damage is handled by the core PE
    # pbEORWeatherDamage at the correct 1/16 rate.  Do NOT add it here — doing
    # so caused a second 1/16 hit with a second "buffeted" message.
    
    return false
  end
  
  # Burning field passive damage check
  def burning_field_passive_damage?
    return false if pbHasType?(:FIRE)
    return false if @effects[PBEffects::AquaRing]
    return false if hasActiveAbility?([:FLAREBOOST, :MAGMAARMOR, :FLAMEBODY, :FLASHFIRE,
                                       :WATERVEIL, :MAGICGUARD, :HEATPROOF, :WATERBUBBLE])
    # Check if using Dig or Dive
    if @effects[PBEffects::TwoTurnAttack]
      move_data = GameData::Move.try_get(@effects[PBEffects::TwoTurnAttack])
      return false if move_data && [:DIG, :DIVE].include?(move_data.id)
    end
    return true
  end
  
  # Underwater field passive damage check
  def underwater_field_passive_damage?
    return false if pbHasType?(:WATER)
    return false if hasActiveAbility?([:SWIFTSWIM, :MAGICGUARD])
    # Check water effectiveness using the field system's preferred method API
    effectiveness = Effectiveness.calculate(:WATER, *pbTypes(true))
    return false if Effectiveness.not_very_effective?(effectiveness) || Effectiveness.ineffective?(effectiveness)
    return true
  end
  
  # Murky water surface passive damage check
  def murky_water_surface_passive_damage?
    return false if pbHasType?(:STEEL) || pbHasType?(:POISON)
    return false if hasActiveAbility?([:POISONHEAL, :MAGICGUARD, :WONDERGUARD, 
                                       :TOXICBOOST, :IMMUNITY, :PASTELVEIL, :SURGESURFER])
    return true
  end
  
  # Corrosive field passive damage check
  def corrosive_field_passive_damage?
    return false if pbHasType?(:STEEL) || pbHasType?(:POISON)
    return false if hasActiveAbility?([:POISONHEAL, :MAGICGUARD, :IMMUNITY, :PASTELVEIL])
    return true
  end
  
  # Dragon's Den passive damage check
  def dragons_den_passive_damage?
    return false if [:Sun, :HarshSun].include?(@battle.pbWeather)
    return false if pbHasType?(:DRAGON)
    return false if hasActiveAbility?(:MAGICGUARD)
    return true
  end
end

#===============================================================================
# Field Defense Multipliers
# Handles defense boosts from certain fields
#===============================================================================
class Battle::Move
  # Calculate defense multiplier from field
  def field_defense_multiplier(user, target)
    return 1.0 unless @battle.has_field?
    
    defmult = 1.0
    field_id = @battle.current_field.id
    move_type = pbCalcType(user)
    
    case field_id
    when :misty
      defmult *= 1.5 if specialMove? && target.pbHasType?(:FAIRY)
      
    when :darkcrystalcavern
      defmult *= 1.5 if target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
      defmult *= 1.33 if target.hasActiveAbility?(:PRISMARMOR)
      
    when :rainbow, :crystalcavern
      defmult *= 1.33 if target.hasActiveAbility?(:PRISMARMOR)
      
    when :dragonsden
      defmult *= 1.3 if target.pbHasType?(:DRAGON)
      
    when :newworld
      defmult *= 0.9 if target.airborne?
      
    when :snowymountain, :icy
      if physicalMove? && target.pbHasType?(:ICE) && @battle.pbWeather == :Hail
        defmult *= 1.5
      end
      
    when :desert
      defmult *= 1.5 if specialMove? && target.pbHasType?(:GROUND)
      
    when :dimensional
      defmult *= 1.5 if target.pbHasType?(:GHOST)
      
    when :frozendimension
      defmult *= 1.2 if target.pbHasType?(:GHOST) || target.pbHasType?(:ICE)
      defmult *= 0.8 if target.pbHasType?(:FIRE)
      
    when :darkness2
      defmult *= 1.1 if target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
      
    when :darkness3
      defmult *= 1.2 if target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
      
    when :ashenbeach
      defmult *= 1.5 if physicalMove? && target.pbHasType?(:GROUND)
      
    when :cave
      defmult *= 1.2 if target.pbHasType?(:ROCK)
      
    when :glitch
      # Random defense effects
      if rand(100) < 20
        defmult *= [0.5, 0.75, 1.25, 1.5].sample
      end
    end
    
    return defmult
  end
end

# Integrate into damage calculation
Battle::Move.class_eval do
  alias field_defense_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:field_defense_pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Call original method
    field_defense_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    
    # Apply field defense multiplier
    def_mult = field_defense_multiplier(user, target)
    multipliers[:defense_multiplier] *= def_mult if def_mult != 1.0
  end
end

#===============================================================================
# Field Counter System (for Crystal Cavern, Short Circuit, etc.)
#===============================================================================
class Battle
  # Get current roll value for fields that use rolling mechanics
  def get_field_roll(update_roll: true, maximize_roll: false)
    return nil unless has_field?
    
    case @current_field.id
    when :crystalcavern
      # Crystal Cavern rolls for random type
      choices = [:NORMAL, :FIGHTING, :FLYING, :POISON, :GROUND, :ROCK,
                 :BUG, :GHOST, :STEEL, :FIRE, :WATER, :GRASS,
                 :ELECTRIC, :PSYCHIC, :ICE, :DRAGON, :DARK, :FAIRY]
      counter = @field_counters.counter
      result = choices[counter % choices.length]
      @field_counters.counter = (counter + 1) % choices.length if update_roll
      # Maximize not applicable for type rolls
      return result
      
    when :shortcircuit
      # Short Circuit rolls for damage multiplier
      choices = [0, 1, 2, 3, 4, 5, 6]
      counter = @field_counters.counter
      result = choices[counter % choices.length]
      @field_counters.counter = (counter + 1) % choices.length if update_roll
      result = choices.max if maximize_roll
      return result
      
    when :glitch
      # Glitch field has random effects
      choices = [1, 2, 3, 4, 5, 6]
      counter = @field_counters.counter
      result = choices[counter % choices.length]
      @field_counters.counter = (counter + 1) % choices.length if update_roll
      result = choices.max if maximize_roll
      return result
    end
    
    return nil
  end
  
  # Reset field counters (when field changes)
  def reset_field_counters
    @field_counters.counter = 0
    @field_counters.counter2 = 0
    @field_counters.counter3 = 0
    @field_counters.backup = nil
  end
  
  # Store backup field info
  def store_field_backup
    return unless has_field?
    @field_counters.backup = {
      counter: @field_counters.counter,
      counter2: @field_counters.counter2,
      counter3: @field_counters.counter3
    }
  end
  
  # Restore field backup
  def restore_field_backup
    return unless @field_counters.backup
    @field_counters.counter = @field_counters.backup[:counter] || 0
    @field_counters.counter2 = @field_counters.backup[:counter2] || 0
    @field_counters.counter3 = @field_counters.backup[:counter3] || 0
  end
end

#===============================================================================
# Weather Blocking for Specific Fields
#===============================================================================
class Battle
  # Check if field blocks weather
  def field_blocks_weather?(weather_type)
    return false unless has_field?
    
    case @current_field.id
    when :newworld
      # New World blocks all weather
      return true
      
    when :underwater
      # Underwater blocks all weather
      return true
      
    when :dimensional
      # Dimensional field blocks non-shadow weather
      return ![:ShadowSky, :StrongWinds].include?(weather_type)
      
    when :superheated, :volcanic, :volcanictop
      # Hot fields block hail
      return weather_type == :Hail
      
    when :infernal
      # Infernal blocks both hail and rain
      return [:Hail, :Rain, :HeavyRain].include?(weather_type)
      
    when :cave, :cave1, :cave2, :cave3, :cave4
      # Caves block some weather
      return [:Sun, :HarshSun].include?(weather_type)
    end
    
    return false
  end
  
  # Get message for blocked weather
  def field_weather_block_message(weather_type)
    case @current_field.id
    when :newworld
      return _INTL("The weather disappeared into space!")
    when :underwater
      return _INTL("You're too deep to notice the weather!")
    when :dimensional
      case weather_type
      when :Sun, :HarshSun
        return _INTL("The sunlight cannot pierce the darkness!")
      when :Rain, :HeavyRain
        return _INTL("The dark dimension swallowed the rain!")
      when :Sandstorm
        return _INTL("The dark dimension swallowed the sand!")
      when :Hail
        return _INTL("The dark dimension swallowed the hail!")
      end
    when :superheated, :volcanic, :volcanictop, :dragonsden
      return _INTL("The hail melted away!")
    when :infernal
      return _INTL("The rain evaporated!") if [:Rain, :HeavyRain].include?(weather_type)
      return _INTL("The hail melted away!")
    end
    
    return _INTL("The field prevented the weather!")
  end
end

# Integrate into weather setting
Battle.class_eval do
  alias field_weather_pbStartWeather pbStartWeather unless method_defined?(:field_weather_pbStartWeather)
  
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
    # Check if field blocks this weather
    if field_blocks_weather?(newWeather)
      pbDisplay(field_weather_block_message(newWeather))
      return
    end
    
    # Call original method
    field_weather_pbStartWeather(user, newWeather, fixedDuration, showAnim)
  end
end

#===============================================================================
# End of Round Integration
# NOTE: apply_field_passive_damage is called directly from end_of_round_field_process
# in 001_Battle.rb, which runs before PE's own pbEndOfRoundPhase. This ensures
# passive field damage faints are caught by PE's natural faint sweep rather than
# being handled after PE's replacement flow has already completed.
#===============================================================================

#===============================================================================
# MAGIC FIELD — Passive Effects Note
#
# The Magic Field has NO end-of-round passive damage, so no additional
# damage-handler code is required in this file.
#
# All Magic Field passive mechanics are handled elsewhere:
#
#   • Ability stat boosts on switch-in (Magician/Anticipation/Forewarn/
#     Mind's Eye → +1 SpAtk; Magic Bounce/Magic Guard → +1 SpDef)
#     → Registered via :abilityStatBoosts in 005_fieldtxt.rb and processed
#       by the existing abilityStatBoosts handler in 007/010.
#
#   • Pure Power / Huge Power → Sp. Atk instead of Atk
#   • Power Spot              → 1.5× ally damage
#   • Telepathy               → Speed × 2
#   • Zen Mode                → always active
#     → All hardcoded in 010_Comprehensive_Field_Mechanics.rb
#       under the MAGIC_FIELD_IDS block.
#
#   • Camouflage   → Psychic   (handled by :mimicry      => :PSYCHIC in 005)
#   • Nature Power → Psychic   (handled by :naturePower  => :PSYCHIC in 005)
#   • Secret Power → Confuse   (overridden in 010 via SecretPower#pbAdditionalEffect)
#   • Terrain Pulse → Psychic  (handled by :mimicry      => :PSYCHIC in 005)
#===============================================================================
