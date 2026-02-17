#===============================================================================
# Comprehensive Field Mechanics System
# Combines: Move Failures, Mimicry, Ability Mods, Cave Collapse, No Charging
#===============================================================================

#===============================================================================
# 1. FIELD CLASS EXTENSIONS
#===============================================================================
class Battle::Field
  attr_reader :ability_mods           # Ability modifications for this field
  attr_reader :failed_moves           # Moves that fail on this field
  attr_reader :no_charging_moves      # Moves that skip charging turn on this field
  attr_reader :no_charging_messages   # Custom messages for no charging moves
  attr_reader :status_damage_mods     # Status damage multipliers for this field
  attr_reader :move_stat_boosts       # Stat boosts from using certain moves
  attr_reader :blocked_statuses       # Status conditions that cannot be inflicted
  attr_reader :blocked_weather        # Weather conditions that cannot be set
  attr_reader :health_changes         # End of round healing/damage
  attr_reader :ability_stat_boosts    # Stat boosts when battler with ability enters
  attr_reader :ability_form_changes   # Form changes when battler with ability enters
  attr_reader :move_stat_stage_mods   # Modify stat stage changes caused by moves
  attr_reader :ability_activated      # Abilities activated by this field (passive + EOR)
  attr_reader :ignore_acc_eva_changes # Abilities that ignore accuracy/evasion changes
  attr_reader :status_immunity        # Status conditions prevented by type/ability on this field
  attr_reader :weather_duration       # Extended weather duration for specific weather types
  attr_reader :item_effect_mods       # Item effect modifications on this field
  attr_reader :weather_field_change   # Field transitions triggered by weather at EOR
  attr_reader :ground_hits_airborne   # Ground moves can hit airborne Pokemon
  attr_reader :hazard_multiplier      # Entry hazard damage multipliers
  
  alias comprehensive_initialize initialize
  def initialize(*args)
    comprehensive_initialize(*args)
    @ability_mods ||= {}
    @failed_moves ||= {}
    @no_charging_moves ||= []
    @no_charging_messages ||= {}
    @status_damage_mods ||= {}
    @move_stat_boosts ||= []
    @blocked_statuses ||= []
    @blocked_weather ||= []
    @health_changes ||= []
    @ability_stat_boosts ||= {}
    @ability_form_changes ||= {}
    @move_stat_stage_mods ||= {}
    @ability_activated ||= {}
    @ignore_acc_eva_changes ||= []
    @status_immunity ||= {}
    @weather_duration ||= {}
    @item_effect_mods ||= {}
    @weather_field_change ||= {}
    @ground_hits_airborne ||= false
    @hazard_multiplier ||= {}
  end
  
  # Called after initialization to register the no_charging effect
  def register_no_charging_effect
    @effects[:no_charging] = proc { |user, move|
      if $DEBUG
        Console.echo_li("[FIELD EFFECT] no_charging proc called")
        Console.echo_li("[FIELD EFFECT] @no_charging_moves = #{@no_charging_moves.inspect}")
        Console.echo_li("[FIELD EFFECT] move.id = #{move.id}")
        Console.echo_li("[FIELD EFFECT] included? #{@no_charging_moves.include?(move.id)}")
      end
      next false if !@no_charging_moves
      next @no_charging_moves.include?(move.id)
    }
  end
end

#===============================================================================
# 2. MOVE FAILURES
#===============================================================================
class Battle::Move
  alias field_failure_pbFailsAgainstTarget? pbFailsAgainstTarget?
  
  def pbFailsAgainstTarget?(user, target, show_message)
    # Check if field causes this move to fail
    if @battle.has_field? && @battle.current_field.failed_moves
      if @battle.current_field.failed_moves[@id]
        if show_message
          @battle.pbDisplay(@battle.current_field.failed_moves[@id])
        end
        return true
      end
    end
    
    # Call original
    return field_failure_pbFailsAgainstTarget?(user, target, show_message)
  end
end

#===============================================================================
# 3. NO CHARGING MOVES - Makes two-turn moves execute immediately
#===============================================================================

class Battle::Move::TwoTurnMove
  def pbIsChargingTurn?(user)
    @powerHerb = false
    @chargingTurn = false   # Assume damaging turn by default
    @damagingTurn = true
    
    if $DEBUG
      Console.echo_li("[NO CHARGE DEBUG] ===== pbIsChargingTurn START =====")
      Console.echo_li("[NO CHARGE DEBUG] Move: #{@id}, TwoTurnAttack effect: #{user.effects[PBEffects::TwoTurnAttack]}")
    end
    
    # nil at start of charging turn, move's ID at start of damaging turn
    if !user.effects[PBEffects::TwoTurnAttack]
      if skipChargingTurn?(user)
        if $DEBUG
          Console.echo_li("[NO CHARGE DEBUG] skipChargingTurn returned TRUE - executing immediately")
        end
        skipChargingTurn
      else
        if $DEBUG
          Console.echo_li("[NO CHARGE DEBUG] skipChargingTurn returned FALSE - normal charging")
        end
        @powerHerb = user.hasActiveItem?(:POWERHERB)
        @chargingTurn = true
        @damagingTurn = @powerHerb
      end
    end
    
    if $DEBUG
      Console.echo_li("[NO CHARGE DEBUG] FINAL FLAGS: chargingTurn=#{@chargingTurn}, damagingTurn=#{@damagingTurn}, powerHerb=#{@powerHerb}")
      Console.echo_li("[NO CHARGE DEBUG] Returning: #{!@damagingTurn}")
      Console.echo_li("[NO CHARGE DEBUG] ===== pbIsChargingTurn END =====")
    end
    
    return !@damagingTurn   # Deliberately not "return @chargingTurn"
  end

  def skipChargingTurn?(user)
    if $DEBUG
      Console.echo_li("[NO CHARGE DEBUG] Checking skipChargingTurn for #{@id}")
      Console.echo_li("[NO CHARGE DEBUG] Has field? #{@battle.has_field?}")
      if @battle.has_field?
        Console.echo_li("[NO CHARGE DEBUG] Field ID: #{@battle.current_field.id}")
        Console.echo_li("[NO CHARGE DEBUG] Field has no_charging_moves? #{@battle.current_field.respond_to?(:no_charging_moves)}")
        if @battle.current_field.respond_to?(:no_charging_moves)
          Console.echo_li("[NO CHARGE DEBUG] no_charging_moves list: #{@battle.current_field.no_charging_moves.inspect}")
        end
      end
    end
    
    ret = @battle.apply_field_effect(:no_charging, user, self)
    
    if $DEBUG
      Console.echo_li("[NO CHARGE DEBUG] apply_field_effect(:no_charging) returned: #{ret.inspect}")
    end
    
    return true if ret
    return false
  end

  def skipChargingTurn
    @powerHerb = false
    @chargingTurn = true
    @damagingTurn = true
    
    if $DEBUG
      Console.echo_li("[NO CHARGE DEBUG] skipChargingTurn called - setting chargingTurn=true, damagingTurn=true")
    end
  end
end

# Override pbEffectGeneral to prevent TwoTurnAttack effect from being set
class Battle::Move::TwoTurnMove
  alias field_pbEffectGeneral pbEffectGeneral
  
  def pbEffectGeneral(user)
    # Check if field allows instant execution
    field_skips = false
    if @battle.has_field? && @battle.current_field.no_charging_moves
      field_skips = @battle.current_field.no_charging_moves.include?(@id)
      if $DEBUG && field_skips
        Console.echo_li("[NO CHARGE DEBUG] pbEffectGeneral - field skip detected")
      end
    end
    
    # Call original (this triggers charging animation and "flew up high" message)
    ret = field_pbEffectGeneral(user)
    
    # Clear the TwoTurnAttack effect if field skips charging
    if field_skips
      user.effects[PBEffects::TwoTurnAttack] = nil
      if $DEBUG
        Console.echo_li("[NO CHARGE DEBUG] Cleared TwoTurnAttack effect")
      end
    end
    
    return ret
  end
  
  # Show custom message at the very start of damage calculation
  alias field_pbCalcDamage pbCalcDamage
  
  def pbCalcDamage(user, target, *args)
    # Check if field allows instant execution and we haven't shown the message yet
    if @battle.has_field? && @battle.current_field.no_charging_moves
      if @battle.current_field.no_charging_moves.include?(@id)
        if !@field_message_shown
          custom_msg = get_no_charging_message
          if custom_msg
            if $DEBUG
              Console.echo_li("[NO CHARGE MSG] Displaying custom message before damage calc: #{custom_msg}")
            end
            @battle.pbDisplay(custom_msg)
            @field_message_shown = true
          end
        end
      end
    end
    
    # Call original to calculate damage with all arguments
    field_pbCalcDamage(user, target, *args)
  end
end

# Show custom message right after "uses" message
class Battle::Move::TwoTurnMove
  alias field_pbDisplayUseMessage pbDisplayUseMessage
  
  def pbDisplayUseMessage(user)
    # Call original to show "[Pokemon] used [Move]!"
    field_pbDisplayUseMessage(user)
    
    # Don't show custom message here - let it show after charging animation
  end
  
  # Suppress the charging message when field skips charging
  # NOTE: This doesn't seem to work because the message comes from the animation system
  # Instead we just show our custom message after it
  alias field_pbChargingTurnMessage pbChargingTurnMessage
  
  def pbChargingTurnMessage(user, targets)
    # Just call original - we'll show our message separately
    field_pbChargingTurnMessage(user, targets)
  end
  
  def get_no_charging_message
    return nil unless @battle.has_field?
    field = @battle.current_field
    
    # Check if there's a custom message in the field data
    if field.respond_to?(:no_charging_messages) && field.no_charging_messages
      return field.no_charging_messages[@id] if field.no_charging_messages[@id]
    end
    
    # Default messages for common moves
    case @id
    when :FLY
      return "The cave's low ceiling makes flying high impossible!"
    when :BOUNCE
      return "The cave's low ceiling prevents a high bounce!"
    when :SOLARBEAM, :SOLARBLADE
      return "The field's energy allows instant charging!"
    when :SKYDROP
      return "The cave's low ceiling makes flying high impossible!"
    when :SKYATTACK
      return "The conditions allow an instant strike!"
    when :RAZORWIND
      return "The wind is already whipping!"
    when :SKULLBASH, :GEOMANCY
      return "The field's energy allows instant preparation!"
    end
    
    return nil
  end
