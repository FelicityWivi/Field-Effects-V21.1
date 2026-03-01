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
    
    allBattlers.each do |battler|
      next if battler.fainted?
      
      damage_amount = field_passive_damage_amount(battler)
      next unless damage_amount && damage_amount > 0
      
      # Apply the damage
      battler.pbTakeEffectDamage(damage_amount, false)
      
      # Display message
      message = field_passive_damage_message(battler)
      pbDisplay(message) if message
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
    when :desert
      # 1/16 HP damage in sandstorm
      if pbWeather == :Sandstorm
        return (battler.totalhp / 16.0).round
      end
    when :icy, :snowymountain
      # 1/16 HP damage in hail
      if pbWeather == :Hail
        return (battler.totalhp / 16.0).round
      end
    end
    
    return nil
  end
  
  # Get message for passive damage
  def field_passive_damage_message(battler)
    case @current_field.id
    when :volcanic, :superheated, :volcanictop, :infernal
      return _INTL("{1} was hurt by the scorching heat!", battler.pbThis)
    when :dragonsden
      return _INTL("{1} was hurt by the draconic energy!", battler.pbThis) if pbWeather != :SUNNYDAY
    when :underwater
      return _INTL("{1} struggled to breathe!", battler.pbThis)
    when :murkwatersurface
      return _INTL("{1} was poisoned by the murky water!", battler.pbThis)
    when :corrosive, :corrosivemist
      return _INTL("{1} was hurt by the corrosion!", battler.pbThis)
    when :desert
      return _INTL("{1} was buffeted by the sand!", battler.pbThis) if pbWeather == :Sandstorm
    when :icy, :snowymountain
      return _INTL("{1} was buffeted by the hail!", battler.pbThis) if pbWeather == :Hail
    end
    
    return _INTL("{1} was hurt by the field!", battler.pbThis)
  end
end

class Battle::Battler
  # Check if battler should take field passive damage
  def should_take_field_passive_damage?
    return false if fainted?
    
    case @battle.current_field&.id
    when :volcanic, :superheated, :volcanictop, :infernal
      return burning_field_passive_damage?
    when :underwater
      return underwater_field_passive_damage?
    when :murkwatersurface
      return murky_water_surface_passive_damage?
    when :corrosive, :corrosivemist
      return corrosive_field_passive_damage?
    when :desert
      return desert_field_passive_damage?
    when :icy, :snowymountain
      return icy_field_passive_damage?
    when :dragonsden
      return dragons_den_passive_damage?
    end
    
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
    # Check water effectiveness
    effectiveness = Effectiveness.calculate(:WATER, *pbTypes(true))
    return false if effectiveness <= Effectiveness::NOT_VERY_EFFECTIVE_ONE
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
  
  # Desert field passive damage check
  def desert_field_passive_damage?
    return false unless @battle.pbWeather == :Sandstorm
    return false if pbHasType?(:GROUND) || pbHasType?(:ROCK) || pbHasType?(:STEEL)
    return false if hasActiveAbility?([:SANDVEIL, :SANDRUSH, :SANDFORCE, :MAGICGUARD, :OVERCOAT])
    return false if hasActiveItem?(:SAFETYGOGGLES)
    return true
  end
  
  # Icy field passive damage check
  def icy_field_passive_damage?
    return false unless @battle.pbWeather == :Hail
    return false if pbHasType?(:ICE)
    return false if hasActiveAbility?([:ICEBODY, :SNOWCLOAK, :MAGICGUARD, :OVERCOAT])
    return false if hasActiveItem?(:SAFETYGOGGLES)
    return true
  end
  
  # Dragon's Den passive damage check
  def dragons_den_passive_damage?
    return false if @battle.pbWeather == :SUNNYDAY
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
# Pledge Move System
# Handles Grass Pledge + Fire Pledge = Sea of Fire, etc.
#===============================================================================
class Battle
  attr_accessor :pledge_moves_used
  
  # Initialize pledge tracking
  alias field_pledge_initialize initialize unless method_defined?(:field_pledge_initialize)
  def initialize(*args)
    field_pledge_initialize(*args)
    @pledge_moves_used = {}
  end
  
  # Check if a pledge move was used this turn
  def pledge_move_used?(move_id)
    return @pledge_moves_used[move_id] == true
  end
  
  # Register pledge move usage
  def register_pledge_move(move_id)
    @pledge_moves_used[move_id] = true
  end
  
  # Clear pledge moves (at end of round)
  def clear_pledge_moves
    @pledge_moves_used.clear
  end
  
  # Check for pledge combo
  def check_pledge_combo(move_id)
    case move_id
    when :FIREPLEDGE
      if pledge_move_used?(:GRASSPLEDGE)
        return :sea_of_fire
      elsif pledge_move_used?(:WATERPLEDGE)
        return :rainbow
      end
    when :WATERPLEDGE
      if pledge_move_used?(:FIREPLEDGE)
        return :rainbow
      elsif pledge_move_used?(:GRASSPLEDGE)
        return :swamp
      end
    when :GRASSPLEDGE
      if pledge_move_used?(:WATERPLEDGE)
        return :swamp
      elsif pledge_move_used?(:FIREPLEDGE)
        return :sea_of_fire
      end
    end
    
    return nil
  end
  
  # Apply pledge combo effect
  def apply_pledge_combo(combo_type, side)
    case combo_type
    when :sea_of_fire
      pbDisplay(_INTL("A sea of fire enveloped {1}!", side.opposes?(0) ? "the opposing team" : "your team"))
      side.effects[PBEffects::SeaOfFire] = 4
      
    when :rainbow
      pbDisplay(_INTL("A rainbow appeared in the sky on {1}'s side!", side.opposes?(0) ? "the opposing team" : "your team"))
      side.effects[PBEffects::Rainbow] = 4
      
    when :swamp
      pbDisplay(_INTL("A swamp enveloped {1}!", side.opposes?(0) ? "the opposing team" : "your team"))
      side.effects[PBEffects::Swamp] = 4
    end
  end