end

# NOTE: pbChargingTurnMessage is only called when the move charges (returns true from pbIsChargingTurn?)
# Since we return false (move executes immediately), the charging message method is never called.
# We show our custom message in pbEffectGeneral instead.

#===============================================================================
# 4. MIMICRY ABILITY
#===============================================================================

# Battle Helper Methods
class Battle
  def get_mimicry_type
    # First check for terrain (vanilla mechanics)
    if @field.terrain != :None
      case @field.terrain
      when :Electric then return :ELECTRIC
      when :Grassy   then return :GRASS
      when :Misty    then return :FAIRY
      when :Psychic  then return :PSYCHIC
      end
    end
    
    # Then check for field effect mimicry type
    if has_field?
      field_type = apply_field_effect(:mimicry_type, nil, nil)
      return field_type if field_type
    end
    
    return nil
  end
  
  def apply_mimicry_to_battler(battler, show_message = true)
    return unless battler.hasActiveAbility?(:MIMICRY)
    return if battler.fainted?
    
    new_type = get_mimicry_type
    return if !new_type
    
    # Check if type actually changed
    current_types = battler.pbTypes(true)
    return if current_types.length == 1 && current_types[0] == new_type
    
    # Change the battler's type
    battler.pbChangeTypes(new_type)
    
    # Display message
    if show_message
      type_name = GameData::Type.get(new_type).name
      pbDisplay(_INTL("{1} transformed into the {2} type!", battler.pbThis, type_name))
    end
  end
  
  def trigger_mimicry_on_field_change
    allBattlers.each do |b|
      apply_mimicry_to_battler(b, true)
    end
  end
end

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

# Trigger on field change
class Battle
  alias mimicry_set_field set_field
  def set_field(*args)
    mimicry_set_field(*args)
    trigger_mimicry_on_field_change
  end
end

# Add to begin_battle effect
class Battle::Field
  alias mimicry_initialize initialize
  def initialize(*args)
    mimicry_initialize(*args)
    
    existing_begin_battle = @effects[:begin_battle] || proc { }
    @effects[:begin_battle] = proc {
      existing_begin_battle.call
      @battle.trigger_mimicry_on_field_change
    }
  end
end

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

Battle::AbilityEffects::DamageCalcFromUser.copy(:GALVANIZE,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :ELECTRIC || move.function_code == "TypeDependsOnUserIVs"
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :GALVANIZE, 1.2)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:PIXILATE,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :FAIRY || move.function_code == "TypeDependsOnUserIVs"
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :PIXILATE, 1.2)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:AERILATE,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :FLYING || move.function_code == "TypeDependsOnUserIVs"
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :AERILATE, 1.2)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.copy(:REFRIGERATE,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :ICE || move.function_code == "TypeDependsOnUserIVs"
    mults[:power_multiplier] *= move.field_ability_multiplier(user, :REFRIGERATE, 1.2)
  }
)

#===============================================================================
# 6. CAVE COLLAPSE SYSTEM
#===============================================================================
class Battle
  alias cave_collapse_initialize initialize
  def initialize(*args)
    cave_collapse_initialize(*args)
    @cave_collapse_counter = 0
    @cave_collapse_warning = false
  end
  
  def is_cave?
    return false unless has_field?
    cave_fields = [:cave, :cave1, :cave2, :cave3, :cave4, :crystalcavern, 
                   :darkcrystalcavern]
    return cave_fields.include?(@current_field.id)
  end
  
  def caveCollapse
    return unless is_cave?
    @cave_collapse_counter += 1
    @cave_collapse_warning = true if @cave_collapse_counter == 1
  end
  
  def process_cave_collapse_after_move
    return unless is_cave?
    return if @cave_collapse_counter == 0
    
    if @cave_collapse_counter == 1 && @cave_collapse_warning
      @cave_collapse_warning = false
      pbDisplay(_INTL("Bits of rock fell from the crumbling ceiling!"))
    elsif @cave_collapse_counter >= 2
      trigger_cave_collapse
    end
  end
  
  def trigger_cave_collapse
    @cave_collapse_counter = 0
    pbDisplay(_INTL("The quake collapsed the ceiling!"))
    
    allBattlers.each do |b|
      next if b.fainted?
      next if b.hasActiveAbility?([:BULLETPROOF, :STALWART, :ROCKHEAD])
      next if b.effects[PBEffects::Protect] || b.effects[PBEffects::SpikyShield] ||
              b.effects[PBEffects::Obstruct] || b.effects[PBEffects::KingsShield] ||
              b.effects[PBEffects::WideGuard]
      
      damage = calculate_cave_collapse_damage(b)
      if damage > 0
        b.pbReduceHP(damage, false)
        pbDisplay(_INTL("{1} was crushed by falling rocks!", b.pbThis))
        b.pbFaint if b.fainted?
      end
    end
  end
  
  def calculate_cave_collapse_damage(battler)
    hp = battler.hp
    total_hp = battler.totalhp
    
    if battler.hasActiveAbility?([:PRISMARMOR, :SOLIDROCK])
      return (total_hp / 3.0).round
    elsif battler.hasActiveAbility?([:SHELLARMOR, :BATTLEARMOR])
      return (total_hp / 2.0).round
    elsif battler.effects[PBEffects::Endure]
      return [hp - 1, 0].max
    elsif battler.hasActiveAbility?(:STURDY) && hp == total_hp
      return [hp - 1, 0].max
    else
      return hp
    end
  end
  
  def reset_cave_collapse
    @cave_collapse_counter = 0
    @cave_collapse_warning = false
  end
end

# Move Integration
class Battle::Move
  alias cave_collapse_pbEffectAfterAllHits pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
    cave_collapse_pbEffectAfterAllHits(user, target)
    
    earthquake_moves = [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, 
                       :TECTONICRAGE, :CONTINENTALCRUSH]
    
    if earthquake_moves.include?(@id)
      @battle.process_cave_collapse_after_move
    end
  end
end

class Battle::Move
  alias cave_collapse_pbDisplayUseMessage pbDisplayUseMessage
  def pbDisplayUseMessage(user)
    cave_collapse_pbDisplayUseMessage(user)
    
    earthquake_moves = [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE,
                       :TECTONICRAGE, :CONTINENTALCRUSH]
    
    if earthquake_moves.include?(@id) && @battle.is_cave?
      @battle.caveCollapse
    end
  end
end

class Battle
  alias cave_collapse_set_field set_field
  def set_field(*args)
    cave_collapse_set_field(*args)
    reset_cave_collapse unless is_cave?
  end
end

#===============================================================================
# 8. BLOCKED STATUSES
# Prevent certain status conditions on specific fields
#===============================================================================

# Prevent status from being inflicted
class Battle::Battler
  alias field_blocked_pbCanInflictStatus? pbCanInflictStatus?
  
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    # Check if field blocks this status
    if @battle.has_field? && @battle.current_field.respond_to?(:blocked_statuses)
      blocked = @battle.current_field.blocked_statuses
      if blocked && blocked.include?(newStatus)
        if showMessages
          field_name = @battle.current_field.name
          case newStatus
          when :FROZEN
            @battle.pbDisplay(_INTL("The {1} prevents freezing!", field_name))
          when :CONFUSED
            @battle.pbDisplay(_INTL("The {1} keeps minds clear!", field_name))
          when :SLEEP
            @battle.pbDisplay(_INTL("The {1} prevents sleep!", field_name))
          when :BURN
            @battle.pbDisplay(_INTL("The {1} prevents burns!", field_name))
          when :POISON
            @battle.pbDisplay(_INTL("The {1} prevents poison!", field_name))
          when :PARALYSIS
            @battle.pbDisplay(_INTL("The {1} prevents paralysis!", field_name))
          else
            @battle.pbDisplay(_INTL("The {1} prevents status conditions!", field_name))
          end
        end
        return false
      end
    end
    
    # Call original
    return field_blocked_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end
end

# Cure blocked statuses when field changes or Pokemon enters
class Battle::Field
  alias blocked_status_initialize initialize
  
  def initialize(*args)
    blocked_status_initialize(*args)
    
    # Register field effect to cure blocked statuses when field starts
    existing_begin_battle = @effects[:begin_battle] || proc { }
    @effects[:begin_battle] = proc {
      existing_begin_battle.call
      cure_blocked_statuses_on_field
    }
  end
  
  def cure_blocked_statuses_on_field
    return unless @blocked_statuses && @blocked_statuses.any?
    
    @battle.allBattlers.each do |battler|
      next if battler.fainted?
      
      # Check main status
      if @blocked_statuses.include?(battler.status)
        old_status = battler.status
        battler.pbCureStatus(false)
        
        status_name = case old_status
        when :FROZEN then "freeze"
        when :BURN then "burn"
        when :PARALYSIS then "paralysis"
        when :POISON then "poison"
        when :SLEEP then "sleep"
        else "status condition"
        end
        
        @battle.pbDisplay(_INTL("{1}'s {2} was cured by the {3}!", 
                               battler.pbThis, status_name, @name))
      end
      
      # Check confusion (volatile status)
      if @blocked_statuses.include?(:CONFUSED) && battler.effects[PBEffects::Confusion] > 0
        battler.pbCureConfusion
        @battle.pbDisplay(_INTL("{1} snapped out of confusion thanks to the {2}!", 
                               battler.pbThis, @name))
      end
    end
  end
  
  def register_blocked_status_cure
    return unless @blocked_statuses && @blocked_statuses.any?
    
    # Cure blocked statuses when field starts
    existing_begin_battle = @effects[:begin_battle] || proc { }
    @effects[:begin_battle] = proc {
      existing_begin_battle.call
      
      # Cure blocked statuses on all active battlers
      @battle.allBattlers.each do |battler|
        next if battler.fainted?
        
        # Check main status
        if @blocked_statuses.include?(battler.status)
          old_status = battler.status
          battler.pbCureStatus(false)
          
          status_name = case old_status
          when :FROZEN then "freeze"
          when :BURN then "burn"
          when :PARALYSIS then "paralysis"
          when :POISON then "poison"
          when :SLEEP then "sleep"
          else "status condition"
          end
          
          @battle.pbDisplay(_INTL("{1}'s {2} was cured by the {3}!", 
                                 battler.pbThis, status_name, @name))
        end
        
        # Check confusion
        if @blocked_statuses.include?(:CONFUSED) && battler.effects[PBEffects::Confusion] > 0
          battler.pbCureConfusion
          @battle.pbDisplay(_INTL("{1} snapped out of confusion thanks to the {2}!", 
                                 battler.pbThis, @name))
        end
      end
    }
  end
end

#===============================================================================
# 9. BLOCKED WEATHER
# Prevent certain weather conditions on specific fields
#===============================================================================
class Battle::Field
  alias blocked_weather_initialize initialize
  
  def initialize(*args)
    blocked_weather_initialize(*args)
    
    # Clear blocked weather when field starts
    existing_begin_battle = @effects[:begin_battle] || proc { }
    @effects[:begin_battle] = proc {
      existing_begin_battle.call
      clear_blocked_weather
    }
  end
  
  def clear_blocked_weather
    return unless @blocked_weather && @blocked_weather.any?
    
    # Check if current weather is blocked
    current = @battle.field.weather
    if @blocked_weather.include?(current)
      weather_name = case current
      when :Sun, :HarshSun then "harsh sunlight"
      when :Rain, :HeavyRain then "rain"
      when :Sandstorm then "sandstorm"
      when :Hail, :Snow then "hail"
      else "weather"
      end
      
      @battle.pbDisplay(_INTL("The {1} clears away the {2}!", @name, weather_name))
      @battle.pbStartWeather(nil, :None, false)
    end
  end
  
  def register_blocked_weather
    return unless @blocked_weather && @blocked_weather.any?
    
    @effects[:block_weather] = proc { |new_weather, user, fixedDuration|
      if @blocked_weather.include?(new_weather)
        weather_name = case new_weather
        when :Sun, :HarshSun then "harsh sunlight"
        when :Rain, :HeavyRain then "rain"
        when :Sandstorm then "sandstorm"
        when :Hail, :Snow then "hail"
        else "weather"
        end
        
        @battle.pbDisplay(_INTL("The {1} prevents {2} from starting!", @name, weather_name))
        next true  # Block the weather
      end
      
      next false  # Allow the weather
    }
  end