end

# Integrate pledge moves
Battle::Move.class_eval do
  alias field_pledge_pbEffectGeneral pbEffectGeneral unless method_defined?(:field_pledge_pbEffectGeneral)
  
  def pbEffectGeneral(user)
    # Check for pledge moves
    if [:FIREPLEDGE, :WATERPLEDGE, :GRASSPLEDGE].include?(@id)
      combo = @battle.check_pledge_combo(@id)
      if combo
        @battle.apply_pledge_combo(combo, user.pbOwnSide)
      end
      @battle.register_pledge_move(@id)
    end
    
    # Call original method
    field_pledge_pbEffectGeneral(user)
  end
end

# Clear pledge moves at end of round
Battle.class_eval do
  alias field_pledge_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:field_pledge_pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    field_pledge_pbEndOfRoundPhase
    clear_pledge_moves
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
      return ![:SHADOWSKY, :STRONGWINDS].include?(weather_type)
      
    when :superheated, :volcanic, :volcanictop, :infernal
      # Hot fields block hail
      return weather_type == :Hail
      
    when :infernal
      # Infernal also blocks rain
      return [:Hail, :RAINDANCE].include?(weather_type)
      
    when :cave, :cave1, :cave2, :cave3, :cave4
      # Caves block some weather
      return [:SUNNYDAY].include?(weather_type)
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
      when :SUNNYDAY
        return _INTL("The sunlight cannot pierce the darkness!")
      when :RAINDANCE
        return _INTL("The dark dimension swallowed the rain!")
      when :SANDSTORM
        return _INTL("The dark dimension swallowed the sand!")
      when :HAIL
        return _INTL("The dark dimension swallowed the hail!")
      end
    when :superheated, :volcanic, :volcanictop, :infernal, :dragonsden
      return _INTL("The hail melted away!")
    when :infernal
      return _INTL("The rain evaporated!") if weather_type == :RAINDANCE
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
#===============================================================================
Battle.class_eval do
  alias field_passive_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:field_passive_pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    # Call original method first
    field_passive_pbEndOfRoundPhase
    
    # Apply field passive damage
    apply_field_passive_damage
  end
end