end

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
    
    # Populate the @ability_activation array used by existing ability checks
    # This makes apply_field_effect(:ability_activation) return these abilities
    @ability_activated.each_key do |ability|
      @ability_activation << ability unless @ability_activation.include?(ability)
    end
    
    if $DEBUG
      Console.echo_li("[ABILITY ACTIVATE] #{@name} activates: #{@ability_activation.inspect}")
    end
    
    # Register EOR handlers for abilities that need special end-of-turn effects
    eor_abilities = @ability_activated.select { |ability, config| config[:eor] }
    return unless eor_abilities.any?
    
    existing_eor = @effects[:EOR_field_battler] || proc { |battler| }
    
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
    
    @effects[:EOR_field_battler] = proc { |battler|
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
          effectiveness = Effectiveness.calculate(damage_type, 
                                                  battler.pbTypes[0], 
                                                  battler.pbTypes[1])
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
          battler.pbRecoverHP(amount)
          if message
            @battle.pbDisplay(message.gsub("{1}", battler.pbThis).gsub("{2}", @name))
          end
        else
          # Damage - don't show animation or message, pbReduceHP with registerDamage=true handles it
          battler.pbReduceHP(amount, false, true)
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
# 12. MOVE STAT STAGE MODIFIERS
# Intercept stat stage changes from specific moves and replace with boosted version
# e.g. Smokescreen lowers accuracy by 2 stages with a custom field message
#===============================================================================

#===============================================================================
# 12. MOVE STAT STAGE MODIFIERS
# Matches the original code pattern - patches specific move subclasses directly
# Works for both stat downs (TargetStatDownMove) and stat ups (StatUpMove)
#===============================================================================

# Helper module mixed into patched move classes
module FieldStatStageMod
  def field_stat_stage_config
    return nil unless @battle.has_field?
    return nil unless @battle.current_field.respond_to?(:move_stat_stage_mods)
    mods = @battle.current_field.move_stat_stage_mods
    return mods && mods[id] ? mods[id] : nil
  end
end

# Patch TargetStatDownMove subclasses
class Battle::Move::TargetStatDownMove
  include FieldStatStageMod
  
  alias field_stat_down_pbOnStartUse pbOnStartUse
  
  def pbOnStartUse(user, targets)
    field_stat_down_pbOnStartUse(user, targets)
    @field_stat_config = nil
    config = field_stat_stage_config
    return unless config
    
    new_stages = (@statDown[1] * (config[:stages] || 1)).round
    if $DEBUG
      Console.echo_li("[STAT MOD] #{id} @statDown #{@statDown[1]} -> #{new_stages} on #{@battle.current_field.name}")
    end
    @statDown = [@statDown[0], new_stages]
    @field_stat_config = config if config[:message]
  end
  
  alias field_stat_down_pbEffectAgainstTarget pbEffectAgainstTarget
  
  def pbEffectAgainstTarget(user, target)
    unless @field_stat_config&.dig(:message)
      field_stat_down_pbEffectAgainstTarget(user, target)
      return
    end
    stat, stages = @statDown[0], @statDown[1]
    return unless target.pbCanLowerStatStage?(stat, user, self)
    @battle.field_stat_override = true
    target.pbLowerStatStage(stat, stages, user)
    @battle.field_stat_override = false
    msg = @field_stat_config[:message].gsub("{1}", target.pbThis).gsub("{2}", @battle.current_field.name)
    @battle.pbDisplay(msg)
  end
end

# Patch StatUpMove subclasses (used by self-targeting stat raises)
class Battle::Move::StatUpMove
  include FieldStatStageMod
  
  alias field_stat_up_pbOnStartUse pbOnStartUse
  
  def pbOnStartUse(user, targets)
    field_stat_up_pbOnStartUse(user, targets)
    @field_stat_config = nil
    config = field_stat_stage_config
    return unless config
    
    new_stages = (@statUp[1] * (config[:stages] || 1)).round
    if $DEBUG
      Console.echo_li("[STAT MOD] #{id} @statUp #{@statUp[1]} -> #{new_stages} on #{@battle.current_field.name}")
    end
    @statUp = [@statUp[0], new_stages]
    @field_stat_config = config if config[:message]
  end
  
  alias field_stat_up_pbEffectGeneral pbEffectGeneral
  
  def pbEffectGeneral(user)
    unless @field_stat_config&.dig(:message)
      field_stat_up_pbEffectGeneral(user)
      return
    end
    stat, stages = @statUp[0], @statUp[1]
    return unless user.pbCanRaiseStatStage?(stat, user, self)
    @battle.field_stat_override = true
    user.pbRaiseStatStage(stat, stages, user)
    @battle.field_stat_override = false
    msg = @field_stat_config[:message].gsub("{1}", user.pbThis).gsub("{2}", @battle.current_field.name)
    @battle.pbDisplay(msg)
  end
end

# Patch MultiStatUpMove subclasses (e.g. Work Up, Calm Mind, Shift Gear)
class Battle::Move::MultiStatUpMove
  include FieldStatStageMod
  
  alias field_multi_stat_up_pbOnStartUse pbOnStartUse
  
  def pbOnStartUse(user, targets)
    field_multi_stat_up_pbOnStartUse(user, targets)
    @field_stat_config = nil
    config = field_stat_stage_config
    return unless config
    
    # Scale all stat entries in @statUp (format: [stat, stages, stat, stages, ...])
    new_statUp = @statUp.each_slice(2).map do |stat, stages|
      [stat, (stages * (config[:stages] || 1)).round]
    end.flatten
    if $DEBUG
      Console.echo_li("[STAT MOD] #{id} @statUp #{@statUp.inspect} -> #{new_statUp.inspect} on #{@battle.current_field.name}")
    end
    @statUp = new_statUp
    @field_stat_config = config if config[:message]
  end
end

# Suppress built-in stat message when field provides a custom one
class Battle
  attr_accessor :field_stat_override
  
  alias field_stat_override_pbDisplay pbDisplay
  
  def pbDisplay(msg, &block)
    return if @field_stat_override
    field_stat_override_pbDisplay(msg, &block)
  end
end

#===============================================================================
# 21. VOLCANIC TOP FIELD MECHANICS
# Volcanic Top shares most mechanics with Volcanic field (Section 13)
# Additional mechanics specific to Volcanic Top
#===============================================================================

VOLCANIC_TOP_IDS = %i[volcanictop].freeze

# Tailwind - Lasts 6 turns and creates Strong Winds
# NOTE: This needs manual implementation in Tailwind move code to check for volcanic top

# Poison Gas - Causes badly poisoned status
class Battle::Move::PoisonTarget
  alias volcanictop_pbFailsAgainstTarget? pbFailsAgainstTarget?
  
  def pbFailsAgainstTarget?(user, target, show_message)
    # On Volcanic Top, Poison Gas badly poisons
    if @id == :POISONGAS && 
       @battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(@battle.current_field.id)
      @badly_poison = true
    end
    
    volcanictop_pbFailsAgainstTarget?(user, target, show_message)
  end
  
  alias volcanictop_pbEffectAgainstTarget pbEffectAgainstTarget
  
  def pbEffectAgainstTarget(user, target)
    if @badly_poison && 
       @battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(@battle.current_field.id)
      return target.pbInflictStatus(:POISON, 1, nil, user) ? 0 : -1
    end
    
    volcanictop_pbEffectAgainstTarget(user, target)
  end
end

# Outrage/Thrash/Petal Dance - Fatigue after single turn
# Hook into the rampage continuation check
class Battle::Battler
  alias volcanictop_pbContinueAttack pbContinueAttack
  
  def pbContinueAttack
    # On Volcanic Top, immediately end rampage moves
    if @battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(@battle.current_field.id) &&
       @effects[PBEffects::Outrage] > 0
      @effects[PBEffects::Outrage] = 0
      return false
    end
    
    return volcanictop_pbContinueAttack
  end
end

# Tailwind - Lasts 6 turns and creates Strong Winds on Volcanic Top
class Battle::Move::StartUserSideDoubleSpeed
  alias volcanictop_pbEffectGeneral pbEffectGeneral
  
  def pbEffectGeneral(user)
    ret = volcanictop_pbEffectGeneral(user)
    
    # On Volcanic Top, Tailwind lasts 6 turns and creates Strong Winds
    if @battle.has_field? && VOLCANIC_TOP_IDS.include?(@battle.current_field.id)
      user.pbOwnSide.effects[PBEffects::Tailwind] = 6
      # Start Strong Winds weather
      @battle.pbStartWeather(user, :StrongWinds, true)
    end
    
    return ret
  end
end

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

# Volcanic Eruption System
# Triggered by specific moves and Desolate Land ability
class Battle
  attr_accessor :volcanic_eruption_triggered
  
  alias volcanictop_eruption_pbEndOfRoundPhase pbEndOfRoundPhase
  
  def pbEndOfRoundPhase
    volcanictop_eruption_pbEndOfRoundPhase
    
    # Check for Desolate Land triggering eruption
    if has_field? && VOLCANIC_TOP_IDS.include?(current_field.id)
      allBattlers.each do |battler|
        if battler.hasActiveAbility?(:DESOLATELAND) && field.weather == :HarshSun
          trigger_volcanic_eruption
          break
        end
      end
    end
  end
  
  def trigger_volcanic_eruption
    return unless has_field? && VOLCANIC_TOP_IDS.include?(current_field.id)
    
    pbDisplay(_INTL("The volcano erupted!"))
    
    # Deal damage to all Pokemon based on Fire effectiveness
    allBattlers.each do |battler|
      next if battler.fainted?
      
      # Check immunities
      next if battler.pbHasType?(:FIRE)
      next if battler.hasActiveAbility?([:MAGMAARMOR, :FLASHFIRE, :FLAREBOOST, :BLAZE, :FLAMEBODY,
                                          :SOLIDROCK, :STURDY, :BATTLEARMOR, :SHELLARMOR, :WATERBUBBLE,
                                          :MAGICGUARD, :WONDERGUARD, :PRISMARMOR])
      next if battler.effects[PBEffects::AquaRing]
      next if battler.pbOwnSide.effects[PBEffects::WideGuard]
      
      # Calculate damage based on Fire effectiveness
      effectiveness = Effectiveness.calculate(:FIRE, battler.pbTypes(true))
      damage_fraction = 16  # Default neutral (1/16 = 6.25%)
      
      if Effectiveness.super_effective?(effectiveness)
        damage_fraction = 4   # Weak to Fire (1/4 = 25%)
      elsif Effectiveness.not_very_effective?(effectiveness)
        damage_fraction = 16  # Resistant (1/16 = 6.25%)
      else
        damage_fraction = 8   # Neutral (1/8 = 12.5%)
      end
      
      # Double damage for Tar Shot
      damage_fraction /= 2 if battler.effects[PBEffects::TarShot]
      
      damage = (battler.totalhp / damage_fraction).round
      battler.pbReduceHP(damage, false)
      pbDisplay(_INTL("{1} was damaged by the eruption!", battler.pbThis))
      
      # Wake up sleeping Pokemon (unless Soundproof)
      if battler.status == :SLEEP && !battler.hasActiveAbility?(:SOUNDPROOF)
        battler.pbCureStatus(false)
        pbDisplay(_INTL("{1} woke up!", battler.pbThis))
      end
    end
    
    # Clear hazards and Leech Seed
    eachSide do |side|
      side.effects[PBEffects::StealthRock] = false
      side.effects[PBEffects::Spikes] = 0
      side.effects[PBEffects::ToxicSpikes] = 0
      side.effects[PBEffects::StickyWeb] = false
    end
    allBattlers.each do |battler|
      battler.effects[PBEffects::LeechSeed] = -1
    end
    pbDisplay(_INTL("The eruption cleared the field!"))
    
    # Trigger post-eruption ability effects
    allBattlers.each do |battler|
      next if battler.fainted?
      
      # Magma Armor - Raise Defense and Special Defense
      if battler.hasActiveAbility?(:MAGMAARMOR)
        battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)
        battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler)
      end
      
      # Flare Boost - Raise Special Attack
      if battler.hasActiveAbility?(:FLAREBOOST)
        battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, battler)
      end
      
      # Flash Fire - Activate
      if battler.hasActiveAbility?(:FLASHFIRE) && !battler.effects[PBEffects::FlashFire]
        pbShowAbilitySplash(battler)
        battler.effects[PBEffects::FlashFire] = true
        pbDisplay(_INTL("{1} is being boosted by the eruption!", battler.pbThis))
        pbHideAbilitySplash(battler)
      end
      
      # Blaze - Already passive, just show message
      if battler.hasActiveAbility?(:BLAZE) && !@blaze_eruption_shown
        pbShowAbilitySplash(battler)
        pbDisplay(_INTL("{1}'s Blaze is activated by the heat!", battler.pbThis))
        pbHideAbilitySplash(battler)
        @blaze_eruption_shown = true
      end
    end
  end
end

# Hook eruption trigger into specific moves
class Battle::Move
  alias volcanictop_pbEffectAfterAllHits pbEffectAfterAllHits
  
  def pbEffectAfterAllHits(user, target)
    volcanictop_pbEffectAfterAllHits(user, target)
    
    # Check if this move triggers eruption on Volcanic Top
    if @battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(@battle.current_field.id) &&
       [:BULLDOZE, :EARTHQUAKE, :MAGNITUDE, :ERUPTION, :PRECIPICEBLADES, 
        :LAVAPLUME, :EARTHPOWER, :FEVERPITCH, :MAGMADRIFT].include?(@id)
      @battle.trigger_volcanic_eruption
    end
  end
end

#===============================================================================
# 20. MISTY TERRAIN MECHANICS
# Hardcoded ability and move effects specific to Misty Terrain
#===============================================================================

MISTY_TERRAIN_IDS = %i[misty].freeze

# Fairy-type Sp.Def 1.5x - This is a field effect, not an ability
# Hook into damage calculation for all Fairy-types on Misty Terrain
class Battle::Move
  alias misty_fairy_spdef_pbCalcDamageMultipliers pbCalcDamageMultipliers
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    misty_fairy_spdef_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    
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
  proc { |ability, user, target, move, mults, baseDmg, type|
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
    battler.pbRecoverHP(battler.totalhp / 16)
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
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !target.battle.has_field? || !MISTY_TERRAIN_IDS.include?(target.battle.current_field.id)
    next if type != :POISON
    mults[:final_damage_multiplier] /= 2.0
  }
)

# Soul Heart - Additionally boosts Sp.Def on use
# Soul Heart triggers when any Pokemon faints
# In v21.1, we need to hook the faint event differently
# Soul Heart base effect already exists, we just need to add Sp.Def boost
# Hook into the general faint handling
class Battle::Battler
  alias misty_soulheart_pbFaint pbFaint
  
  def pbFaint(showMessage = true)
    # Store if any battlers have Soul Heart before fainting
    soulheart_battlers = []
    if @battle.has_field? && MISTY_TERRAIN_IDS.include?(@battle.current_field.id)
      @battle.allBattlers.each do |b|
        next if b.fainted? || b.index == @index
        soulheart_battlers << b if b.hasActiveAbility?(:SOULHEART)
      end
    end
    
    # Call original faint (this triggers Soul Heart's Sp.Atk boost)
    ret = misty_soulheart_pbFaint(showMessage)
    
    # On Misty Terrain, also boost Sp.Def for Soul Heart users
    soulheart_battlers.each do |battler|
      next if battler.fainted?
      next unless battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler, false)
    end
    
    return ret
  end
end

# Wish - Restores 75% instead of 50% on Misty Terrain
# Hook into battler's wish healing
class Battle::Battler
  alias misty_wish_pbRecoverHP pbRecoverHP
  
  def pbRecoverHP(amt, anim = true)
    # Check if this is Wish healing on Misty Terrain
    if @effects[PBEffects::Wish] > 0 &&
       @battle.has_field? && 
       MISTY_TERRAIN_IDS.include?(@battle.current_field.id)
      # Wish heals 50% normally, boost to 75%
      # So multiply by 1.5
      amt = (amt * 1.5).round
    end
    
    misty_wish_pbRecoverHP(amt, anim)
  end
end

# Aqua Ring - Restores 1/8 instead of 1/16 on Misty Terrain
# Chain onto the Grassy Terrain EOR hook
class Battle
  alias misty_aquaring_pbEndOfRoundPhase pbEndOfRoundPhase
  
  def pbEndOfRoundPhase
    # Call previous in chain (could be grassy_ingrain_pbEndOfRoundPhase)
    misty_aquaring_pbEndOfRoundPhase
    return unless has_field? && MISTY_TERRAIN_IDS.include?(current_field.id)
    
    # Aqua Ring normally heals 1/16, boost to 1/8
    # Base healing already happened, so add extra 1/16
    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::AquaRing]
      next if battler.hp == battler.totalhp
      
      extra_heal = battler.totalhp / 16
      battler.pbRecoverHP(extra_heal)
    end
  end
end

#===============================================================================
# 19. GRASSY TERRAIN MECHANICS
# Hardcoded ability and move effects specific to Grassy Terrain
#===============================================================================

GRASSY_TERRAIN_IDS = %i[grassy].freeze

# Grass Pelt - Defense 1.5x
Battle::AbilityEffects::DamageCalcFromTarget.add(:GRASSPELT,
  proc { |ability, user, target, move, mults, baseDmg, type|
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
  proc { |ability, user, target, move, mults, baseDmg, type|
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
    battler.pbRecoverHP(battler.totalhp / 16)
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

# Drain moves - Heal 75% of damage dealt on Grassy Terrain
# Hook into drain move healing
GRASSY_DRAIN_MOVES = [:ABSORB, :MEGADRAIN, :GIGADRAIN, :HORNLEECH, :DRAININGKISS, :DRAINPUNCH, :LEECHLIFE, :OBLIVIONWING, :PARABOLICCHARGE].freeze

class Battle::Move
  alias grassy_pbEffectAgainstTarget pbEffectAgainstTarget
  
  def pbEffectAgainstTarget(user, target)
    ret = grassy_pbEffectAgainstTarget(user, target)
    
    # Check if this is a drain move on Grassy Terrain
    if GRASSY_DRAIN_MOVES.include?(@id) && 
       @battle.has_field? && 
       GRASSY_TERRAIN_IDS.include?(@battle.current_field.id)
      # Drain moves normally heal 50% - boost to 75%
      # The base healing already happened, so add extra 25%
      if user.damageState.hpLost > 0
        extra_heal = (user.damageState.hpLost / 4.0).round
        user.pbRecoverHP(extra_heal) if extra_heal > 0
      end
    end
    
    return ret
  end
end

# Floral Healing and Synthesis - Restore 75% on Grassy Terrain
# Hook into the move's healing calculation
# These moves have function code "HealTargetDependingOnWeather"
class Battle::Move
  alias grassy_healing_pbMoveFailed? pbMoveFailed?
  
  def pbMoveFailed?(user, targets)
    ret = grassy_healing_pbMoveFailed?(user, targets)
    
    # Store for healing amount calculation if this is Synthesis/Floral Healing
    if [:SYNTHESIS, :FLORALHEALING, :MORNINGSUN, :MOONLIGHT].include?(@id) &&
       @battle.has_field? && 
       GRASSY_TERRAIN_IDS.include?(@battle.current_field.id)
      @grassy_terrain_75_heal = true
    end
    
    return ret
  end
end

# Hook the actual healing
class Battle::Battler
  alias grassy_healing_pbRecoverHP pbRecoverHP
  
  def pbRecoverHP(amt, anim = true)
    # Check if this is a Grassy Terrain boosted heal
    # This is triggered during Synthesis/Floral Healing execution
    if @battle.respond_to?(:pbGetMoveIndexFromID)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move && 
         [:SYNTHESIS, :FLORALHEALING, :MORNINGSUN, :MOONLIGHT].include?(current_move.id) &&
         @battle.has_field? && 
         GRASSY_TERRAIN_IDS.include?(@battle.current_field.id)
        # Change heal to 75%
        amt = (@totalhp * 3 / 4.0).round
      end
    end
    
    grassy_healing_pbRecoverHP(amt, anim)
  end
end

# Leech Seed - Recovery increased by 30% on Grassy Terrain
class Battle
  alias grassy_pbEndOfRoundPhase pbEndOfRoundPhase
  
  def pbEndOfRoundPhase
    # Store if on grassy terrain for Leech Seed check
    @grassy_leech_seed_boost = has_field? && GRASSY_TERRAIN_IDS.include?(current_field.id)
    grassy_pbEndOfRoundPhase
    @grassy_leech_seed_boost = nil
  end
end

class Battle::Battler
  alias grassy_pbReduceHP pbReduceHP
  
  def pbReduceHP(amt, anim = false, registerDamage = true, anyAnim = true)
    # Check if this is Leech Seed damage with grassy boost
    if @battle.instance_variable_get(:@grassy_leech_seed_boost) && 
       @effects[PBEffects::LeechSeed] >= 0
      # Boost damage by 30%
      amt = (amt * 1.3).round
    end
    grassy_pbReduceHP(amt, anim, registerDamage, anyAnim)
  end
end

# Grassy Glide - +1 priority on Grassy Terrain
class Battle::Move::HigherPriorityInGrassyTerrain
  alias grassy_pbPriority pbPriority
  
  def pbPriority(user)
    ret = grassy_pbPriority(user)
    # On Grassy Terrain (our field), get +1 priority
    if @battle.has_field? && GRASSY_TERRAIN_IDS.include?(@battle.current_field.id) && user.grounded?
      ret += 1
    end
    return ret
  end
end

# Nature's Madness - Deals 75% HP damage on Grassy Terrain
class Battle::Move::LowerTargetHPToUserHP
  alias grassy_pbFailsAgainstTarget? pbFailsAgainstTarget?
  
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = grassy_pbFailsAgainstTarget?(user, target, show_message)
    # Store for damage calculation
    @grassy_terrain_boost = @battle.has_field? && GRASSY_TERRAIN_IDS.include?(@battle.current_field.id)
    return ret
  end
  
  alias grassy_pbEffectAgainstTarget pbEffectAgainstTarget
  
  def pbEffectAgainstTarget(user, target)
    if @grassy_terrain_boost
      # Deal 75% HP damage instead of 50%
      dmg = (target.hp * 3 / 4.0).round
      target.pbReduceHP(dmg, false)
      return
    end
    grassy_pbEffectAgainstTarget(user, target)
  end
end

# Snap Trap - Deals 1/6 HP damage per turn on Grassy Terrain
# This is handled by PBEffects::Trapping - needs to check in EOR damage
class Battle
  alias grassy_trap_pbEndOfRoundPhase pbEndOfRoundPhase
  
  def pbEndOfRoundPhase
    grassy_trap_pbEndOfRoundPhase
    return unless has_field? && GRASSY_TERRAIN_IDS.include?(current_field.id)
    
    # Check for Snap Trap - boost damage from 1/8 to 1/6
    # This already ran in the original EOR, so we apply extra damage
    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Trapping] > 0
      
      trapping_move = nil
      if PBEffects.const_defined?(:TrappingMove)
        trapping_move = battler.effects[PBEffects::TrappingMove]
      end
      next unless trapping_move == :SNAPTRAP
      
      # Normal trap damage is 1/8, we want 1/6 total
      # So add extra (1/6 - 1/8) = 1/24
      extra_dmg = battler.totalhp / 24
      battler.pbReduceHP(extra_dmg, false) if extra_dmg > 0
    end
  end
end

# Ingrain - Heals 1/8 instead of 1/16 on Grassy Terrain
class Battle
  alias grassy_ingrain_pbEndOfRoundPhase pbEndOfRoundPhase
  
  def pbEndOfRoundPhase
    grassy_ingrain_pbEndOfRoundPhase
    return unless has_field? && GRASSY_TERRAIN_IDS.include?(current_field.id)
    
    # Ingrain normally heals 1/16, boost to 1/8
    # Base healing already happened, so add extra 1/16
    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Ingrain]
      next if battler.hp == battler.totalhp
      
      extra_heal = battler.totalhp / 16
      battler.pbRecoverHP(extra_heal)
    end
  end
end

# NOTE: Desolate Land field transition needs to be in abilityFieldChange or similar system

#===============================================================================
# 18. ELECTRIC TERRAIN MECHANICS
# Hardcoded ability effects specific to Electric Terrain
#===============================================================================

ELECTRIC_TERRAIN_IDS = %i[electerrain].freeze

# Plus - Special Attack 1.5x (even without Minus present)
# In v21.1, stat boosts are applied in damage calculation
Battle::AbilityEffects::DamageCalcFromUser.add(:PLUS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !user.battle.has_field? || !ELECTRIC_TERRAIN_IDS.include?(user.battle.current_field.id)
    next if !move.specialMove?(type)
    mults[:attack_multiplier] *= 1.5
  }
)

# Minus - Special Attack 1.5x (even without Plus present)
Battle::AbilityEffects::DamageCalcFromUser.add(:MINUS,
  proc { |ability, user, target, move, mults, baseDmg, type|
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
    battler.pbRecoverHP(battler.totalhp / 16)
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

# Teravolt - Electric moves deal neutral damage to Ground-types on Electric Terrain
# Hook into damage calculation
class Battle::Move
  alias electric_teravolt_pbCalcDamageMultipliers pbCalcDamageMultipliers
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    electric_teravolt_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    
    # Teravolt makes Electric moves neutral to Ground on Electric Terrain
    if user.hasActiveAbility?(:TERAVOLT) &&
       type == :ELECTRIC &&
       target.pbHasType?(:GROUND) &&
       @battle.has_field? &&
       ELECTRIC_TERRAIN_IDS.include?(@battle.current_field.id)
      # Override the 0x Ground immunity to be 1x neutral
      multipliers[:base_damage_multiplier] *= 2  # Counteract the 0.5x from immunity
    end
  end
end

# Transistor - Reduces Ground-type move damage by 0.5x
Battle::AbilityEffects::DamageCalcFromTarget.add(:TRANSISTOR,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !ELECTRIC_TERRAIN_IDS.include?(target.battle.current_field.id)
    if type == :GROUND
      mults[:final_damage_multiplier] /= 2.0
    end
  }
)

#===============================================================================
# 17. CAVE FIELD MECHANICS
# Ground moves hit airborne Pokemon
# Stealth Rock damage doubled (needs manual implementation)
#===============================================================================

# Ground-type moves can hit airborne Pokemon on cave field
# Hook into type effectiveness calculation
class Battle::Move
  alias cave_ground_pbCalcTypeMod pbCalcTypeMod
  
  def pbCalcTypeMod(moveType, user, target)
    # Call original first
    typeMod = cave_ground_pbCalcTypeMod(moveType, user, target)
    
    # On cave field, Ground moves ignore Flying immunity from being airborne
    if moveType == :GROUND && 
       @battle.has_field? && 
       @battle.current_field.id == :cave &&
       target.airborne?
      
      field_data = @battle.current_field
      if field_data.respond_to?(:ground_hits_airborne) && field_data.ground_hits_airborne
        # Recalculate type effectiveness ignoring the airborne immunity
        # Just calculate based on actual types
        typeMod = Effectiveness::NORMAL_EFFECTIVE_ONE
        if target.pbHasType?(:FLYING)
          typeMod = Effectiveness.calculate(moveType, :FLYING)
        end
        target.pbTypes(true).each do |type|
          next if type == :FLYING  # Already handled
          mod = Effectiveness.calculate(moveType, type)
          typeMod *= mod
        end
      end
    end
    
    return typeMod
  end
end

# NOTE: Stealth Rock doubled damage (:hazardMultiplier key) needs manual implementation
# in the base game's entry hazard damage code (Battle::Battler#pbCheckEntryHazards or similar)
# by checking if @battle.has_field? && @battle.current_field.hazard_multiplier[:StealthRock]

#===============================================================================
# 16. WEATHER-BASED FIELD TRANSITIONS
# Fields can transition to other fields based on active weather at end of round
#===============================================================================

class Battle
  alias weather_field_change_pbEOREndWeather pbEOREndWeather
  
  def pbEOREndWeather(priority)
    # Call original first
    weather_field_change_pbEOREndWeather(priority)
    
    # Check for weather-based field transitions
    return unless has_field?
    field_data = current_field
    return unless field_data.respond_to?(:weather_field_change)
    return unless field_data.weather_field_change && field_data.weather_field_change.any?
    
    current_weather = @field.weather
    return if current_weather == :None
    
    # Check each potential field transition
    field_data.weather_field_change.each do |new_field, config|
      weather_list = config[:weather] || []
      next unless weather_list.include?(current_weather)
      
      # Get the message for this specific weather
      messages = config[:messages] || {}
      message = messages[current_weather]
      
      # Trigger field change
      pbDisplay(message) if message
      pbChangeBattleField(new_field, message.nil?)
      
      if $DEBUG
        Console.echo_li("[WEATHER FIELD CHANGE] #{current_weather} changed #{field_data.name} -> #{new_field}")
      end
      
      break # Only one transition per turn
    end
  end
end

#===============================================================================
# 15. WEATHER DURATION EXTENSION
# Allows fields to extend the duration of specific weather types
# Compatible with both base game weather and custom weather plugin
#===============================================================================

# Hook into Battle#pbStartWeather to extend weather duration based on field
class Battle
  alias field_weather_duration_pbStartWeather pbStartWeather
  
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnimation = true)
    # Call original method first
    field_weather_duration_pbStartWeather(user, newWeather, fixedDuration, showAnimation)
    
    # Check if field extends duration for this weather
    return unless has_field?
    
    # Access the field's weather_duration configuration
    # current_field returns the Battle::Field instance which has the config
    field_data = current_field
    return unless field_data.respond_to?(:weather_duration)
    return unless field_data.weather_duration && field_data.weather_duration[newWeather]
    return if @field.weatherDuration <= 0 # Don't extend infinite weather
    
    extended_duration = field_data.weather_duration[newWeather]
    @field.weatherDuration = extended_duration
    
    if $DEBUG
      Console.echo_li("[WEATHER DURATION] #{field_data.name} extended #{newWeather} to #{extended_duration} turns")
    end
  end
end

# Also hook into custom weather plugin's pbStartWeather if it exists
# This ensures compatibility with custom weather from the Repudiation plugin
if defined?(CustomWeather)
  class Battle
    alias field_weather_custom_pbStartWeather customweather_pbStartWeather
    
    def customweather_pbStartWeather(user, newWeather, fixedDuration = false, showAnimation = true)
      # Check if this is a custom weather that we should extend
      should_extend = false
      extended_duration = nil
      
      if has_field?
        field_data = current_field
        if field_data.respond_to?(:weather_duration) && field_data.weather_duration && field_data.weather_duration[newWeather]
          should_extend = true
          extended_duration = field_data.weather_duration[newWeather]
        end
      end
      
      # Call the custom weather version
      field_weather_custom_pbStartWeather(user, newWeather, fixedDuration, showAnimation)
      
      # Apply field extension if applicable
      if should_extend && @field.weatherDuration > 0
        @field.weatherDuration = extended_duration
        if $DEBUG
          Console.echo_li("[WEATHER DURATION] #{current_field.name} extended #{newWeather} to #{extended_duration} turns")
        end
      end
    end
  end
end

#===============================================================================
# 14. BEACH FIELD MOVE EFFECTS
# Hardcoded move behaviour changes specific to the beach field:
#   - Focus Energy:  boosts crit rate by 3 stages instead of 2
#   - Shore Up:      fully restores HP instead of partial heal
#   - Psych Up:      additionally cures the user's status condition
#   - Sand Tomb:     lowers trapped Pokémon's accuracy by 1 each EOR
#===============================================================================

BEACH_FIELD_IDS = %i[beach].freeze

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

# IGNORE ACC/EVA CHANGES - Inner Focus, Own Tempo, Pure Power, Sand Veil, Steadfast
# These abilities make the bearer ignore accuracy/evasion stage changes when attacking,
# unless the target has As One or Unnerve.
BEACH_IGNORE_ACC_EVA_ABILITIES = %i[INNERFOCUS OWNTEMPO PUREPOWER SANDVEIL STEADFAST].freeze
BEACH_BLOCK_IGNORE_ABILITIES   = %i[ASONESINGLESTRIKE ASONERAPIDSTRIKE UNNERVE].freeze

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
  proc { |ability, user, target, move, numHits, battlersHit, damage_state|
    next unless target.battle.has_field? && BEACH_FIELD_IDS.include?(target.battle.current_field.id)
    next unless move.type == :WATER
    next unless target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target, nil)
    target.battle.pbShowAbilitySplash(target)
    target.pbRaiseStatStage(:SPECIAL_DEFENSE, 2, target)
    target.battle.pbDisplay(_INTL("The Beach's waters also boosted {1}'s Special Defense!", target.pbThis))
    target.battle.pbHideAbilitySplash(target)
  }
)

# FOCUS ENERGY - +3 crit stages instead of +2
# Focus Energy's function class sets FocusEnergy to 2.
# We intercept pbEffectGeneral (where the effect is applied) and boost to 3.
class Battle::Move::RaiseUserCriticalHitRate2
  alias beach_focus_energy_pbEffectGeneral pbEffectGeneral

  def pbEffectGeneral(user)
    beach_focus_energy_pbEffectGeneral(user)
    return unless @battle.has_field? && BEACH_FIELD_IDS.include?(@battle.current_field.id)
    # Base effect sets to 2; bump to 3
    user.effects[PBEffects::FocusEnergy] = 3
    @battle.pbDisplay(_INTL("The Beach's focus sharpened {1}'s concentration further!", user.pbThis))
  end
end

# SHORE UP - Full HP restore instead of partial
# Shore Up's function code is "HealUserDependingOnSandstorm".
# We override pbEffectGeneral to fully restore HP on beach field.
class Battle::Move::HealUserDependingOnSandstorm
  alias beach_shore_up_pbEffectGeneral pbEffectGeneral

  def pbEffectGeneral(user)
    return beach_shore_up_pbEffectGeneral(user) unless @battle.has_field? && BEACH_FIELD_IDS.include?(@battle.current_field.id)
    return unless id == :SHOREUP
    return unless user.canHeal?
    user.pbRecoverHP(user.totalhp)
    @battle.pbDisplay(_INTL("{1} was fully restored by the Beach!", user.pbThis))
  end
end

# PSYCH UP - Additionally cures user's status
class Battle::Move::UserCopyTargetStatStages
  alias beach_psych_up_pbEffectAgainstTarget pbEffectAgainstTarget

  def pbEffectAgainstTarget(user, target)
    beach_psych_up_pbEffectAgainstTarget(user, target)
    return unless @battle.has_field? && BEACH_FIELD_IDS.include?(@battle.current_field.id)
    return if user.status == :NONE
    old_status = user.status
    user.pbCureStatus(false)
    case old_status
    when :BURN      then @battle.pbDisplay(_INTL("The Beach's calm soothed {1}'s burn!", user.pbThis))
    when :POISON    then @battle.pbDisplay(_INTL("The Beach's calm cured {1}'s poisoning!", user.pbThis))
    when :PARALYSIS then @battle.pbDisplay(_INTL("The Beach's calm cured {1}'s paralysis!", user.pbThis))
    when :SLEEP     then @battle.pbDisplay(_INTL("The Beach's calm woke up {1}!", user.pbThis))
    when :FROZEN    then @battle.pbDisplay(_INTL("The Beach's warmth thawed {1}!", user.pbThis))
    end
  end
end

# SAND TOMB - Lower trapped Pokémon's accuracy by 1 stage each EOR
# Sand Tomb sets PBEffects::Trapping on the target.
# PBEffects::TrappingMove stores which move caused the trap.
# We hook into pbEndOfRoundPhase to apply the accuracy drop after the trap damage.
class Battle
  alias beach_sand_tomb_pbEndOfRoundPhase pbEndOfRoundPhase

  def pbEndOfRoundPhase
    beach_sand_tomb_pbEndOfRoundPhase
    return unless has_field? && BEACH_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Trapping] > 0
      
      # Check if the trapping move is Sand Tomb
      # PBEffects::TrappingMove stores the move symbol in v21.1
      trapping_move = nil
      if PBEffects.const_defined?(:TrappingMove)
        trapping_move = battler.effects[PBEffects::TrappingMove]
      end
      # If we can't confirm the move, skip to avoid affecting other trapping moves
      next unless trapping_move == :SANDTOMB
      
      next unless battler.pbCanLowerStatStage?(:ACCURACY, nil, nil)
      battler.pbLowerStatStage(:ACCURACY, 1, nil)
      Console.echo_li("[BEACH] Sand Tomb lowered #{battler.pbThis}'s accuracy") if $DEBUG
    end
  end
end

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

# SAND SPIT - Lowers all foes' accuracy by 1 stage on activation
# Sand Spit normally summons Sandstorm when hit.
# On beach field it also lowers all foes' accuracy by 1.
Battle::AbilityEffects::OnBeingHit.add(:SANDSPIT,
  proc { |ability, user, target, move, battle|
    battle.pbStartWeatherAbility(:Sandstorm, target)
    if battle.has_field? && BEACH_FIELD_IDS.include?(battle.current_field.id)
      battle.allOtherSideBattlers(target.index).each do |b|
        b.pbLowerStatStageByAbility(:ACCURACY, 1, target, true, true)
      end
    end
  }
)

#===============================================================================
# 13. VOLCANIC FIELD MOVE EFFECTS
# Hardcoded move behaviour changes specific to the volcanic field:
#   - Burn Up: Fire typing is restored at the end of the round
#   - Raging Fury / Outrage / Thrash: Skip post-thrash confusion
#===============================================================================

VOLCANIC_FIELD_IDS = %i[volcanic volcanictop superheated infernal].freeze

# BURN UP - Restore Fire typing at end of round
# Burn Up sets PBEffects::BurnUp = true when it removes the Fire type.
# We restore type1/type2 from species data at EOR and clear the flag.
class Battle
  alias volcanic_move_pbEndOfRoundPhase pbEndOfRoundPhase

  def pbEndOfRoundPhase
    volcanic_move_pbEndOfRoundPhase

    return unless has_field? && VOLCANIC_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::BurnUp]

      poke_data  = GameData::Species.get_species_form(battler.species, battler.form)
      orig_type1 = poke_data.type1
      orig_type2 = poke_data.type2
      next unless orig_type1 == :FIRE || orig_type2 == :FIRE

      battler.effects[PBEffects::BurnUp] = false
      battler.type1 = orig_type1
      battler.type2 = orig_type2

      pbDisplay(_INTL("The Volcanic Field restored {1}'s Fire typing!", battler.pbThis))
      Console.echo_li("[VOLCANIC] Burn Up reset for #{battler.pbThis}") if $DEBUG
    end
  end
end

# RAGING FURY / OUTRAGE / THRASH - No post-thrash confusion on volcanic field
# After the final hit the game calls pbConfuse on the user.
# We intercept it, check if the active move is a thrashing move, and suppress.
class Battle::Battler
  alias volcanic_pbConfuse pbConfuse

  def pbConfuse(msg = nil)
    if @battle.has_field? && VOLCANIC_FIELD_IDS.include?(@battle.current_field.id)
      move = @battle.choices[@index]&.[](2)
      if move && ["AttackAndSkipWithFury", "ThrashingMove"].include?(move.function_code.to_s)
        Console.echo_li("[VOLCANIC] Suppressed confusion for #{pbThis} (#{move.id})") if $DEBUG
        @battle.pbDisplay(_INTL("The volcanic heat kept {1} from getting confused!", pbThis))
        return
      end
    end
    volcanic_pbConfuse(msg)
  end
end


#===============================================================================
# 7. ICY FIELD MECHANICS
#===============================================================================

# Status effect damage multipliers (configured via field data)
# Hook into end of round to modify status damage
Battle::Scene.class_eval do
  alias field_status_pbDamageAnimation pbDamageAnimation
  
  def pbDamageAnimation(battler, effectiveness = 0)
    # Store if this is status damage being animated
    @last_damage_battler = battler
    field_status_pbDamageAnimation(battler, effectiveness)
  end
end

class Battle::Battler
  alias field_status_pbReduceHP pbReduceHP
  
  def pbReduceHP(amt, anim = false, registerDamage = true, anyAnim = true)
    # Check if this is status damage and field modifies it
    if @status != :NONE && @battle.has_field? && @battle.current_field.respond_to?(:status_damage_mods)
      status_mods = @battle.current_field.status_damage_mods
      if status_mods && status_mods[@status]
        multiplier = status_mods[@status]
        # Only modify if this looks like status damage (small amounts)
        if amt > 0 && amt <= @totalhp / 4
          original_amt = amt
          amt = (amt * multiplier).round
          amt = 1 if amt < 1
          
          if $DEBUG && amt != original_amt
            Console.echo_li("[STATUS MOD] #{@status} damage: #{original_amt} -> #{amt} (#{multiplier}x)")
          end
        end
      end
    end
    
    # Call original with potentially modified damage
    field_status_pbReduceHP(amt, anim, registerDamage, anyAnim)
  end
end

# Ice Body - heals 1/16 HP each turn on icy field
Battle::AbilityEffects::EndOfRoundHealing.add(:ICEBODY,
  proc { |ability, battler, battle|
    next if !battle.has_field? || battle.current_field.id != :icy
    next if battler.hp == battler.totalhp
    battle.pbShowAbilitySplash(battler)
    battler.pbRecoverHP(battler.totalhp / 16)
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
  proc { |ability, mults, user, target, move, type|
    if target.battle.has_field? && target.battle.current_field.id == :icy
      mults[:accuracy_multiplier] *= 0.8  # 20% harder to hit (inverse of 1.25 evasion)
    end
  }
)

# Ice-type Defense boost during Hail on Icy field
# Ice-types get 1.5x Defense when Hail/Snow is active
# Hook into damage calculation for the target
class Battle::Move
  alias icy_ice_defense_pbCalcDamageMultipliers pbCalcDamageMultipliers
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    icy_ice_defense_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    
    # Check for icy field + Ice-type + Hail/Snow
    return unless @battle.has_field? && @battle.current_field.id == :icy
    return unless target.pbHasType?(:ICE)
    weather = target.effectiveWeather
    return unless [:Hail, :Snow].include?(weather)
    
    # Boost Defense by 1.5x (equivalent to reducing physical damage)
    if physicalMove?(type)
      multipliers[:final_damage_multiplier] /= 1.5
    end
  end
end

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

# Aurora Veil - Can be used regardless of weather on Icy field
class Battle::Move::StartWeakenDamageAgainstUserSideIfHail
  alias icy_pbMoveFailed? pbMoveFailed?
  
  def pbMoveFailed?(user, targets)
    # On icy field, Aurora Veil always works
    if @battle.has_field? && @battle.current_field.id == :icy
      return false
    end
    
    # Call original (checks for hail/snow)
    return icy_pbMoveFailed?(user, targets)
  end
end

# Earthquake moves create spikes on icy field
class Battle
  def icy_field_spike_layer
    return unless has_field?
    return unless current_field.id == :icy
    
    pbDisplay(_INTL("The quake broke up the ice into spiky pieces!"))
    
    # Add one layer of spikes to both sides
    2.times do |side|
      next if sides[side].effects[PBEffects::Spikes] >= 3
      sides[side].effects[PBEffects::Spikes] += 1
    end
  end
end

class Battle::Move
  alias icy_spike_pbEffectAfterAllHits pbEffectAfterAllHits
  
  def pbEffectAfterAllHits(user, target)
    icy_spike_pbEffectAfterAllHits(user, target)
    
    # Earthquake moves on icy field create spikes
    earthquake_moves = [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, 
                       :TECTONICRAGE]
    
    if earthquake_moves.include?(@id)
      @battle.icy_field_spike_layer
    end
  end
end

# Move stat boosts - configured via field data
# This is registered as a field effect in the Field initialization
class Battle::Field
  def register_move_stat_boosts
    return unless @move_stat_boosts && @move_stat_boosts.any?
    
    @effects[:end_of_move] = proc { |user, targets, move, numHits|
      if $DEBUG
        Console.echo_li("[MOVESTATBOOST] ===== START =====")
        Console.echo_li("[MOVESTATBOOST] Move: #{move.id}")
        Console.echo_li("[MOVESTATBOOST] User: #{user.pbThis} (index: #{user.index})")
      end
      
      # Check each stat boost configuration
      @move_stat_boosts.each_with_index do |config, index|
        if $DEBUG
          Console.echo_li("[MOVESTATBOOST] --- Config #{index} ---")
        end
        
        # Check if this move qualifies
        qualifies = check_move_stat_boost_qualification(user, move, config)
        
        if $DEBUG
          Console.echo_li("[MOVESTATBOOST] Qualifies? #{qualifies}")
        end
        
        next unless qualifies
        
        # Apply the stat boost TO THE USER
        stat = config[:stat]
        stages = config[:stages] || 1
        message = config[:message]
        
        if $DEBUG
          Console.echo_li("[MOVESTATBOOST] >>> BOOSTING USER: #{user.pbThis} <<<")
          Console.echo_li("[MOVESTATBOOST] >>> Stat: #{stat}, Stages: #{stages} <<<")
        end
        
        if user.pbCanRaiseStatStage?(stat, user, move)
          user.pbRaiseStatStage(stat, stages, user)
          if message
            @battle.pbDisplay(message.gsub("{1}", user.pbThis))
          end
          if $DEBUG
            Console.echo_li("[MOVESTATBOOST] ✓ SUCCESS: #{user.pbThis}'s #{stat} raised!")
          end
        else
          if $DEBUG
            Console.echo_li("[MOVESTATBOOST] ✗ FAILED: Cannot raise #{user.pbThis}'s #{stat}")
          end
        end
      end
      
      if $DEBUG
        Console.echo_li("[MOVESTATBOOST] ===== END =====")
      end
    }
  end
  
  def check_move_stat_boost_qualification(user, move, config)
    # Check grounded requirement
    if config[:grounded]
      is_grounded = !user.airborne?
      if $DEBUG
        Console.echo_li("[MOVESTATBOOST] Grounded required: true, User grounded: #{is_grounded}")
      end
      return false unless is_grounded
    end
    
    # Check specific moves
    if config[:moves] && config[:moves].any?
      has_move = config[:moves].include?(move.id)
      if $DEBUG
        Console.echo_li("[MOVESTATBOOST] Specific moves: #{config[:moves].inspect}, Move #{move.id} included: #{has_move}")
      end
      return true if has_move
    end
    
    # Check conditions
    conditions = config[:conditions] || []
    
    if $DEBUG
      Console.echo_li("[MOVESTATBOOST] Conditions to check: #{conditions.inspect}")
    end
    
    conditions.each do |condition|
      result = true
      case condition
      when :physical
        result = move.physicalMove?
      when :special
        result = move.specialMove?
      when :contact
        result = move.pbContactMove?(user)
      when :priority
        result = move.priority > 0
      when :sound
        result = move.soundMove?
      when :punching
        result = move.punchingMove?
      when :biting
        result = move.bitingMove?
      when :slicing
        result = move.slicingMove?
      when :wind
        result = move.windMove?
      when :pulse
        result = move.pulseMove?
      when :ballistic
        result = move.ballMove?
      end
      
      if $DEBUG
        Console.echo_li("[MOVESTATBOOST]   :#{condition} - #{result}")
      end
      
      return false unless result
    end
    
    if $DEBUG
      Console.echo_li("[MOVESTATBOOST] All conditions passed!")
    end
    
    return true
  end
end

#===============================================================================
# EXAMPLE USAGE IN FIELD DATA
#===============================================================================
# :CAVE => {
#   :damageMods => {
#     0 => [:SKYDROP],  # Move fails
#   },
#   :moveMessages => {
#     "The cave's low ceiling makes flying high impossible!" => [:SKYDROP],
#   },
#   :noCharging => [:BOUNCE, :FLY],  # Skip charging turn - attack immediately
#   :noChargingMessages => {
#     :FLY => "The cave's low ceiling makes flying high impossible!",
#     :BOUNCE => "The cave's low ceiling prevents a high bounce!",
#   },
#   :abilityMods => {
#     :PUNKROCK => { multiplier: 1.5 },  # Field-modified ability boost
#   },
#   :soundBoost => {
#     multiplier: 1.5,
#     message: "The cave echoed the sound!"
#   },
#   :mimicry => :ROCK,  # Mimicry ability becomes Rock type
# }
#
# :ICY => {
#   :name => "Icy Field",
#   :fieldMessage => ["The field is covered in ice!"],
#   :mimicry => :ICE,
#   :abilityMods => {
#     :REFRIGERATE => { multiplier: 1.5 },
#   },
#   :statusDamageMods => {
#     :BURN => 0.5,
#   },
#   :moveStatBoosts => [
#     {
#       grounded: true,
#       conditions: [:physical, :contact, :priority],
#       stat: :SPEED,
#       stages: 1,
#       message: "{1} gained momentum on the ice!"
#     }
#   ],
# }
#
# :VOLCANIC => {
#   :blockedStatuses => [:FROZEN],
#   :blockedWeather => [:Hail, :Snow],
#   :abilityStatBoosts => {
#     :MAGMAARMOR => { stat: :DEFENSE, stages: 1, message: "{1}'s Magma Armor hardened its body!" }
#   },
#   :abilityFormChanges => {
#     :EISCUE => {
#       :ICEFACE => { form: 1, show_ability: true, message: "{1}'s Ice Face melted!" }
#     }
#   },
#   :healthChanges => [
#     {
#       grounded: true,
#       exclude_types: [:FIRE],
#       healing: false,
#       damage_type: :FIRE,
#       amount: 1/8.0,
#       message: "{1} was hurt by the {2}!",
#       immune_abilities: [:FLAMEBODY, :FLAREBOOST, :FLASHFIRE, :HEATPROOF, 
#                         :MAGMAARMOR, :WATERBUBBLE, :WATERVEIL],
#       immune_effects: [PBEffects::AquaRing],
#       multiplier_abilities: {
#         :FLUFFY => 2.0,
#         :GRASSPELT => 2.0,
#         :ICEBODY => 2.0,
#         :LEAFGUARD => 2.0
#       },
#       multiplier_effects: {
#         PBEffects::TarShot => 2.0
#       }
#     }
#   ],
# }
#
# ABILITY FORM CHANGES:
# :abilityFormChanges => {
#   :EISCUE => {
#     :ICEFACE => { form: 1, show_ability: true, message: "{1}'s Ice Face melted!" }
#   },
#   :DARMANITAN => {
#     :ZENMODE => { form: 1, message: "{1} entered Zen Mode!" }
#   }
# }
# - Triggers when Pokémon with the ability/species enters the field
# - form: New form number (0 = base form, 1 = alt form, etc.)
# - show_ability: true/false - Show ability splash animation
# - message: Transformation message (use {1} for Pokémon name)
#
# ABILITY STAT BOOSTS:
# :abilityStatBoosts => {
#   :MAGMAARMOR => { stat: :DEFENSE, stages: 1, message: "..." },
#   :FLASHFIRE => { stat: :SPECIAL_ATTACK, stages: 2 }  # Uses default message
# }
# - Triggers when Pokémon with the ability enters (switch-in or start of battle)
# - stat: :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :EVASION, :ACCURACY
# - stages: Number of stages to boost (default 1)
# - message: Optional custom message (use {1} for Pokémon, {2} for field name)
#
# ABILITY ACTIVATION:
# Hooks into the existing apply_field_effect(:ability_activation) system.
# Abilities in this list are treated as "always active" on this field.
#
# Simple array (just passive activation - uses existing ability logic):
# :abilityActivate => [:BLAZE, :FLAREBOOST, :FLASHFIRE]
#
# Hash with config (for EOR effects):
# :abilityActivate => {
#   :BLAZE      => {},                          # Passive: existing Blaze logic applies
#   :FLAREBOOST => {},                          # Passive: existing Flare Boost logic applies
#   :FLASHFIRE  => { eor: true, grounded: true } # EOR: activates Flash Fire at end of turn
# }
# - eor: true - Run effect at end of each round
# - grounded: true - Only applies if battler is grounded
#
# Built-in EOR handlers: :FLASHFIRE
# Any ability without a built-in handler will just appear in @ability_activation
# which is checked by existing ability procs via:
#   battle.apply_field_effect(:ability_activation, ...).include?(ability)
#
#
# :GRASSY => {
#   :healthChanges => [
#     {
#       grounded: true,
#       healing: true,
#       amount: 1/16.0,
#       message: "{1}'s HP was restored by the {2}!"
#     }
#   ],
# }
#
# HEALTH CHANGES OPTIONS:
# - grounded: true/false - Must be grounded
# - types: [:FIRE, :WATER] - Must have one of these types
# - exclude_types: [:FIRE] - Must NOT have these types
# - healing: true/false - true = heal, false = damage
# - damage_type: :FIRE - Type for effectiveness calculation (damage only)
# - amount: 1/8.0 - Fraction of max HP (use decimals: 1/8.0, 1/16.0)
# - message: "Text" - Use {1} for Pokémon name, {2} for field name
# - immune_abilities: [:FLAMEBODY, ...] - Abilities that prevent damage/healing
# - immune_effects: [PBEffects::AquaRing, ...] - Effects that prevent damage/healing
# - multiplier_abilities: { :FLUFFY => 2.0 } - Abilities that multiply damage (damage only)
# - multiplier_effects: { PBEffects::TarShot => 2.0 } - Effects that multiply damage (damage only)
#
#
# BLOCKED STATUSES:
# - :FROZEN, :BURN, :PARALYSIS, :POISON, :SLEEP, :CONFUSED
#
# BLOCKED WEATHER:
# - :Sun, :HarshSun - Sunny weather
# - :Rain, :HeavyRain - Rainy weather
# - :Sandstorm - Sandstorm
# - :Hail, :Snow - Hail/Snow weather
#
#
# HOW NO CHARGING WORKS:
# Turn 1 (with :noCharging):
#   1. Shows charging animation (Pidgeot flies up)
#   2. Shows charging message ("Pidgeot flew up high!")
#   3. Shows custom field message ("The cave's low ceiling makes flying high impossible!")
#   4. Immediately attacks the target
#   5. All in the SAME turn
#
# Without :noCharging:
#   Turn 1: "Pidgeot flew up high!"
#   Turn 2: Pidgeot attacks
#===============================================================================
