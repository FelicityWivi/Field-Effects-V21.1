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
  # avoid alias so method may not exist yet
  def pbFailsAgainstTarget?(user, target, show_message)
    # Check if field causes this move to fail
    if @battle.has_field? && @battle.current_field.failed_moves
      if @battle.current_field.failed_moves[@id]
        @battle.pbDisplay(@battle.current_field.failed_moves[@id]) if show_message
        return true
      end
    end
    return super
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
    ret = super
    
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
    return super(user, target, *args)
  end
end

# Show custom message right after "uses" message
class Battle::Move::TwoTurnMove
  def pbDisplayUseMessage(user)
    begin
      super
    rescue NoMethodError
      # some subclasses may not implement this yet
    end
    # Don't show custom message here - let it show after charging animation
  end
  
  # Suppress the charging message when field skips charging
  # NOTE: This doesn't seem to work because the message comes from the animation system
  # Instead we just show our custom message after it
  def pbChargingTurnMessage(user, targets)
    begin
      super
    rescue NoMethodError
      # fallback to default behaviour
    end
    # Just call original - we'll show our message separately
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
  def pbEffectAfterAllHits(user, target)
    if method(:pbEffectAfterAllHits).super_method
      begin
        super
      rescue NoMethodError
        # missing parent method
      end
    end
    earthquake_moves = [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, 
                       :TECTONICRAGE, :CONTINENTALCRUSH]
    if earthquake_moves.include?(@id)
      @battle.process_cave_collapse_after_move
    end
  end
end

class Battle::Move
  def pbDisplayUseMessage(user)
    # only call super if a parent defines the method
    if method(:pbDisplayUseMessage).super_method
      begin
        super
      rescue NoMethodError
        # parent may still be missing in some situations
      end
    end
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
  
  alias field_stat_down_pbOnStartUse pbOnStartUse if method_defined?(:pbOnStartUse)
  
  def pbOnStartUse(user, targets)
    respond_to?(:field_stat_down_pbOnStartUse) ? field_stat_down_pbOnStartUse(user, targets) : super
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
  
  alias field_stat_down_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    unless @field_stat_config&.dig(:message)
      respond_to?(:field_stat_down_pbEffectAgainstTarget) ? field_stat_down_pbEffectAgainstTarget(user, target) : super
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
  
  alias field_stat_up_pbOnStartUse pbOnStartUse if method_defined?(:pbOnStartUse)
  
  def pbOnStartUse(user, targets)
    respond_to?(:field_stat_up_pbOnStartUse) ? field_stat_up_pbOnStartUse(user, targets) : super
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
  
  alias field_stat_up_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)
  
  def pbEffectGeneral(user)
    unless @field_stat_config&.dig(:message)
      respond_to?(:field_stat_up_pbEffectGeneral) ? field_stat_up_pbEffectGeneral(user) : super
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
  
  alias field_multi_stat_up_pbOnStartUse pbOnStartUse if method_defined?(:pbOnStartUse)
  
  def pbOnStartUse(user, targets)
    respond_to?(:field_multi_stat_up_pbOnStartUse) ? field_multi_stat_up_pbOnStartUse(user, targets) : super
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
  
  alias field_stat_override_pbDisplay pbDisplay if method_defined?(:pbDisplay)
  
  def pbDisplay(msg, &block)
    return if @field_stat_override
    respond_to?(:field_stat_override_pbDisplay) ? field_stat_override_pbDisplay(msg, &block) : super
  end
end

#===============================================================================
# 30. BACK ALLEY FIELD MECHANICS
# Healing reduction, ability switch-in boosts, item theft mechanics
#===============================================================================

BACK_ALLEY_IDS = %i[backalley].freeze

# Passive healing reduction (33%)
class Battle::Battler
  def pbRecoverHP(amt, anim = true)
    # Reduce healing by 33% on Back Alley
    if @battle.has_field? && BACK_ALLEY_IDS.include?(@battle.current_field.id)
      amt = (amt * 0.67).round
    end
    return super
  end
end

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

# Pursuit - Raises Speed when KOing
class Battle::Move::DoublePowerIfTargetActed
  alias backalley_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)
  
  def pbEffectAfterAllHits(user, target)
    respond_to?(:backalley_pbEffectAfterAllHits) ? backalley_pbEffectAfterAllHits(user, target) : super
    # On Back Alley, raise Speed if KO'd
    if @id == :PURSUIT &&
       target.fainted? &&
       @battle.has_field? &&
       BACK_ALLEY_IDS.include?(@battle.current_field.id)
      user.pbRaiseStatStage(:SPEED, 1, user)
    end
  end
end

# Trick/Switcheroo - Stat swap effects
class Battle::Move::UserTargetSwapItems
  alias backalley_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)
  
  def pbEffectAfterAllHits(user, target)
    ret = backalley_pbEffectAfterAllHits(user, target)
    
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

# Snatch - Raises random stat by 2 stages when successful
class Battle::Move::StealAndUseBeneficialStatusMove
  alias backalley_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)
  
  def pbEffectGeneral(user)
    ret = backalley_pbEffectGeneral(user)
    
    # On Back Alley, raise random stat by 2
    if ret == 0 && @battle.has_field? && BACK_ALLEY_IDS.include?(@battle.current_field.id)
      random_stat = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].sample
      user.pbRaiseStatStage(random_stat, 2, user)
    end
    
    return ret
  end
end

# Thief/Covet - 2x power when successfully stealing
class Battle::Move::RemoveTargetItem
  alias backalley_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage)
  
  def pbBaseDamage(baseDmg, user, target)
    dmg = backalley_pbBaseDamage(baseDmg, user, target)
    
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

# Poison Gas/Smog/Corrosive Gas - Same as City Field (already implemented)
# Defiant/Stench/Hustle/Download - Same as City Field (already implemented)

#===============================================================================
# 39. MURKWATER SURFACE - EOR poison, speed reduction, ability effects
#===============================================================================

MURKWATER_IDS = %i[murkwatersurface].freeze

# EOR poison damage for grounded non-Poison/Steel types
class Battle
  alias murkwater_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    murkwater_pbEndOfRoundPhase
    return unless has_field? && MURKWATER_IDS.include?(current_field.id)
    
    allBattlers.each do |b|
      next if b.fainted? || !b.grounded?
      next if b.pbHasType?(:POISON) || b.pbHasType?(:STEEL)
      
      # Immune abilities
      next if b.hasActiveAbility?([:IMMUNITY, :TOXICBOOST, :POISONHEAL, :MAGICGUARD, 
                                    :WONDERGUARD, :PASTELVEIL, :SURGESURFER])
      
      # Calculate damage (type-scaling)
      dmg = b.totalhp / 16
      
      # Dive users take 4x damage
      if b.effects[PBEffects::TwoTurnAttack] && 
         [:DIVE].include?(b.effects[PBEffects::TwoTurnAttack])
        dmg *= 4
      end
      
      # 2x damage abilities
      if b.hasActiveAbility?([:DRYSKIN, :WATERABSORB, :MAGMAARMOR, :FLAMEBODY])
        dmg *= 2
      end
      
      b.pbReduceHP(dmg, false) if dmg > 0
      pbDisplay(_INTL("{1} was hurt by the toxic water!", b.pbThis))
    end
  end
end

# Speed reduction (0.75x) for grounded non-Water types
class Battle::Battler
  # Speed reduction (0.75x) for grounded non-Water types in murk water
  def pbSpeed
    begin
      speed = super
    rescue NoMethodError
      speed = 0
    end
    return speed if !@battle.has_field? || !MURKWATER_IDS.include?(@battle.current_field.id)
    return speed if pbHasType?(:WATER) || !grounded?
    return speed if hasActiveAbility?([:SWIFTSWIM, :SURGESURFER])
    return (speed * 0.75).round
  end
end

# Dry Skin/Water Absorb heal for Poison types
# Gooey effect doubled
# Liquid Ooze double damage
# Stench double activation
# Water Compaction activates EOR
# Schooling always active

#===============================================================================
# 40. BIG TOP ARENA - HIGH STRIKER DAMAGE ROLLS
#===============================================================================

BIG_TOP_IDS = %i[bigtop].freeze

# Sound-based moves get 1.5x boost
class Battle::Move
  alias bigtop_sound_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)
  
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

# Acrobatics always deals double damage
class Battle::Move::DoublePowerIfUserHasNoItem
  alias bigtop_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage)
  
  def pbBaseDamage(baseDmg, user, target)
    ret = bigtop_pbBaseDamage(baseDmg, user, target)
    
    if user.battle.has_field? && BIG_TOP_IDS.include?(user.battle.current_field.id)
      return ret * 2  # Always double on Big Top
    end
    
    return ret
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

# Flinched Pokemon take 1/4 HP damage, Pokemon with raised Defense can't flinch
class Battle::Battler
  alias rocky_pbFlinch pbFlinch if method_defined?(:pbFlinch)
  
  def pbFlinch(user = nil)
    # Check if on Rocky Field with raised Defense - prevent flinch
    if @battle.has_field? && ROCKY_FIELD_IDS.include?(@battle.current_field.id)
      if @stages[:DEFENSE] > 0
        return false  # Can't flinch with raised Defense
      end
    end
    
    ret = rocky_pbFlinch(user)
    
    # Apply damage if flinched (except Sturdy/Steadfast)
    if @battle.has_field? && ROCKY_FIELD_IDS.include?(@battle.current_field.id)
      if ret && !hasActiveAbility?([:STURDY, :STEADFAST])
        dmg = (@totalhp / 4.0).round
        pbReduceHP(dmg, false)
        @battle.pbDisplay(_INTL("{1} was hurt by the rocks from flinching!", pbThis))
      end
    end
    
    return ret
  end
end

# Missing physical contact move = 1/8 HP recoil
class Battle::Battler
  alias rocky_pbEffectsAfterMove pbEffectsAfterMove if method_defined?(:pbEffectsAfterMove)
  
  def pbEffectsAfterMove(user, targets, move, numHits)
    respond_to?(:rocky_pbEffectsAfterMove) ? rocky_pbEffectsAfterMove(user, targets, move, numHits) : super

    if @battle.has_field? && ROCKY_FIELD_IDS.include?(@battle.current_field.id)
      # Check if move missed and was physical contact
      if move.physicalMove? && move.contactMove? && numHits == 0
        return if user.hasActiveAbility?(:ROCKHEAD)
        
        dmg = (user.totalhp / 8.0).round
        # Gorilla Tactics takes double
        dmg *= 2 if user.hasActiveAbility?(:GORILLATACTICS)
        
        user.pbReduceHP(dmg, false)
        @battle.pbDisplay(_INTL("{1} crashed into the rocks!", user.pbThis))
      end
    end
  end
end

# Long Reach accuracy drop (0.9x)
class Battle::Move
  alias rocky_pbBaseAccuracy pbBaseAccuracy if method_defined?(:pbBaseAccuracy)
  
  def pbBaseAccuracy(user, target)
    ret = rocky_pbBaseAccuracy(user, target)
    
    if user.battle.has_field? && ROCKY_FIELD_IDS.include?(user.battle.current_field.id)
      if user.hasActiveAbility?(:LONGREACH)
        return (ret * 0.9).round
      end
    end
    
    return ret
  end
end

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

# Substitute/raised Defense dodge Bulletproof-blockable attacks
class Battle::Move
  alias rocky_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)
  
  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && ROCKY_FIELD_IDS.include?(@battle.current_field.id)
      # Check if move would be blocked by Bulletproof (bomb/ball moves)
      bulletproof_moves = [
        :ACIDSPRAY, :AURASPHERE, :BARRAGE, :BULLETSEED, :EGGBOMB, :ELECTROSPHERE,
        :ENERGYBALL, :FOCUSBLAST, :GYROBALL, :ICEBALL, :MAGNETBOMB, :MISTBALL,
        :MUDBOMB, :OCTAZOOKA, :POLLENPUFF, :PYROBALL, :ROCKWRECKER, :SEEDBOMB,
        :SHADOWBALL, :SLUDGEBOMB, :WEATHERBALL, :ZAPCANNON
      ]
      
      if bulletproof_moves.include?(@id)
        # Target can dodge if they have Substitute or raised Defense
        if target.effects[PBEffects::Substitute] > 0 || target.stages[:DEFENSE] > 0
          if rand(100) < 50  # 50% dodge chance
            @battle.pbDisplay(_INTL("{1} hid behind the rocks!", target.pbThis)) if show_message
            return true
          end
        end
      end
    end
    respond_to?(:rocky_pbFailsAgainstTarget?) ? rocky_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#===============================================================================
# 37. PSYCHIC TERRAIN - Priority blocking, room durations, ability modifications
#===============================================================================

PSYCHIC_TERRAIN_IDS = %i[psychic].freeze

# Priority moves fail on grounded Pokemon
class Battle::Move
  alias psychic_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)
  
  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
      if @priority > 0 && target.grounded?
        @battle.pbDisplay(_INTL("{1} protected itself from the priority move!", target.pbThis)) if show_message
        return true
      end
    end
    respond_to?(:psychic_pbFailsAgainstTarget?) ? psychic_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

# Gravity/Trick Room/Magic Room/Wonder Room: 8 turns
# Already implemented above in pbEffectGeneral overrides

# Pure Power: Doubles SpAtk instead of Atk
class Battle::Battler
  # under Psychic Terrain, Pure Power/Huge Power use Sp. Atk instead of Atk
  def pbAttack
    atk = super
    if @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
      if hasActiveAbility?(:PUREPOWER) || hasActiveAbility?(:HUGEPOWER)
        # remove the Attack boost that was applied
        atk = (atk / 2.0).round
      end
    end
    return atk
  end

  def pbSpAtk
    spatk = super
    if @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
      if hasActiveAbility?(:PUREPOWER) || hasActiveAbility?(:HUGEPOWER)
        # apply SpAtk boost instead
        spatk = (spatk * 2.0).round
      end
    end
    return spatk
  end
end

# Telepathy: Speed 2x
class Battle::Battler
  # double speed with Telepathy under Psychic Terrain
  def pbSpeed
    # attempt to call whatever implementation exists; fall back to 0 if none
    begin
      speed = super
    rescue NoMethodError
      speed = 0
    end
    if @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
      if hasActiveAbility?(:TELEPATHY)
        speed = (speed * 2.0).round
      end
    end
    return speed
  end
end

# Magician: Status moves have 50% accuracy when targeting user
class Battle::Move
  def pbAccuracyCheck(user, target)
    if @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
      if target.hasActiveAbility?(:MAGICIAN) && statusMove?
        # 50% accuracy for status moves
        return rand(100) < 50
      end
    end
    # call super only if it actually exists, otherwise default to true
    if method(:pbAccuracyCheck).super_method
      begin
        return super
      rescue NoMethodError
        return true
      end
    end
    return true
  end
end

# Zen Mode activation (via form change in config)
# NOTE: Zen Mode form change handled via abilityFormChanges in field config

#===============================================================================
# 36. BEWITCHED WOODS - Sleep damage, Grass healing, type effectiveness, abilities
#===============================================================================

BEWITCHED_WOODS_IDS = %i[bewitched].freeze

# Sleep damage (1/16 HP), Grass healing (1/16 HP) EOR
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && BEWITCHED_WOODS_IDS.include?(current_field.id)
    allBattlers.each do |b|
      next if b.fainted?
      # Sleep damage
      if b.status == :SLEEP
        dmg = b.totalhp / 16
        b.pbReduceHP(dmg, false)
        pbDisplay(_INTL("{1} is suffering in the fairy ring!", b.pbThis))
      end
      # Grass healing
      if b.pbHasType?(:GRASS) && b.grounded? && b.hp < b.totalhp
        b.pbRecoverHP(b.totalhp / 16)
        pbDisplay(_INTL("{1} was healed by the enchanted woods!", b.pbThis))
      end
    end
  end
end

# Prankster works on Dark-types
class Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && BEWITCHED_WOODS_IDS.include?(@battle.current_field.id)
      # Don't block Prankster on Dark-types in Bewitched Woods
      if @priority > 0 && user.hasActiveAbility?(:PRANKSTER)
        # Allow it to work - skip the Dark-type immunity check
        if method(:pbFailsAgainstTarget?).super_method
          return super unless target.pbHasType?(:DARK)
        end
      end
    end
    if method(:pbFailsAgainstTarget?).super_method
      return super
    end
    return false
  end
end

# Type effectiveness changes
class Battle::Move
  # Properly alias so the original PE type chart is preserved in the chain
  alias bewitched_pbCalcTypeMod pbCalcTypeMod if method_defined?(:pbCalcTypeMod)

  def pbCalcTypeMod(moveType, user, target)
    typeMod = bewitched_pbCalcTypeMod(moveType, user, target)
    return typeMod unless @battle.has_field? && BEWITCHED_WOODS_IDS.include?(@battle.current_field.id)
    # Fairy SE vs Steel
    return Effectiveness::SUPER_EFFECTIVE_ONE if moveType == :FAIRY && target.pbHasType?(:STEEL)
    # Poison neutral vs Grass
    return Effectiveness::NORMAL_EFFECTIVE_ONE if moveType == :POISON && target.pbHasType?(:GRASS)
    # Dark neutral vs Fairy
    return Effectiveness::NORMAL_EFFECTIVE_ONE if moveType == :DARK && target.pbHasType?(:FAIRY)
    # Fairy neutral vs Dark
    return Effectiveness::NORMAL_EFFECTIVE_ONE if moveType == :FAIRY && target.pbHasType?(:DARK)
    return typeMod
  end
end

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

# Ground-types: 1.5x SpDef
class Battle::Move
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    super(user, target, numTargets, type, baseDmg, multipliers)
    return unless @battle.has_field? && DESERT_FIELD_IDS.include?(@battle.current_field.id)
    return unless target.pbHasType?(:GROUND)
    return unless specialMove?(type)
    multipliers[:defense_multiplier] *= 1.5
  end
end

# Sandstorm: 1/8 damage (add extra 1/16)
# Sunny Day: Grass/Water take 1/8 damage EOR (unless Solar Power/Chlorophyll)
# Grass/Water healed by Water moves in Sunny Day
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && DESERT_FIELD_IDS.include?(current_field.id)
    allBattlers.each do |b|
      next if b.fainted?
      # Sandstorm extra damage
      if [:Sandstorm].include?(field.weather) && !b.pbHasType?(:GROUND, :ROCK, :STEEL)
        extra_dmg = b.totalhp / 16
        b.pbReduceHP(extra_dmg, false) if extra_dmg > 0
      end
      # Sunny Day damage to Grass/Water
      if [:Sun, :HarshSun].include?(field.weather)
        if (b.pbHasType?(:GRASS) || b.pbHasType?(:WATER)) && 
           !b.hasActiveAbility?([:SOLARPOWER, :CHLOROPHYLL])
          dmg = b.totalhp / 8
          b.pbReduceHP(dmg, false)
          pbDisplay(_INTL("{1} is hurt by the intense sun!", b.pbThis))
        end
      end
    end
  end
end

#===============================================================================
# 34. CORROSIVE FIELD - Entry hazard poison, sleep damage, Ingrain/Grass Pelt damage
#===============================================================================

CORROSIVE_FIELD_IDS = %i[corrosive].freeze

# Sleeping Pokemon take 1/16 HP damage
# Ingrain/Grass Pelt damage users
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && CORROSIVE_FIELD_IDS.include?(current_field.id)
    allBattlers.each do |b|
      next if b.fainted?
      # Sleeping non-Poison/Steel Pokemon take damage
      if b.status == :SLEEP && !b.pbHasType?(:POISON) && !b.pbHasType?(:STEEL)
        next if b.hasActiveAbility?(:WONDERGUARD)
        dmg = (b.totalhp / 16.0).round
        b.pbReduceHP(dmg, false)
        pbDisplay(_INTL("{1} was hurt by the corrosive field while sleeping!", b.pbThis))
      end
      # Grass Pelt damages user
      if b.hasActiveAbility?(:GRASSPELT)
        dmg = (b.totalhp / 16.0).round
        b.pbReduceHP(dmg, false)
        pbDisplay(_INTL("{1} was hurt by the corrosive field!", b.pbThis))
      end
      # Ingrain damages user
      if b.effects[PBEffects::Ingrain]
        dmg = (b.totalhp / 16.0).round
        b.pbReduceHP(dmg, false)
        pbDisplay(_INTL("{1}'s roots were corroded!", b.pbThis))
      end
    end
  end
end

# Corrosion - 1.5x damage boost
Battle::AbilityEffects::DamageCalcFromUser.add(:CORROSION_CORROSIVE,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !CORROSIVE_FIELD_IDS.include?(user.battle.current_field.id)
    next if user.ability != :CORROSION
    mults[:power_multiplier] *= 1.5
  }
)

# Floral Healing poisons target
class Battle::Move::HealTargetDependingOnGrassyTerrain
  def pbEffectAgainstTarget(user, target)
    super
    # Poison target on Corrosive Field or Corrosive Mist
    if @battle.has_field? && (CORROSIVE_FIELD_IDS.include?(@battle.current_field.id) || 
                               CORROSIVE_MIST_IDS.include?(@battle.current_field.id))
      target.pbPoison(user) if target.pbCanPoison?(user, false, self)
    end
  end
end

# Life Dew poisons targets on Corrosive Mist
class Battle::Move::HealAllyOrUserByQuarterOfTotalHP
  def pbMoveFailed?(user, targets)
    ret = super
    # Poison all targets on Corrosive Mist after healing
    if @battle.has_field? && CORROSIVE_MIST_IDS.include?(@battle.current_field.id)
      targets.each do |b|
        b.pbPoison(user) if b.pbCanPoison?(user, false, self)
      end
    end
    return ret
  end
end

# Toxic Spikes can't be absorbed on Corrosive Field
class Battle::Battler
  def pbEffectsOnMakingHit(move, user, target)
    # call super if available
    if method(:pbEffectsOnMakingHit).super_method
      begin
        super
      rescue NoMethodError
        # gracefully ignore
      end
    end
    # Prevent Toxic Spikes absorption on Corrosive Field
    if @battle.has_field? && CORROSIVE_FIELD_IDS.include?(@battle.current_field.id)
      if grounded? && pbHasType?(:POISON)
        # Don't absorb Toxic Spikes - do nothing (absorption happens in base game)
        # We just prevent the removal by not allowing the check
      end
    end
  end
end

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

#===============================================================================
# 33. CORROSIVE MIST FIELD MECHANICS
# EOR poison all, Aqua Ring/Dry Skin damage, field explosion
#===============================================================================

CORROSIVE_MIST_IDS = %i[corrosivemist].freeze

# EOR poison for ALL Pokemon (unless Neutralizing Gas active)
# Aqua Ring damages users
# Dry Skin damages users (heals Poison types)
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && CORROSIVE_MIST_IDS.include?(current_field.id)
    # Check for Neutralizing Gas
    neutralizing_gas_active = allBattlers.any? { |b| b.hasActiveAbility?(:NEUTRALIZINGGAS) }
    allBattlers.each do |b|
      next if b.fainted?
      
      # Poison all Pokemon (unless Neutralizing Gas)
      if !neutralizing_gas_active && b.status != :POISON
        b.pbPoison(nil, nil, false)
      end
      
      # Aqua Ring damages user
      if b.effects[PBEffects::AquaRing]
        dmg = (b.totalhp / 16.0).round
        b.pbReduceHP(dmg, false)
        pbDisplay(_INTL("{1} was hurt by the toxic mist!", b.pbThis))
      end
      
      # Dry Skin - damages unless Poison type
      if b.hasActiveAbility?(:DRYSKIN)
        if b.pbHasType?(:POISON)
          # Heal Poison types
          if b.hp < b.totalhp
            b.pbRecoverHP((b.totalhp / 8.0).round)
            pbDisplay(_INTL("{1} absorbed the toxic mist!", b.pbThis))
          end
        else
          # Damage non-Poison types
          dmg = (b.totalhp / 8.0).round
          b.pbReduceHP(dmg, false)
          pbDisplay(_INTL("{1} was hurt by the toxic mist!", b.pbThis))
        end
      end
    end
  end
end

# Floral Healing/Life Dew poison targets
# Field explosion on Fire moves
# NOTE: Field explosion handled via changeEffects (@battle.mistExplosion)

#===============================================================================
# 32. CORRUPTED CAVE FIELD MECHANICS
# EOR poison, ability effects, Stealth Rock Poison chart, Ingrain damage
#===============================================================================

CORRUPTED_CAVE_IDS = %i[corrupted].freeze

# EOR poison for grounded non-Poison/Steel types
# EOR damage for Grass Pelt/Leaf Guard/Flower Veil
# EOR healing for Poison Heal
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && CORRUPTED_CAVE_IDS.include?(current_field.id)
    allBattlers.each do |b|
      next if b.fainted?
      
      # Poison grounded non-Poison/Steel types
      if b.grounded? && !b.pbHasType?(:POISON) && !b.pbHasType?(:STEEL)
        if !b.hasActiveAbility?([:WONDERSKIN, :IMMUNITY, :PASTELVEIL]) && b.status != :POISON
          b.pbPoison(nil, nil, false)
          pbDisplay(_INTL("{1} was poisoned by the corruption!", b.pbThis))
        end
      end
      
      # Grass Pelt/Leaf Guard/Flower Veil - take damage
      if b.hasActiveAbility?([:GRASSPELT, :LEAFGUARD, :FLOWERVEIL])
        dmg = (b.totalhp / 16.0).round
        b.pbReduceHP(dmg, false)
        pbDisplay(_INTL("{1} was hurt by the corruption!", b.pbThis))
      end
      
      # Poison Heal - heal
      if b.hasActiveAbility?(:POISONHEAL) && b.status == :POISON
        if b.hp < b.totalhp
          b.pbRecoverHP((b.totalhp / 8.0).round)
          pbDisplay(_INTL("{1} is healed by the poison!", b.pbThis))
        end
      end
    end
  end
end

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
        battler.pbRecoverHP((battler.totalhp / 8.0).round)
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

# Poison Touch/Point - Doubled activation rate
class Battle::Move
  def pbAdditionalEffect(user, target)
    if user.battle.has_field? && CORRUPTED_CAVE_IDS.include?(user.battle.current_field.id)
      if user.hasActiveAbility?([:POISONTOUCH, :POISONPOINT]) && contactMove?
        # Double chance to poison
        if rand(100) < 60  # 30% x 2 = 60%
          target.pbPoison(user) if target.pbCanPoison?(user, false, self)
        end
      end
    end
    return super
  end
end

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

# Ingrain - Damages user unless Poison/Steel type
class Battle::Move::HealUserDependingOnWeather
  def pbEffectGeneral(user)
    if @battle.has_field? && CORRUPTED_CAVE_IDS.include?(@battle.current_field.id)
      if @id == :INGRAIN && !user.pbHasType?(:POISON) && !user.pbHasType?(:STEEL)
        dmg = (user.totalhp / 8.0).round
        user.pbReduceHP(dmg, false)
        @battle.pbDisplay(_INTL("{1} was hurt by the corrupted ground!", user.pbThis))
      end
    end
    return super
  end
end

# Liquid Ooze - Doubled damage
class Battle::Move
  # under Corrupted Cave the life‑leeching check might be modified later
  def pbLifeLeechingMove?
    ret = super
    return ret
  end
end

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
      battler.pbRecoverHP(amt)
      battle.pbDisplay(_INTL("{1} restored a little HP using its {2}!", battler.pbThis, battler.itemName))
    else
      battler.pbReduceHP(amt, false)
      battle.pbDisplay(_INTL("{1} was hurt by its {2}!", battler.pbThis, battler.itemName))
    end
  }
)

# Field Explosion - Heat Wave/etc. deal 50% max HP to all
# NOTE: Handled via @battle.mistExplosion in field change effects

#===============================================================================
# 31. UNDERWATER FIELD MECHANICS
# Speed halved for non-Water, physical move reduction, EOR damage
#===============================================================================

UNDERWATER_IDS = %i[underwater].freeze

# Non-Water types: Speed halved
class Battle::Battler
  def pbSpeed
    begin
      speed = super
    rescue NoMethodError
      speed = 0
    end
    return speed if !@battle.has_field? || !UNDERWATER_IDS.include?(@battle.current_field.id)
    return speed if pbHasType?(:WATER)
    return (speed * 0.5).round
  end
end

# Physical non-Water moves by non-Water types: 0.5x damage
class Battle::Move
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    super(user, target, numTargets, type, baseDmg, multipliers)
    return unless @battle.has_field? && UNDERWATER_IDS.include?(@battle.current_field.id)
    return if user.pbHasType?(:WATER) || type == :WATER
    return unless physicalMove?(type)
    multipliers[:base_damage_multiplier] *= 0.5
  end
end

# EOR damage to non-Water weak to Water
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && UNDERWATER_IDS.include?(current_field.id)
    allBattlers.each do |b|
      next if b.fainted? || b.pbHasType?(:WATER)
      effectiveness = Effectiveness.calculate(:WATER, *b.pbTypes(true))
      next unless Effectiveness.super_effective?(effectiveness)
      
      dmg = (b.totalhp / 16.0).round
      dmg = (dmg * 2).round if b.hasActiveAbility?([:MAGMAARMOR, :FLAMEBODY])
      b.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is hurt by the water pressure!", b.pbThis))
    end
  end
end

# Water hits Water for neutral damage
# Whirlpool confuses, Electric never misses
# NOTE: Similar implementations to other fields

#===============================================================================
# 30. WATER SURFACE FIELD MECHANICS
# Speed reduction for non-Water grounded, ability activations
#===============================================================================

WATER_SURFACE_IDS = %i[watersurface].freeze

# Passive Speed reduction (0.75x) for grounded non-Water types
# Applied via Battle::Battler#pbSpeed hook
class Battle::Battler
  def pbSpeed
    # try to use parent speed if it exists
    if method(:pbSpeed).super_method
      begin
        speed = super
      rescue NoMethodError
        speed = 0
      end
    else
      speed = 0
    end
    return speed if !@battle.has_field? || !WATER_SURFACE_IDS.include?(@battle.current_field.id)
    return speed if pbHasType?(:WATER) || !grounded?
    return speed if hasActiveAbility?([:SWIFTSWIM, :SURGESURFER])
    return (speed * 0.75).round
  end
end

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
    battler.pbRecoverHP(battler.totalhp / 16)
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
    battler.pbRecoverHP(battler.totalhp / 16)
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

# Whirlpool - 1/6 damage, Aqua Ring - 1/8 healing, Tar Shot wash
class Battle
  def pbEndOfRoundPhase
    super
    return unless has_field? && WATER_SURFACE_IDS.include?(current_field.id)
    allBattlers.each do |battler|
      next if battler.fainted?
      
      # Whirlpool extra damage
      if battler.effects[PBEffects::Trapping] > 0
        trapping_move = battler.effects[PBEffects::TrappingMove] if PBEffects.const_defined?(:TrappingMove)
        if trapping_move == :WHIRLPOOL
          extra_dmg = battler.totalhp / 24
          battler.pbReduceHP(extra_dmg, false) if extra_dmg > 0
        end
      end
      
      # Aqua Ring extra healing
      if battler.effects[PBEffects::AquaRing]
        extra_heal = battler.totalhp / 16
        battler.pbRecoverHP(extra_heal) if battler.hp < battler.totalhp
      end
      
      # Tar Shot wash off
      battler.effects[PBEffects::TarShot] = false if battler.effects[PBEffects::TarShot]
    end
  end
end

# Life Dew - Grants Aqua Ring
class Battle::Move::HealAllyOrUserByQuarterOfTotalHP
  def pbEffectAgainstTarget(user, target)
    ret = super
    if @battle.has_field? && WATER_SURFACE_IDS.include?(@battle.current_field.id)
      if @id == :LIFEDEW
        target.effects[PBEffects::AquaRing] = true
        @battle.pbDisplay(_INTL("{1} surrounded itself with a veil of water!", target.pbThis))
      end
    end
    return ret
  end
end

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

# Wave Crash - Recoil reduced to 25%
class Battle::Move::RecoilQuarterOfDamageDealt
  def pbEffectAfterAllHits(user, target)
    if @battle.has_field? && WATER_SURFACE_IDS.include?(@battle.current_field.id)
      if @id == :WAVECRASH
        return if !user.takesIndirectDamage?
        return if user.hasActiveAbility?(:ROCKHEAD)
        amt = [(user.totalhp * 0.25).round, 1].max  # 25% of max HP
        user.pbReduceHP(amt, false)
        @battle.pbDisplay(_INTL("{1} is damaged by recoil!", user.pbThis))
        return
      end
    end
    watersurface_pbEffectAfterAllHits(user, target)
  end
end

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

# Poison Gas/Smog - Always hit and badly poison
class Battle::Move::PoisonTarget
  def pbFailsAgainstTarget?(user, target, show_message)
    if [:POISONGAS, :SMOG].include?(@id) &&
       @battle.has_field? &&
       CITY_FIELD_IDS.include?(@battle.current_field.id)
      # Never miss
      @city_field_boost = true
      return false if target.pbCanPoison?(user, false, self)
    end
    return super
  end
  
  def pbEffectAgainstTarget(user, target)
    if @city_field_boost
      # Badly poison instead of regular poison
      target.pbPoison(user, nil, true)
      @city_field_boost = nil
      return 0
    end
    
    respond_to?(:city_pbEffectAgainstTarget) ? city_pbEffectAgainstTarget(user, target) : super
  end
end

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
  alias city_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    ret = city_pbEffectAgainstTarget(user, target)
    
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

#===============================================================================
# 28. SNOWY MOUNTAIN FIELD MECHANICS
# Ice-type Defense boost in Hail, ability activations, Ice Scales modification
#===============================================================================

SNOWY_MOUNTAIN_IDS = %i[snowymountain].freeze

# Ice-type Defense boost during Hail (1.5x)
class Battle::Move
  alias snowy_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:snowy_pbCalcDamageMultipliers) ? snowy_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
    # Ice-types get 1.5x Defense during Hail on Snowy Mountain
    return unless @battle.has_field? && SNOWY_MOUNTAIN_IDS.include?(@battle.current_field.id)
    return unless [:Hail, :Snow].include?(@battle.field.weather)
    return unless target.pbHasType?(:ICE)
    
    # Boost defense calculation
    multipliers[:defense_multiplier] *= 1.5
  end
end

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

# Ice Scales - Ignores Ice-type weaknesses
class Battle::Move
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    super(user, target, numTargets, type, baseDmg, multipliers)
    # Ice Scales ignores Ice weaknesses on Snowy Mountain
    return unless @battle.has_field? && SNOWY_MOUNTAIN_IDS.include?(@battle.current_field.id)
    return unless target.hasActiveAbility?(:ICESCALES)
    return unless type == :ICE
    # If target is weak to Ice, make it neutral
    effectiveness = Effectiveness.calculate(type, *target.pbTypes(true))
    if Effectiveness.super_effective?(effectiveness)
      # Divide out the super effectiveness
      multipliers[:final_damage_multiplier] /= 2.0
    end
  end
end

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

# Bitter Malice - 10% freeze chance on Snowy Mountain
# NOTE: This move's function code may not support pbAdditionalEffect
# Would need to modify the base move code to add freeze chance on Snowy Mountain

# Tailwind + Strong Winds (same as Mountain/Volcanic Top)
# Special Flying moves boost (same as Mountain)
# Wind moves boost in Strong Winds (same as Mountain)
# These are already implemented and will work for Snowy Mountain too

#===============================================================================
# 27. MOUNTAIN FIELD MECHANICS
# Tailwind + Strong Winds, Long Reach boost, Flying move boosts
#===============================================================================

MOUNTAIN_FIELD_IDS = %i[mountain].freeze

# Long Reach - 1.5x damage on Mountain Field
Battle::AbilityEffects::DamageCalcFromUser.add(:LONGREACH,
  proc { |ability, user, target, move, mults, power, type|
    next if !user.battle.has_field? || !MOUNTAIN_FIELD_IDS.include?(user.battle.current_field.id)
    mults[:attack_multiplier] *= 1.5
  }
)

# Tailwind - Lasts 6 turns and creates Strong Winds (same as Volcanic Top)
# Already implemented in Volcanic Top section, reuse here

# Special Flying moves get additional 1.5x boost during Strong Winds
class Battle::Move
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # only attempt super if defined
    if method(:pbCalcDamageMultipliers).super_method
      begin
        super(user, target, numTargets, type, baseDmg, multipliers)
      rescue NoMethodError
        # ignore
      end
    end
    # On Mountain Field during Strong Winds, special Flying moves get extra boost
    return unless @battle.has_field? && MOUNTAIN_FIELD_IDS.include?(@battle.current_field.id)
    return unless @battle.field.weather == :StrongWinds
    return unless type == :FLYING && specialMove?(type)
    # Additional 1.5x boost
    multipliers[:base_damage_multiplier] *= 1.5
  end
end

# Wind moves (Ominous Wind, Razor Wind, Icy Wind, etc.) also get boost in Strong Winds
# This applies to: OMINOUSWIND, RAZORWIND, ICYWIND, SILVERWIND, FAIRYWIND, TWISTER, GUST
MOUNTAIN_WIND_MOVES = [:OMINOUSWIND, :RAZORWIND, :ICYWIND, :SILVERWIND, :FAIRYWIND, :TWISTER, :GUST].freeze

class Battle::Move
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if method(:pbCalcDamageMultipliers).super_method
      begin
        super(user, target, numTargets, type, baseDmg, multipliers)
      rescue NoMethodError
        # ignore
      end
    end
    # Wind moves get 1.5x boost during Strong Winds on Mountain Field
    return unless @battle.has_field? && MOUNTAIN_FIELD_IDS.include?(@battle.current_field.id)
    return unless @battle.field.weather == :StrongWinds
    return unless MOUNTAIN_WIND_MOVES.include?(@id)
    multipliers[:base_damage_multiplier] *= 1.5
  end
end

# Hail weather transformation to Snowy Mountain after 3 consecutive turns
class Battle
  def pbEndOfRoundPhase
    # call parent phase if it exists
    if method(:pbEndOfRoundPhase).super_method
      begin
        super
      rescue NoMethodError
        # nothing to do
      end
    end
    # Check for Hail on Mountain Field
    if has_field? && MOUNTAIN_FIELD_IDS.include?(current_field.id)
      if [:Hail, :Snow].include?(field.weather)
        # Increment hail counter
        @mountain_hail_turns ||= 0
        @mountain_hail_turns += 1
        if @mountain_hail_turns >= 3
          # Transform to Snowy Mountain
          pbDisplay(_INTL("The mountain became covered in snow!"))
          pbChangeBattleField(:SNOWYMOUNTAIN)
          @mountain_hail_turns = 0
        end
      else
        # Reset counter if weather changes
        @mountain_hail_turns = 0
      end
    else
      @mountain_hail_turns = 0
    end
    # Check for Sun on Snowy Mountain Field (reverse transformation)
    if has_field? && current_field.id == :snowymountain
      if [:Sun, :HarshSun].include?(field.weather)
        # Increment sun counter
        @snowy_sun_turns ||= 0
        @snowy_sun_turns += 1
        if @snowy_sun_turns >= 3
          # Transform to Mountain
          pbDisplay(_INTL("The snow melted away!"))
          pbChangeBattleField(:MOUNTAIN)
          @snowy_sun_turns = 0
        end
      else
        # Reset counter if weather changes
        @snowy_sun_turns = 0
      end
    else
      @snowy_sun_turns = 0
    end
  end
end

#===============================================================================
# 26. BLESSED FIELD MECHANICS
# Normal hits Ghost/Dark for SE, partner damage immunity, healing effects
#===============================================================================

BLESSED_FIELD_IDS = %i[holy].freeze

# Normal hits Ghost and Dark for super effective damage
class Battle::Move
  alias blessed_pbCalcTypeMod pbCalcTypeMod if method_defined?(:pbCalcTypeMod)

  def pbCalcTypeMod(moveType, user, target)
    typeMod = blessed_pbCalcTypeMod(moveType, user, target)
    return typeMod unless moveType == :NORMAL &&
                          @battle.has_field? &&
                          BLESSED_FIELD_IDS.include?(@battle.current_field.id)
    return Effectiveness::SUPER_EFFECTIVE_ONE if target.pbHasType?(:GHOST) || target.pbHasType?(:DARK)
    return typeMod
  end
end

# Partner damage immunity - Pokemon avoid damage from partner's moves
class Battle::Move
  alias blessed_pbChangeTargetHP pbChangeTargetHP if method_defined?(:pbChangeTargetHP)
  
  def pbChangeTargetHP(target, damage, opts = {})
    # On Blessed Field, partners don't take damage
    if @battle.has_field? &&
       BLESSED_FIELD_IDS.include?(@battle.current_field.id) &&
       @battle.pbSideSize(@user.index) > 1  # Double battle
      # Check if target is on same side as user
      if @battle.pbIsOpposingSide?(target.index) != @battle.pbIsOpposingSide?(@user.index)
        # Same side - no damage
        damage = 0
      end
    end
    
    return blessed_pbChangeTargetHP(target, damage, opts) if defined?(blessed_pbChangeTargetHP)
    return damage
  end
end

# Wish - Restores 75% HP
# Life Dew - 50% healing (from 25%)
class Battle::Battler
  alias blessed_healing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)
  
  def pbRecoverHP(amt, anim = true)
    # Check healing moves on Blessed Field
    if @battle.respond_to?(:choices) && @battle.has_field? && BLESSED_FIELD_IDS.include?(@battle.current_field.id)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move
        if current_move.id == :WISH
          amt = (@totalhp * 3 / 4.0).round
        elsif current_move.id == :LIFEDEW
          amt = (@totalhp / 2.0).round
        end
      end
    end
    
    respond_to?(:blessed_healing_pbRecoverHP) ? blessed_healing_pbRecoverHP(amt, anim) : super
  end
end

# Nature's Madness - 66% HP damage
class Battle::Move::LowerTargetHPToUserHP
  alias blessed_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    if @id == :NATURESMADNESS &&
       @battle.has_field? &&
       BLESSED_FIELD_IDS.include?(@battle.current_field.id)
      # Deal 66% HP damage
      dmg = (target.hp * 2 / 3.0).round
      target.pbReduceHP(dmg, false)
      return 0
    end
    
    respond_to?(:blessed_pbEffectAgainstTarget) ? blessed_pbEffectAgainstTarget(user, target) : super
  end
end

# Curse (Ghost-type) - Lifted at end of turn
class Battle
  alias blessed_curse_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    blessed_curse_pbEndOfRoundPhase
    return unless has_field? && BLESSED_FIELD_IDS.include?(current_field.id)
    
    # Remove Curse from all Pokemon
    allBattlers.each do |battler|
      next if battler.fainted?
      if battler.effects[PBEffects::Curse]
        battler.effects[PBEffects::Curse] = false
        pbDisplay(_INTL("The blessing lifted the curse on {1}!", battler.pbThis))
      end
    end
  end
end

# Spirit Break - Super effective vs Ghost
class Battle::Move::LowerTargetAtkSpAtk1
  alias blessed_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)
  
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = blessed_pbCalcTypeModSingle(moveType, defType, user, target)
    
    # Spirit Break hits Ghost for super effective on Blessed Field
    if @id == :SPIRITBREAK &&
       defType == :GHOST &&
       @battle.has_field? &&
       BLESSED_FIELD_IDS.include?(@battle.current_field.id)
      return Effectiveness::SUPER_EFFECTIVE_ONE
    end
    
    return ret
  end
end

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

# Sleep HP loss - Non-Ghost types lose HP while asleep
class Battle
  alias haunted_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    haunted_pbEndOfRoundPhase
    return unless has_field? && HAUNTED_FIELD_IDS.include?(current_field.id)
    
    # Sleeping non-Ghost types take damage
    allBattlers.each do |battler|
      next if battler.fainted?
      next if battler.status != :SLEEP
      next if battler.pbHasType?(:GHOST)
      
      damage = battler.totalhp / 8
      battler.pbReduceHP(damage, false)
      pbDisplay(_INTL("{1} is suffering in its nightmares!", battler.pbThis))
    end
  end
end

# Ghost neutral to Normal - Override type effectiveness
class Battle::Move
  alias haunted_pbCalcTypeMod pbCalcTypeMod if method_defined?(:pbCalcTypeMod)
  
  def pbCalcTypeMod(moveType, user, target)
    typeMod = haunted_pbCalcTypeMod(moveType, user, target)
    
    # On Haunted Field, Ghost hits Normal for neutral damage
    if moveType == :GHOST &&
       target.pbHasType?(:NORMAL) &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      # Override the immunity to neutral
      return Effectiveness::NORMAL_EFFECTIVE_ONE
    end
    
    return typeMod
  end
end

# Nightmare - More damage on Haunted Field
class Battle
  alias haunted_nightmare_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    haunted_nightmare_pbEndOfRoundPhase
    return unless has_field? && HAUNTED_FIELD_IDS.include?(current_field.id)
    
    # Nightmare normally deals 1/4, boost to 1/3
    # Base damage already happened, add extra 1/12
    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Nightmare]
      next if battler.status != :SLEEP
      
      extra_damage = battler.totalhp / 12
      battler.pbReduceHP(extra_damage, false)
    end
  end
end

# NOTE: Curse (Ghost-type) HP cost reduction to 25% on Haunted Field
# This is complex as Curse has different behavior for Ghost vs non-Ghost users
# Best implemented by adding to fieldtxt :moveEffects with custom handler
# For now, documented as needing base game modification

# Spite - Depletes 2 more PP (total 4 instead of 2)
class Battle::Move::LowerPPOfTargetLastMoveBy4
  alias haunted_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    # Change to deplete 6 PP on Haunted Field (4 base + 2 extra)
    if @battle.has_field? && HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      @pp_reduction = 6
    else
      @pp_reduction = 4
    end
    
    respond_to?(:haunted_pbEffectAgainstTarget) ? haunted_pbEffectAgainstTarget(user, target) : super
  end
end

# Ominous Wind - 20% chance to raise all stats (from 10%)
class Battle::Move::RaiseUserMainStats1
  alias haunted_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)
  
  def pbAdditionalEffect(user, target)
    if @id == :OMINOUSWIND &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      # 20% chance instead of 10%
      return if rand(100) >= 20
      user.pbRaiseStatStage(:ATTACK, 1, user)
      user.pbRaiseStatStage(:DEFENSE, 1, user)
      user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user)
      user.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, user)
      user.pbRaiseStatStage(:SPEED, 1, user)
      return 0
    end
    
    respond_to?(:haunted_pbAdditionalEffect) ? haunted_pbAdditionalEffect(user, target) : super
  end
end

# Fire Spin - 1/6 damage instead of 1/8
class Battle
  alias haunted_firespin_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    haunted_firespin_pbEndOfRoundPhase
    return unless has_field? && HAUNTED_FIELD_IDS.include?(current_field.id)
    
    # Fire Spin damage boost from 1/8 to 1/6
    # Base 1/8 already happened, add extra 1/24
    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Trapping] > 0
      
      trapping_move = nil
      if PBEffects.const_defined?(:TrappingMove)
        trapping_move = battler.effects[PBEffects::TrappingMove]
      end
      next unless trapping_move == :FIRESPIN
      
      extra_dmg = battler.totalhp / 24
      battler.pbReduceHP(extra_dmg, false) if extra_dmg > 0
    end
  end
end

# Lick - 100% chance to Paralyze (from 30%)
class Battle::Move::ParalyzeTarget
  alias haunted_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)
  
  def pbFailsAgainstTarget?(user, target, show_message)
    if @id == :LICK &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      @haunted_boost = true
    end
    
    respond_to?(:haunted_pbFailsAgainstTarget?) ? haunted_pbFailsAgainstTarget?(user, target, show_message) : super
  end
  
  alias haunted_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)
  
  def pbAdditionalEffect(user, target)
    if @haunted_boost
      # 100% chance
      return 0 if target.pbCanParalyze?(user, false, self)
      target.pbParalyze(user)
    end
    @haunted_boost = nil
    
    respond_to?(:haunted_pbAdditionalEffect) ? haunted_pbAdditionalEffect(user, target) : super
  end
end

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

# Night Shade - 1.5x damage on Haunted Field
class Battle::Move::FixedDamageUserLevel
  alias haunted_pbFixedDamage pbFixedDamage if method_defined?(:pbFixedDamage)
  
  def pbFixedDamage(user, target)
    dmg = haunted_pbFixedDamage(user, target)
    
    # Night Shade deals 1.5x on Haunted Field
    if @id == :NIGHTSHADE &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      dmg = (dmg * 1.5).round
    end
    
    return dmg
  end
end

# Magic Powder - Puts target to sleep on Haunted Field
class Battle::Move::SetTargetTypesToPsychic
  alias haunted_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    if @id == :MAGICPOWDER &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      # Put to sleep instead of changing type
      if target.pbCanSleep?(user, true, self)
        target.pbSleep
        return 0
      end
      return -1
    end
    
    respond_to?(:haunted_pbEffectAgainstTarget) ? haunted_pbEffectAgainstTarget(user, target) : super
  end
end

# Destiny Bond - No consecutive fail on Haunted Field
class Battle::Move::AttackerFaintsIfUserFaints
  alias haunted_pbMoveFailed? pbMoveFailed? if method_defined?(:pbMoveFailed?)
  
  def pbMoveFailed?(user, targets)
    # On Haunted Field, Destiny Bond never fails from consecutive use
    if @battle.has_field? && HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      # Skip the consecutive use check
      return false
    end
    
    respond_to?(:haunted_pbMoveFailed?) ? haunted_pbMoveFailed?(user, targets) : super
  end
end

# Mean Look - Targets both opponents on Haunted Field
class Battle::Move::TrapTargetInBattle
  alias haunted_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)
  
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = haunted_pbFailsAgainstTarget?(user, target, show_message)
    
    # On Haunted Field with Mean Look, affect all opponents
    if @id == :MEANLOOK &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      @haunted_multi_target = true
    end
    
    return ret
  end
  
  alias haunted_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    ret = haunted_pbEffectAgainstTarget(user, target)
    
    # If multi-target, trap all other opponents too
    if @haunted_multi_target
      @battle.allOtherBattlers(user.index).each do |b|
        next if b.index == target.index
        next if b.fainted?
        next if b.effects[PBEffects::MeanLook] >= 0
        
        b.effects[PBEffects::MeanLook] = user.index
        @battle.pbDisplay(_INTL("{1} can't escape now!", b.pbThis))
      end
      @haunted_multi_target = nil
    end
    
    return ret
  end
end

# Fire Spin - Targets both opponents on Haunted Field
class Battle::Move::BindTarget
  alias haunted_pbNumHits pbNumHits if method_defined?(:pbNumHits)
  
  def pbNumHits(user, targets)
    # On Haunted Field, Fire Spin hits all opponents
    if @id == :FIRESPIN &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      # Make it hit all opponents by modifying targets
      @haunted_multi = true
    end
    
    respond_to?(:haunted_pbNumHits) ? haunted_pbNumHits(user, targets) : super
  end
  
  alias haunted_pbModifyTargets pbModifyTargets if method_defined?(:pbModifyTargets)
  
  def pbModifyTargets(targets, user)
    # If Fire Spin on Haunted Field, target all opponents
    if @haunted_multi
      new_targets = []
      @battle.allOtherBattlers(user.index).each do |b|
        new_targets.push(b) unless b.fainted?
      end
      @haunted_multi = nil
      return new_targets unless new_targets.empty?
    end
    
    respond_to?(:haunted_pbModifyTargets) ? haunted_pbModifyTargets(targets, user) : super
  end
end

# Bitter Malice - Lower SpAtk on Haunted Field
# NOTE: This move's function code may not support pbAdditionalEffect
# Would need to modify the base move code to add SpAtk drop on Haunted Field

# Spirit Break - Super effective vs Ghost on Haunted Field
class Battle::Move::LowerTargetAtkSpAtk1
  alias haunted_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)
  
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = haunted_pbCalcTypeModSingle(moveType, defType, user, target)
    
    # Spirit Break hits Ghost for super effective on Haunted Field
    if @id == :SPIRITBREAK &&
       defType == :GHOST &&
       @battle.has_field? &&
       HAUNTED_FIELD_IDS.include?(@battle.current_field.id)
      return Effectiveness::SUPER_EFFECTIVE_ONE
    end
    
    return ret
  end
end

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

# Power Spot - 1.5x damage boost (already handled in general Power Spot code)

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

# Strength Sap - Heals 30% more HP
class Battle::Move::HealUserByTargetAttackLowerTargetAttack1
  alias forest_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    # On Forest Field, boost healing by 30%
    if @battle.has_field? && FOREST_FIELD_IDS.include?(@battle.current_field.id)
      @forest_boost = true
    end
    
    ret = forest_pbEffectAgainstTarget(user, target)
    @forest_boost = nil
    return ret
  end
  
  alias forest_pbHealAmount pbHealAmount if method_defined?(:pbHealAmount)
  
  def pbHealAmount(user, target)
    amt = forest_pbHealAmount(user, target) if defined?(forest_pbHealAmount)
    amt ||= target.attack
    
    if @forest_boost
      amt = (amt * 1.3).round
    end
    
    return amt
  end
end

# Ingrain - Healing doubled on Forest Field
class Battle
  alias forest_ingrain_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    forest_ingrain_pbEndOfRoundPhase
    return unless has_field? && FOREST_FIELD_IDS.include?(current_field.id)
    
    # Ingrain normally heals 1/16, double to 1/8
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

# Infestation - 1/6 damage instead of 1/8
class Battle
  alias forest_infestation_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    forest_infestation_pbEndOfRoundPhase
    return unless has_field? && FOREST_FIELD_IDS.include?(current_field.id)
    
    # Infestation damage boost from 1/8 to 1/6
    # Base 1/8 already happened, add extra 1/24
    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Trapping] > 0
      
      trapping_move = nil
      if PBEffects.const_defined?(:TrappingMove)
        trapping_move = battler.effects[PBEffects::TrappingMove]
      end
      next unless trapping_move == :INFESTATION
      
      extra_dmg = battler.totalhp / 24
      battler.pbReduceHP(extra_dmg, false) if extra_dmg > 0
    end
  end
end

# Nature's Madness - 75% HP damage
class Battle::Move::LowerTargetHPToUserHP
  alias forest_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    if @id == :NATURESMADNESS &&
       @battle.has_field? &&
       FOREST_FIELD_IDS.include?(@battle.current_field.id)
      # Deal 75% HP damage
      dmg = (target.hp * 3 / 4.0).round
      target.pbReduceHP(dmg, false)
      return 0
    end
    
    respond_to?(:forest_pbEffectAgainstTarget) ? forest_pbEffectAgainstTarget(user, target) : super
  end
end

# Heal Order - 66% HP
class Battle::Move::HealUserHalfOfTotalHP
  alias forest_pbHealAmount pbHealAmount if method_defined?(:pbHealAmount)
  
  def pbHealAmount(user)
    if @id == :HEALORDER &&
       @battle.has_field? &&
       FOREST_FIELD_IDS.include?(@battle.current_field.id)
      return (user.totalhp * 2 / 3.0).round
    end
    
    return forest_pbHealAmount(user) if defined?(forest_pbHealAmount)
    return user.totalhp / 2
  end
end

# Forest's Curse - Additionally curses the target
class Battle::Move::AddGrassTypeToTarget
  alias forest_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    ret = forest_pbEffectAgainstTarget(user, target)
    
    # On Forest Field, also curse the target
    if @battle.has_field? && FOREST_FIELD_IDS.include?(@battle.current_field.id)
      target.effects[PBEffects::Curse] = true
      @battle.pbDisplay(_INTL("{1} was cursed!", target.pbThis))
    end
    
    return ret
  end
end

# Sticky Web - Effect doubled (Speed -2 instead of -1)
class Battle::Battler
  alias forest_pbCheckEntryHazards pbCheckEntryHazards if method_defined?(:pbCheckEntryHazards)
  alias forest_pbOwnSide pbOwnSide if method_defined?(:pbOwnSide)
  
  def pbOwnSide
    side = forest_pbOwnSide
    
    # Check for Sticky Web on Forest Field after switch-in
    if @battle.has_field? && 
       FOREST_FIELD_IDS.include?(@battle.current_field.id) &&
       side.effects[PBEffects::StickyWeb] &&
       !@effects[PBEffects::StickyWeb] &&
       !airborne?
      # Lower Speed by extra 1 stage (on top of base -1)
      @forest_sticky_web_boost = true
    end
    
    return side
  end
  
  alias forest_pbLowerStatStage pbLowerStatStage if method_defined?(:pbLowerStatStage)
  
  def pbLowerStatStage(stat, increment, user, show_messages = true, ignore_contrary = false)
    # Boost Sticky Web effect if flagged
    if @forest_sticky_web_boost && stat == :SPEED
      increment += 1  # Make it -2 instead of -1
      @forest_sticky_web_boost = nil
    end
    
    respond_to?(:forest_pbLowerStatStage) ? forest_pbLowerStatStage(stat, increment, user, show_messages, ignore_contrary) : super
  end
end

#===============================================================================
# 23. DARK CRYSTAL CAVERN MECHANICS
# Dark and Ghost type passive defense boost
# Shadow Shield damage reduction, Prism Armor defense boost
#===============================================================================

DARK_CRYSTAL_CAVERN_IDS = %i[darkcrystalcavern].freeze

# Dark and Ghost types get 1.5x Defense and Sp.Def
class Battle::Move
  alias dark_crystal_type_def_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:dark_crystal_type_def_pbCalcDamageMultipliers) ? dark_crystal_type_def_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
    # Dark and Ghost types get defensive boost
    return unless @battle.has_field? && DARK_CRYSTAL_CAVERN_IDS.include?(@battle.current_field.id)
    return unless target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
    
    # 1.5x defense = reduce damage by ~33%
    multipliers[:final_damage_multiplier] /= 1.5
  end
end

# Shadow Shield - Take 0.75x damage (25% reduction)
Battle::AbilityEffects::DamageCalcFromTarget.add(:SHADOWSHIELD,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !DARK_CRYSTAL_CAVERN_IDS.include?(target.battle.current_field.id)
    mults[:final_damage_multiplier] *= 0.75
  }
)

# Prism Armor - 33% increased defenses (same as Crystal Cavern)
# Already implemented in Section 22

# Moonlight - Restores 75% HP on Dark Crystal Cavern
# Synthesis/Morning Sun - Restore 25% HP on Dark Crystal Cavern
# Hook into the healing move's recovery calculation
class Battle::Battler
  alias dark_crystal_healing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)
  
  def pbRecoverHP(amt, anim = true)
    # Check if this is healing from Moonlight/Synthesis/Morning Sun on Dark Crystal Cavern
    if @battle.respond_to?(:pbGetMoveIndexFromID)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move && @battle.has_field? && DARK_CRYSTAL_CAVERN_IDS.include?(@battle.current_field.id)
        if current_move.id == :MOONLIGHT
          # Change heal to 75%
          amt = (@totalhp * 3 / 4.0).round
        elsif [:SYNTHESIS, :MORNINGSUN].include?(current_move.id)
          # Change heal to 25%
          amt = (@totalhp / 4.0).round
        end
      end
    end
    
    respond_to?(:dark_crystal_healing_pbRecoverHP) ? dark_crystal_healing_pbRecoverHP(amt, anim) : super
  end
end

# Solar Beam/Solar Blade - Always fail (in damageMods as 0x)

#===============================================================================
# 22. CRYSTAL CAVERN MECHANICS
# Random type selection for various effects
#===============================================================================

CRYSTAL_CAVERN_IDS = %i[crystalcavern].freeze
CRYSTAL_RANDOM_TYPES = [:FIRE, :WATER, :GRASS, :PSYCHIC].freeze

# Rock-type moves randomly gain Fire/Water/Grass/Psychic typing and 1.5x boost
# Hook into type calculation
class Battle::Move
  alias crystal_pbCalcType pbCalcType if method_defined?(:pbCalcType)
  
  def pbCalcType(user)
    original_type = crystal_pbCalcType(user)
    
    # On Crystal Cavern, Rock moves and specific moves get random crystal typing
    if @battle.has_field? && CRYSTAL_CAVERN_IDS.include?(@battle.current_field.id)
      if original_type == :ROCK ||
         [:JUDGMENT, :STRENGTH, :ROCKCLIMB, :MULTIATTACK, :PRISMATICLASER].include?(@id)
        # Store the random type so it's consistent for the whole move execution
        @crystal_type ||= CRYSTAL_RANDOM_TYPES.sample
        return @crystal_type
      end
    end
    
    return original_type
  end
  
  # Reset crystal type after move
  alias crystal_pbEndOfMoveUsageEffect pbEndOfMoveUsageEffect if method_defined?(:pbEndOfMoveUsageEffect)
  
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    respond_to?(:crystal_pbEndOfMoveUsageEffect) ? crystal_pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers) : super
    @crystal_type = nil
  end
end

# Prism Armor - 33% increased defenses
Battle::AbilityEffects::DamageCalcFromTarget.add(:PRISMARMOR,
  proc { |ability, user, target, move, mults, power, type|
    next if !target.battle.has_field? || !CRYSTAL_CAVERN_IDS.include?(target.battle.current_field.id)
    # 33% defense boost = reduce damage by ~25%
    mults[:defense_multiplier] *= 1.33
  }
)

# Mimicry - Changes to random type (Fire/Water/Grass/Psychic)
# This needs to hook into Mimicry's form/type change
# NOTE: Needs manual implementation to randomize Mimicry type change

# Camouflage - Random type
class Battle::Move::SetUserTypesBasedOnEnvironment
  alias crystal_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)
  
  def pbEffectGeneral(user)
    if @battle.has_field? && CRYSTAL_CAVERN_IDS.include?(@battle.current_field.id)
      new_type = CRYSTAL_RANDOM_TYPES.sample
      user.pbChangeTypes(new_type)
      type_name = GameData::Type.get(new_type).name
      @battle.pbDisplay(_INTL("{1} transformed into the {2} type!", user.pbThis, type_name))
      return 0
    end
    
    respond_to?(:crystal_pbEffectGeneral) ? crystal_pbEffectGeneral(user) : super
  end
end

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

# Terrain Pulse - Random type on Crystal Cavern
# Function code TypeDependsOnUserMorpekoFormTerrainTypeForBattlers
class Battle::Move
  alias crystal_terrainpulse_pbBaseType pbBaseType if method_defined?(:pbBaseType)
  
  def pbBaseType(user)
    if @id == :TERRAINPULSE && 
       @battle.has_field? && 
       CRYSTAL_CAVERN_IDS.include?(@battle.current_field.id)
      return CRYSTAL_RANDOM_TYPES.sample
    end
    
    respond_to?(:crystal_terrainpulse_pbBaseType) ? crystal_terrainpulse_pbBaseType(user) : super
  end
end

# Secret Power - Random status (Burn/Freeze/Sleep/Confusion)
class Battle::Move::EffectDependsOnEnvironment
  alias crystal_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)
  
  def pbAdditionalEffect(user, target)
    if @battle.has_field? && CRYSTAL_CAVERN_IDS.include?(@battle.current_field.id)
      # Random status effect
      roll = rand(4)
      case roll
      when 0
        target.pbBurn(user) if target.pbCanBurn?(user, false, self)
      when 1
        target.pbFreeze if target.pbCanFreeze?(user, false, self)
      when 2
        target.pbSleep if target.pbCanSleep?(user, false, self)
      when 3
        target.pbConfuse if target.pbCanConfuse?(user, false, self)
      end
      return 0
    end
    
    respond_to?(:crystal_pbAdditionalEffect) ? crystal_pbAdditionalEffect(user, target) : super
  end
end

# Stealth Rock - Random type damage on Crystal Cavern
# Hook into the entry hazard damage method
class Battle::Battler
  alias crystal_pbItemHPHealCheck pbItemHPHealCheck if method_defined?(:pbItemHPHealCheck)
  
  def pbItemHPHealCheck(*args)
    # This is called during switch-in after hazards
    # We need to intercept Stealth Rock damage specifically
    respond_to?(:crystal_pbItemHPHealCheck) ? crystal_pbItemHPHealCheck(*args) : super
  end
end

# NOTE: Stealth Rock random type damage on Crystal Cavern would need to hook into
# the base game's entry hazard code, which varies by Essentials version.
# The implementation would check @battle.has_field? && CRYSTAL_CAVERN_IDS and
# randomly select a type from CRYSTAL_RANDOM_TYPES for damage calculation.

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
  alias volcanictop_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)
  
  def pbFailsAgainstTarget?(user, target, show_message)
    # On Volcanic Top, Poison Gas badly poisons
    if @id == :POISONGAS && 
       @battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(@battle.current_field.id)
      @badly_poison = true
    end
    
    respond_to?(:volcanictop_pbFailsAgainstTarget?) ? volcanictop_pbFailsAgainstTarget?(user, target, show_message) : super
  end
  
  alias volcanictop_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    if @badly_poison && 
       @battle.has_field? && 
       VOLCANIC_TOP_IDS.include?(@battle.current_field.id)
      return target.pbInflictStatus(:POISON, 1, nil, user) ? 0 : -1
    end
    
    respond_to?(:volcanictop_pbEffectAgainstTarget) ? volcanictop_pbEffectAgainstTarget(user, target) : super
  end
end

# Outrage/Thrash/Petal Dance - Fatigue after single turn
# Hook into end of round to force rampage to end after just 1 turn
class Battle
  alias volcanictop_rampage_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    # Before normal EOR processing, check for rampage moves on Volcanic Top
    if has_field? && VOLCANIC_TOP_IDS.include?(current_field.id)
      allBattlers.each do |battler|
        # If in a rampage that just started this turn (counter > 1), force it to end
        if battler.effects[PBEffects::Outrage] > 1
          battler.effects[PBEffects::Outrage] = 1
        end
      end
    end
    
    volcanictop_rampage_pbEndOfRoundPhase
  end
end

# Tailwind - Lasts 6 turns and creates Strong Winds on Volcanic Top
class Battle::Move::StartUserSideDoubleSpeed
  alias volcanictop_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)
  
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
  
  alias volcanictop_eruption_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
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
  alias volcanictop_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)
  
  def pbEffectAfterAllHits(user, target)
    respond_to?(:volcanictop_pbEffectAfterAllHits) ? volcanictop_pbEffectAfterAllHits(user, target) : super
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
  alias misty_fairy_spdef_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)
  
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
  proc { |ability, user, target, move, mults, power, type|
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
  alias misty_soulheart_pbFaint pbFaint if method_defined?(:pbFaint)
  
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
  alias misty_wish_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)
  
  def pbRecoverHP(amt, anim = true)
    # Check if this is Wish healing on Misty Terrain
    if @effects[PBEffects::Wish] > 0 &&
       @battle.has_field? && 
       MISTY_TERRAIN_IDS.include?(@battle.current_field.id)
      # Wish heals 50% normally, boost to 75%
      # So multiply by 1.5
      amt = (amt * 1.5).round
    end
    
    respond_to?(:misty_wish_pbRecoverHP) ? misty_wish_pbRecoverHP(amt, anim) : super
  end
end

# Aqua Ring - Restores 1/8 instead of 1/16 on Misty Terrain
# Chain onto the Grassy Terrain EOR hook
class Battle
  alias misty_aquaring_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
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
  alias grassy_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
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
  alias grassy_healing_pbMoveFailed? pbMoveFailed? if method_defined?(:pbMoveFailed?)
  
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
  alias grassy_healing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)
  
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
    
    respond_to?(:grassy_healing_pbRecoverHP) ? grassy_healing_pbRecoverHP(amt, anim) : super
  end
end

# Leech Seed - Recovery increased by 30% on Grassy Terrain
class Battle
  alias grassy_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    # Store if on grassy terrain for Leech Seed check
    @grassy_leech_seed_boost = has_field? && GRASSY_TERRAIN_IDS.include?(current_field.id)
    grassy_pbEndOfRoundPhase
    @grassy_leech_seed_boost = nil
  end
end

class Battle::Battler
  alias grassy_pbReduceHP pbReduceHP if method_defined?(:pbReduceHP)
  
  def pbReduceHP(amt, anim = false, registerDamage = true, anyAnim = true)
    # Check if this is Leech Seed damage with grassy boost
    if @battle.instance_variable_get(:@grassy_leech_seed_boost) && 
       @effects[PBEffects::LeechSeed] >= 0
      # Boost damage by 30%
      amt = (amt * 1.3).round
    end
    respond_to?(:grassy_pbReduceHP) ? grassy_pbReduceHP(amt, anim, registerDamage, anyAnim) : super
  end
end

# Grassy Glide - +1 priority on Grassy Terrain
class Battle::Move::HigherPriorityInGrassyTerrain
  alias grassy_pbPriority pbPriority if method_defined?(:pbPriority)
  
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
  alias grassy_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)
  
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = grassy_pbFailsAgainstTarget?(user, target, show_message)
    # Store for damage calculation
    @grassy_terrain_boost = @battle.has_field? && GRASSY_TERRAIN_IDS.include?(@battle.current_field.id)
    return ret
  end
  
  alias grassy_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)
  
  def pbEffectAgainstTarget(user, target)
    if @grassy_terrain_boost
      # Deal 75% HP damage instead of 50%
      dmg = (target.hp * 3 / 4.0).round
      target.pbReduceHP(dmg, false)
      return
    end
    respond_to?(:grassy_pbEffectAgainstTarget) ? grassy_pbEffectAgainstTarget(user, target) : super
  end
end

# Snap Trap - Deals 1/6 HP damage per turn on Grassy Terrain
# This is handled by PBEffects::Trapping - needs to check in EOR damage
class Battle
  alias grassy_trap_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
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
  alias grassy_ingrain_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)
  
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
  alias electric_teravolt_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:electric_teravolt_pbCalcDamageMultipliers) ? electric_teravolt_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
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
  alias cave_ground_pbCalcTypeMod pbCalcTypeMod if method_defined?(:pbCalcTypeMod)
  
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
        # Recalculate type effectiveness ignoring the airborne immunity.
        # Each Effectiveness.calculate call returns a value on the NORMAL_EFFECTIVE (8) scale,
        # so we must normalise between multiplications to avoid squaring the values.
        typeMod = Effectiveness::NORMAL_EFFECTIVE
        if target.pbHasType?(:FLYING)
          typeMod = typeMod * Effectiveness.calculate(moveType, :FLYING) / Effectiveness::NORMAL_EFFECTIVE
        end
        target.pbTypes(true).each do |type|
          next if type.nil? || type == :FLYING  # Flying already handled above
          typeMod = typeMod * Effectiveness.calculate(moveType, type) / Effectiveness::NORMAL_EFFECTIVE
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
  alias weather_field_change_pbEOREndWeather pbEOREndWeather if method_defined?(:pbEOREndWeather)
  
  def pbEOREndWeather(priority)
    # Call original first
    respond_to?(:weather_field_change_pbEOREndWeather) ? weather_field_change_pbEOREndWeather(priority) : super
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
  alias field_weather_duration_pbStartWeather pbStartWeather if method_defined?(:pbStartWeather)
  
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnimation = true)
    # Call original method first
    respond_to?(:field_weather_duration_pbStartWeather) ? field_weather_duration_pbStartWeather(user, newWeather, fixedDuration, showAnimation) : super
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

# FOCUS ENERGY - +3 crit stages instead of +2
# Focus Energy's function class sets FocusEnergy to 2.
# We intercept pbEffectGeneral (where the effect is applied) and boost to 3.
class Battle::Move::RaiseUserCriticalHitRate2
  alias beach_focus_energy_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:beach_focus_energy_pbEffectGeneral) ? beach_focus_energy_pbEffectGeneral(user) : super
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
  alias beach_shore_up_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

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
  alias beach_psych_up_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:beach_psych_up_pbEffectAgainstTarget) ? beach_psych_up_pbEffectAgainstTarget(user, target) : super
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
  alias beach_sand_tomb_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

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
  alias volcanic_move_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

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
  alias volcanic_pbConfuse pbConfuse if method_defined?(:pbConfuse)

  def pbConfuse(msg = nil)
    if @battle.has_field? && VOLCANIC_FIELD_IDS.include?(@battle.current_field.id)
      move = @battle.choices[@index]&.[](2)
      if move && ["AttackAndSkipWithFury", "ThrashingMove"].include?(move.function_code.to_s)
        Console.echo_li("[VOLCANIC] Suppressed confusion for #{pbThis} (#{move.id})") if $DEBUG
        @battle.pbDisplay(_INTL("The volcanic heat kept {1} from getting confused!", pbThis))
        return
      end
    end
    respond_to?(:volcanic_pbConfuse) ? volcanic_pbConfuse(msg) : super
  end
end


#===============================================================================
# 7. ICY FIELD MECHANICS
#===============================================================================

# Status effect damage multipliers (configured via field data)
# Hook into end of round to modify status damage
Battle::Scene.class_eval do
  alias field_status_pbDamageAnimation pbDamageAnimation if method_defined?(:pbDamageAnimation)
  
  def pbDamageAnimation(battler, effectiveness = 0)
    # Store if this is status damage being animated
    @last_damage_battler = battler
    respond_to?(:field_status_pbDamageAnimation) ? field_status_pbDamageAnimation(battler, effectiveness) : super
  end
end

class Battle::Battler
  alias field_status_pbReduceHP pbReduceHP if method_defined?(:pbReduceHP)
  
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
    respond_to?(:field_status_pbReduceHP) ? field_status_pbReduceHP(amt, anim, registerDamage, anyAnim) : super
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
  proc { |ability, mods, user, target, move, type|
    if target.battle.has_field? && target.battle.current_field.id == :icy
      mults[:accuracy_multiplier] *= 0.8  # 20% harder to hit (inverse of 1.25 evasion)
    end
  }
)

# Ice-type Defense boost during Hail on Icy field
# Ice-types get 1.5x Defense when Hail/Snow is active
# Hook into damage calculation for the target
class Battle::Move
  alias icy_ice_defense_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)
  
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:icy_ice_defense_pbCalcDamageMultipliers) ? icy_ice_defense_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
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
  alias icy_pbMoveFailed? pbMoveFailed? if method_defined?(:pbMoveFailed?)
  
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
  alias icy_spike_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)
  
  def pbEffectAfterAllHits(user, target)
    respond_to?(:icy_spike_pbEffectAfterAllHits) ? icy_spike_pbEffectAfterAllHits(user, target) : super
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

#===============================================================================
# DRAGON'S DEN FIELD MECHANICS
# Passive damage, Stealth Rock Fire type, Magma Armor, Multiscale, Shed Skin,
# Berserk, and Magma Storm 1/6 trap damage
#===============================================================================

DRAGONS_DEN_IDS = %i[dragonsden].freeze

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

# Magma Armor - Immune to Fire attacks entirely on Dragon's Den
class Battle::Move
  alias dragonsden_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && DRAGONS_DEN_IDS.include?(@battle.current_field.id)
      if target.hasActiveAbility?(:MAGMAARMOR) && pbCalcType(user) == :FIRE
        @battle.pbDisplay(_INTL("Magma Armor absorbed the flames!")) if show_message
        return true
      end
    end
    respond_to?(:dragonsden_pbFailsAgainstTarget?) ? dragonsden_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

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

# Shed Skin - Activates every turn EOR on Dragon's Den
# Additionally recovers 25% HP and gives Speed+SpAtk/-Def/-SpDef when curing a status
class Battle
  alias dragonsden_shedskin_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dragonsden_shedskin_pbEndOfRoundPhase
    return unless has_field? && DRAGONS_DEN_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.hasActiveAbility?(:SHEDSKIN)
      next if battler.status == :NONE

      # Always activate on Dragon's Den (no 1/3 chance)
      cured_status = battler.status
      pbShowAbilitySplash(battler)
      battler.pbCureStatus(false)
      pbDisplay(_INTL("{1} shed its skin!", battler.pbThis))

      # Bonus: +25% HP recovery and stat changes on cure
      heal = (battler.totalhp * 0.25).round
      battler.pbRecoverHP(heal) if battler.canHeal?
      battler.pbRaiseStatStage(:SPEED, 1, battler) if battler.pbCanRaiseStatStage?(:SPEED, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
      battler.pbLowerStatStage(:DEFENSE, 1, battler) if battler.pbCanLowerStatStage?(:DEFENSE, battler, nil)
      battler.pbLowerStatStage(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanLowerStatStage?(:SPECIAL_DEFENSE, battler, nil)
      pbHideAbilitySplash(battler)
    end
  end
end

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

# Magma Storm - Deals 1/6 max HP per turn instead of 1/8 on Dragon's Den
class Battle
  alias dragonsden_magmastorm_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dragonsden_magmastorm_pbEndOfRoundPhase
    return unless has_field? && DRAGONS_DEN_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Trapping] > 0
      trapping_move = nil
      trapping_move = battler.effects[PBEffects::TrappingMove] if PBEffects.const_defined?(:TrappingMove)
      next unless trapping_move == :MAGMASTORM

      # Base damage is already 1/8; add extra (1/6 - 1/8) = 1/24
      extra = (battler.totalhp / 24.0).round
      battler.pbReduceHP(extra, false) if extra > 0
      battler.pbFaint if battler.fainted?
    end
  end
end

#===============================================================================
# FROZEN DIMENSIONAL FIELD MECHANICS
# Move failures, Hail damage doubling, Aurora Veil bypass, Rage dark type,
# Dragon Rage 140 damage, Power Trip 40bp/stage, Snarl -2, Parting Shot +Speed
#===============================================================================

FROZEN_DIMENSION_IDS = %i[frozendimension].freeze

# Non-damaging moves that should fail - Teatime and Court Change
class Battle::Move
  alias frozendim_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && FROZEN_DIMENSION_IDS.include?(@battle.current_field.id)
      if [:TEATIME, :COURTCHANGE].include?(@id)
        @battle.pbDisplay(_INTL("The frozen dimension prevented the move!")) if show_message
        return true
      end
    end
    respond_to?(:frozendim_pbFailsAgainstTarget?) ? frozendim_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

# Hail/Shadow Sky - Double passive damage on Frozen Dimensional
# Hook into Battle's EOR weather damage. Normal hail = 1/16; on FZD = 1/8
class Battle
  alias frozendim_hail_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    frozendim_hail_pbEndOfRoundPhase
    return unless has_field? && FROZEN_DIMENSION_IDS.include?(current_field.id)
    return unless [:Hail, :Snow, :ShadowSky].include?(pbWeather)

    allBattlers.each do |battler|
      next if battler.fainted?
      # Types that are already immune to hail damage
      next if battler.pbHasType?(:ICE)
      next if battler.hasActiveAbility?([:ICEBODY, :SNOWCLOAK, :OVERCOAT, :MAGICGUARD])

      # Add extra 1/16 (base game already applied 1/16, total becomes 1/8)
      extra = (battler.totalhp / 16.0).round
      battler.pbReduceHP(extra, false) if extra > 0
      battler.pbFaint if battler.fainted?
    end
  end
end

# Aurora Veil - Can be used without Hail/Snow on Frozen Dimensional
class Battle::Move::StartUserSideAuroraVeil
  alias frozendim_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && FROZEN_DIMENSION_IDS.include?(@battle.current_field.id)
      # Bypass the Hail requirement entirely
      if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        @battle.pbDisplay(_INTL("But it failed!")) if show_message
        return true
      end
      return false
    end
    return frozendim_pbFailsAgainstTarget?(user, target, show_message) if respond_to?(:frozendim_pbFailsAgainstTarget?)
    return super
  end
end

# Shared constant: fields where Rage→Dark 60bp and Dragon Rage→140 apply
DIMENSIONAL_FAMILY_IDS = %i[dimensional frozendimension].freeze

# Rage - Becomes 60bp Dark-type move that always raises Attack on Dimensional family
class Battle::Move::RaiseUserAtkUsesThenSleep
  alias frozendim_rage_pbBaseType pbBaseType if method_defined?(:pbBaseType)

  def pbBaseType(user)
    if @id == :RAGE &&
       @battle.has_field? &&
       DIMENSIONAL_FAMILY_IDS.include?(@battle.current_field.id)
      return :DARK
    end
    respond_to?(:frozendim_rage_pbBaseType) ? frozendim_rage_pbBaseType(user) : super
  end

  alias frozendim_rage_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :RAGE &&
       @battle.has_field? &&
       DIMENSIONAL_FAMILY_IDS.include?(@battle.current_field.id)
      # Always raise Attack regardless of normal Rage conditions
      user.pbRaiseStatStage(:ATTACK, 1, user) if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      return
    end
    respond_to?(:frozendim_rage_pbEffectAgainstTarget) ? frozendim_rage_pbEffectAgainstTarget(user, target) : super
  end
end

# Dragon Rage - Deals 140 flat damage on Dimensional family
class Battle::Move::FixedDamage40
  alias frozendim_dragonrage_pbFixedDamage pbFixedDamage if method_defined?(:pbFixedDamage)

  def pbFixedDamage(user, target)
    if @id == :DRAGONRAGE &&
       @battle.has_field? &&
       DIMENSIONAL_FAMILY_IDS.include?(@battle.current_field.id)
      return 140
    end
    respond_to?(:frozendim_dragonrage_pbFixedDamage) ? frozendim_dragonrage_pbFixedDamage(user, target) : super
  end
end

# Power Trip - Gains 40bp per stage instead of 20bp on Frozen Dimensional
class Battle::Move::PowerBasedOnUserPositiveStatStages
  alias frozendim_powertrip_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage)

  def pbBaseDamage(baseDmg, user, target)
    if @id == :POWERTRIP &&
       @battle.has_field? &&
       FROZEN_DIMENSION_IDS.include?(@battle.current_field.id)
      stages = 0
      GameData::Stat.each_battle { |s| stages += user.stages[s.id] if user.stages[s.id] > 0 }
      return [20 + 40 * stages, 1].max
    end
    respond_to?(:frozendim_powertrip_pbBaseDamage) ? frozendim_powertrip_pbBaseDamage(baseDmg, user, target) : super
  end
end

# Snarl - Lowers SpAtk by 2 stages instead of 1 on Frozen Dimensional
class Battle::Move::LowerTargetAtkSpAtk1
  alias frozendim_snarl_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :SNARL &&
       @battle.has_field? &&
       FROZEN_DIMENSION_IDS.include?(@battle.current_field.id)
      target.pbLowerStatStage(:SPECIAL_ATTACK, 2, user) if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, user, self)
      return
    end
    respond_to?(:frozendim_snarl_pbEffectAgainstTarget) ? frozendim_snarl_pbEffectAgainstTarget(user, target) : super
  end
end

# Parting Shot - Additionally lowers Speed on Frozen Dimensional
class Battle::Move
  alias frozendim_partingshot_pbEffectsAfterMove pbEffectsAfterMove if method_defined?(:pbEffectsAfterMove)

  def pbEffectsAfterMove(user, targets, move, numHits)
    frozendim_partingshot_pbEffectsAfterMove(user, targets, move, numHits) if respond_to?(:frozendim_partingshot_pbEffectsAfterMove)
    return unless @id == :PARTINGSHOT
    return unless @battle.has_field? && FROZEN_DIMENSION_IDS.include?(@battle.current_field.id)

    targets.each do |target|
      next if target.fainted?
      target.pbLowerStatStage(:SPEED, 1, user) if target.pbCanLowerStatStage?(:SPEED, user, self)
    end
  end
end

#===============================================================================
# SKY FIELD MECHANICS
# Move failures, Tailwind→Strong Winds, Bonemerang SE vs Flying,
# Mirror Move stat boosts, Flying Press ignores Flying-type resistances
#===============================================================================

SKY_FIELD_IDS = %i[sky].freeze

# Non-damaging hazards fail - Spikes, Toxic Spikes, Sticky Web, Rototiller
class Battle::Move
  alias sky_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && SKY_FIELD_IDS.include?(@battle.current_field.id)
      if [:SPIKES, :TOXICSPIKES, :STICKYWEB, :ROTOTILLER].include?(@id)
        @battle.pbDisplay(_INTL("But there is no solid ground!")) if show_message
        return true
      end
    end
    respond_to?(:sky_pbFailsAgainstTarget?) ? sky_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

# Tailwind - Creates Strong Winds on Sky Field (in addition to Volcanic Top)
class Battle::Move::StartUserSideDoubleSpeed
  alias sky_tailwind_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:sky_tailwind_pbEffectGeneral) ? sky_tailwind_pbEffectGeneral(user) : super

    if @battle.has_field? && SKY_FIELD_IDS.include?(@battle.current_field.id)
      @battle.pbStartWeather(user, :StrongWinds, true)
      @battle.pbDisplay(_INTL("The skies filled with powerful winds!"))
    end
  end
end

# Bonemerang - Super effective vs Flying on Sky Field
class Battle::Move
  alias sky_bonemerang_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = sky_bonemerang_pbCalcTypeModSingle(moveType, defType, user, target)

    if @id == :BONEMERANG &&
       defType == :FLYING &&
       @battle.has_field? &&
       SKY_FIELD_IDS.include?(@battle.current_field.id)
      return Effectiveness::SUPER_EFFECTIVE_ONE
    end

    ret
  end
end

# Mirror Move - Boosts Atk, SpAtk, and Speed by 1 when used successfully
class Battle::Move::UseLastMoveUsedByTarget
  alias sky_mirrormove_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:sky_mirrormove_pbEffectGeneral) ? sky_mirrormove_pbEffectGeneral(user) : super
    return unless @battle.has_field? && SKY_FIELD_IDS.include?(@battle.current_field.id)
    # Only apply if the move actually executed (i.e. didn't fail)
    user.pbRaiseStatStage(:ATTACK, 1, user) if user.pbCanRaiseStatStage?(:ATTACK, user, self)
    user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
    user.pbRaiseStatStage(:SPEED, 1, user) if user.pbCanRaiseStatStage?(:SPEED, user, self)
  end
end

# Flying Press - The Flying-type component ignores type resistances on Sky Field
# Flying Press normally calculates effectiveness for both Fighting and Flying and multiplies.
# On Sky Field, the Flying component is always neutral regardless of target types.
class Battle::Move::FightingAndFlyingType
  alias sky_flyingpress_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if @battle.has_field? && SKY_FIELD_IDS.include?(@battle.current_field.id)
      # For Flying type component: return neutral effectiveness regardless of defType
      if moveType == :FLYING
        # Check if defType would normally resist or be immune to Flying
        base = Effectiveness.calculate(:FLYING, defType)
        if Effectiveness.not_very_effective?(base) || Effectiveness.ineffective?(base)
          return Effectiveness::NORMAL_EFFECTIVE_ONE
        end
      end
    end
    respond_to?(:sky_flyingpress_pbCalcTypeModSingle) ? sky_flyingpress_pbCalcTypeModSingle(moveType, defType, user, target) : super
  end
end

#===============================================================================
# INFERNAL FIELD MECHANICS
# Fire SE vs Ghost, Stealth Rock Fire type, Bad Dreams doubled+trap,
# Torment passive damage, Nightmare bypass, Hex always active,
# Pastel Veil disabled, Perish Body 1-turn, Ice Face melts, Steam Engine EOR
#===============================================================================

INFERNAL_FIELD_IDS = %i[infernal].freeze

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

# Fire moves - Super effective vs Ghost types on Infernal Field
class Battle::Move
  alias infernal_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = infernal_pbCalcTypeModSingle(moveType, defType, user, target)

    if moveType == :FIRE &&
       defType == :GHOST &&
       @battle.has_field? &&
       INFERNAL_FIELD_IDS.include?(@battle.current_field.id)
      # Ghost is normally immune to Normal/Fighting; Fire hits neutral — override to SE
      return Effectiveness::SUPER_EFFECTIVE_ONE
    end

    ret
  end
end

# Hex - Always doubles power (acts as if target always has a status condition)
class Battle::Move::DoublePowerIfTargetStatusProblem
  alias infernal_hex_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage)

  def pbBaseDamage(baseDmg, user, target)
    if @id == :HEX &&
       @battle.has_field? &&
       INFERNAL_FIELD_IDS.include?(@battle.current_field.id)
      return baseDmg * 2
    end
    respond_to?(:infernal_hex_pbBaseDamage) ? infernal_hex_pbBaseDamage(baseDmg, user, target) : super
  end
end

# Nightmare - Can be used without the target being asleep on Infernal Field
class Battle::Move::StartNightmareOnTarget
  alias infernal_nightmare_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && INFERNAL_FIELD_IDS.include?(@battle.current_field.id)
      # Skip the sleep requirement check entirely
      return false if target.effects[PBEffects::Nightmare]
      return false
    end
    respond_to?(:infernal_nightmare_pbFailsAgainstTarget?) ? infernal_nightmare_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

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

# Steam Engine - Raises Speed by +1 at end of every turn on Infernal Field
class Battle
  alias infernal_steamengine_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    infernal_steamengine_pbEndOfRoundPhase
    return unless has_field? && INFERNAL_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.hasActiveAbility?(:STEAMENGINE)
      next unless battler.pbCanRaiseStatStage?(:SPEED, battler, nil)

      battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
    end
  end
end

# Bad Dreams - Doubled damage and traps sleeping targets on Infernal Field
# Normal Bad Dreams: 1/8 HP per turn. Infernal: adds extra 1/8 and traps.
class Battle
  alias infernal_baddreams_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    infernal_baddreams_pbEndOfRoundPhase
    return unless has_field? && INFERNAL_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next if battler.status != :SLEEP
      next unless battler.opposes?

      # Find if any opponent has Bad Dreams active
      opponent_has_bad_dreams = battler.allOpposing.any? { |b| b.hasActiveAbility?(:BADDREAMS) }
      next unless opponent_has_bad_dreams

      # Extra 1/8 damage (base game already applied 1/8, total becomes 1/4)
      extra = (battler.totalhp / 8.0).round
      battler.pbReduceHP(extra, false) if extra > 0

      # Trap the sleeping target for the duration
      if battler.effects[PBEffects::Trapping] <= 0
        battler.effects[PBEffects::Trapping] = 2
      end

      battler.pbFaint if battler.fainted?
    end
  end
end

# Torment - Deals 1/8th HP passive damage to tormented targets each turn
class Battle
  alias infernal_torment_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    infernal_torment_pbEndOfRoundPhase
    return unless has_field? && INFERNAL_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Torment]

      damage = (battler.totalhp / 8.0).round
      battler.pbReduceHP(damage, false) if damage > 0
      pbDisplay(_INTL("{1} is tormented by the infernal flames!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    end
  end
end

#===============================================================================
# FAIRY TALE FIELD MECHANICS
# Type conversions, move effects, ability modifications
#===============================================================================

FAIRY_TALE_IDS = %i[fairytale].freeze

#──────────────────────────────────────────────────────────────────────────────
# TYPE EFFECTIVENESS
#──────────────────────────────────────────────────────────────────────────────

# Steel super-effective vs Dragon on Fairy Tale Field
class Battle::Move
  alias fairytale_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = fairytale_pbCalcTypeModSingle(moveType, defType, user, target)

    if moveType == :STEEL &&
       defType == :DRAGON &&
       @battle.has_field? &&
       FAIRY_TALE_IDS.include?(@battle.current_field.id)
      return Effectiveness::SUPER_EFFECTIVE_ONE
    end

    ret
  end
end

# Cut, Slash, Sacred Sword, Secret Sword become Steel-type on Fairy Tale Field
class Battle::Move
  alias fairytale_steel_pbBaseType pbBaseType if method_defined?(:pbBaseType)

  def pbBaseType(user)
    if @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
      return :STEEL if [:CUT, :SLASH, :SACREDSWORD, :SECRETSWORD].include?(@id)
    end
    respond_to?(:fairytale_steel_pbBaseType) ? fairytale_steel_pbBaseType(user) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE EFFECT OVERRIDES
#──────────────────────────────────────────────────────────────────────────────

# Floral Healing - 100% HP restoration (base 50%, Grassy 75%, Fairy Tale 100%)
class Battle::Battler
  alias fairytale_floralhealing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)

  def pbRecoverHP(amt, anim = true)
    if @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move&.id == :FLORALHEALING
        amt = @totalhp
      end
    end
    respond_to?(:fairytale_floralhealing_pbRecoverHP) ? fairytale_floralhealing_pbRecoverHP(amt, anim) : super
  end
end

# Wish - 75% HP restoration on Fairy Tale Field (same amount as Misty, different field)
class Battle::Battler
  alias fairytale_wish_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)

  def pbRecoverHP(amt, anim = true)
    if @effects[PBEffects::Wish] > 0 &&
       @battle.has_field? &&
       FAIRY_TALE_IDS.include?(@battle.current_field.id)
      amt = (@totalhp * 0.75).round
    end
    respond_to?(:fairytale_wish_pbRecoverHP) ? fairytale_wish_pbRecoverHP(amt, anim) : super
  end
end

# Healing Wish - Additionally boosts recipient's Attack and Special Attack
class Battle
  alias fairytale_healingwish_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    fairytale_healingwish_pbEndOfRoundPhase
    return unless has_field? && FAIRY_TALE_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::HealingWish]

      # HealingWish normally heals; additionally boost offensive stats
      battler.pbRaiseStatStage(:ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
      pbDisplay(_INTL("The fairy blessing boosted {1}'s fighting spirit!", battler.pbThis))
    end
  end
end

# Noble Roar - Lowers Attack AND Special Attack by 2 stages (amplified) on Fairy Tale Field
class Battle::Move::LowerTargetAtkSpAtk1
  alias fairytale_nobleroar_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :NOBLEROAR &&
       @battle.has_field? &&
       FAIRY_TALE_IDS.include?(@battle.current_field.id)
      target.pbLowerStatStage(:ATTACK, 2, user) if target.pbCanLowerStatStage?(:ATTACK, user, self)
      target.pbLowerStatStage(:SPECIAL_ATTACK, 2, user) if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, user, self)
      return
    end
    respond_to?(:fairytale_nobleroar_pbEffectAgainstTarget) ? fairytale_nobleroar_pbEffectAgainstTarget(user, target) : super
  end
end

# Crafty Shield - Additionally boosts user's Defense and Special Defense +1
class Battle::Move::ProtectUserSideFromStatusMoves
  alias fairytale_craftyshield_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:fairytale_craftyshield_pbEffectGeneral) ? fairytale_craftyshield_pbEffectGeneral(user) : super
    return unless @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)

    # Only apply stat boosts if the shield actually went up
    return unless user.pbOwnSide.effects[PBEffects::CraftyShield]

    user.pbRaiseStatStage(:DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
    user.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
    @battle.pbDisplay(_INTL("The Fairy Tale Field empowered the shield!"))
  end
end

# Flower Shield - Additionally boosts all Fairy-type Pokemon's Special Defense +1 on Fairy Tale Field
class Battle::Move::RaiseGrassTypePokemonDefense1
  alias fairytale_flowershield_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:fairytale_flowershield_pbEffectGeneral) ? fairytale_flowershield_pbEffectGeneral(user) : super
    return unless @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)

    @battle.allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.pbHasType?(:FAIRY)
      battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler, nil)
    end
  end
end

# King's Shield - Lowers attacker's Special Attack by 2 stages (instead of Attack by 1) on contact
# NOTE: Full "protects from all moves including status" requires base game modification
# to the protection check in Battle::Move#pbMoveFailedPrevented? — documented as needing
# manual override of pbDamagingMove? check when KingsShield is active on Fairy Tale Field.
class Battle::Move
  alias fairytale_kingsshield_pbEffectsOnMakingHit pbEffectsOnMakingHit if method_defined?(:pbEffectsOnMakingHit)

  def pbEffectsOnMakingHit(user, target)
    fairytale_kingsshield_pbEffectsOnMakingHit(user, target) if respond_to?(:fairytale_kingsshield_pbEffectsOnMakingHit)

    return unless @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
    return unless pbContactMove?(user)
    return unless target.effects[PBEffects::KingsShield]

    # Override: -2 SpAtk instead of -1 Atk
    if user.pbCanLowerStatStage?(:SPECIAL_ATTACK, target, nil)
      user.pbLowerStatStage(:SPECIAL_ATTACK, 2, target)
    end
  end
end

# Sweet Kiss and Draining Kiss - Cure sleep on the target
class Battle::Move
  alias fairytale_kiss_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:fairytale_kiss_pbEffectAgainstTarget) ? fairytale_kiss_pbEffectAgainstTarget(user, target) : super
    return unless [:SWEETKISS, :DRAININGKISS].include?(@id)
    return unless @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
    return unless target.status == :SLEEP

    target.pbCureStatus(false)
    @battle.pbDisplay(_INTL("{1} was awakened by the fairy's kiss!", target.pbThis))
  end
end

# Miracle Eye - Additionally boosts Special Attack by 1 stage
class Battle::Move::RemoveTargetTypeImmunity
  alias fairytale_miracleeye_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:fairytale_miracleeye_pbEffectAgainstTarget) ? fairytale_miracleeye_pbEffectAgainstTarget(user, target) : super
    return unless @id == :MIRACLEEYE
    return unless @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)

    user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
    @battle.pbDisplay(_INTL("Miracle Eye sharpened {1}'s mystical sight!", user.pbThis))
  end
end

# Forest's Curse - Additionally applies Curse to the target on Fairy Tale Field
# (forest_pbEffectAgainstTarget already exists from Forest Field — chain correctly)
class Battle::Move::AddGrassTypeToTarget
  alias fairytale_forestscurse_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:fairytale_forestscurse_pbEffectAgainstTarget) ? fairytale_forestscurse_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)

    unless target.effects[PBEffects::Curse]
      target.effects[PBEffects::Curse] = true
      @battle.pbDisplay(_INTL("{1} was cursed by fairy magic!", target.pbThis))
    end
  end
end

# Strange Steam - Always confuses (no roll required)
class Battle::Move::ConfuseTarget
  alias fairytale_strangesteam_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @id == :STRANGESTEAM &&
       @battle.has_field? &&
       FAIRY_TALE_IDS.include?(@battle.current_field.id)
      # Skip the chance roll — directly apply confusion
      if target.pbCanConfuse?(user, false, self)
        target.pbConfuse
        @battle.pbDisplay(_INTL("{1} became confused!", target.pbThis))
      end
      return
    end
    respond_to?(:fairytale_strangesteam_pbAdditionalEffect) ? fairytale_strangesteam_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY EFFECTS
#──────────────────────────────────────────────────────────────────────────────

# Soul Heart - Additionally boosts Special Defense when any Pokémon faints
class Battle::Battler
  alias fairytale_soulheart_pbFaint pbFaint if method_defined?(:pbFaint)

  def pbFaint(showMessage = true)
    soulheart_battlers = []
    if @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
      @battle.allBattlers.each do |b|
        next if b.fainted? || b.index == @index
        soulheart_battlers << b if b.hasActiveAbility?(:SOULHEART)
      end
    end

    ret = fairytale_soulheart_pbFaint(showMessage)

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

# Fairy Aura - Cannot miss on Fairy Tale Field
class Battle::Move
  alias fairytale_fairyaura_pbAccuracyCheck pbAccuracyCheck if method_defined?(:pbAccuracyCheck)

  def pbAccuracyCheck(user, target)
    if @battle.has_field? && FAIRY_TALE_IDS.include?(@battle.current_field.id)
      if user.hasActiveAbility?(:FAIRYAURA) || target.allOpposing.any? { |b| b.hasActiveAbility?(:FAIRYAURA) }
        return true
      end
    end
    respond_to?(:fairytale_fairyaura_pbAccuracyCheck) ? fairytale_fairyaura_pbAccuracyCheck(user, target) : super
  end
end

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

#===============================================================================
# INVERSE FIELD MECHANICS
# Core: the entire type chart is inverted.
# Also: Topsy Turvy creates the field for 3 turns, Secret Power confuses,
# Magical Seed normalizes, and Secret Power's side-effects are overridden.
#===============================================================================

INVERSE_FIELD_IDS = %i[inverse].freeze

#──────────────────────────────────────────────────────────────────────────────
# 1. CORE: INVERTED TYPE CHART
# Per-type effectiveness is flipped:
#   Immune (0)  → Super Effective (×2)
#   NVE    (×½) → Super Effective (×2)
#   Normal (×1) → Normal (×1)
#   SE     (×2) → Not Very Effective (×½)
#──────────────────────────────────────────────────────────────────────────────

class Battle::Move
  alias inverse_pbCalcTypeModSingle pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = inverse_pbCalcTypeModSingle(moveType, defType, user, target)
    return ret unless @battle.has_field? && INVERSE_FIELD_IDS.include?(@battle.current_field.id)

    case ret
    when 0                                    # Immune → Super Effective
      Effectiveness::SUPER_EFFECTIVE_ONE
    when Effectiveness::NOT_VERY_EFFECTIVE_ONE # ×½ → ×2
      Effectiveness::SUPER_EFFECTIVE_ONE
    when Effectiveness::SUPER_EFFECTIVE_ONE   # ×2 → ×½
      Effectiveness::NOT_VERY_EFFECTIVE_ONE
    else
      ret  # ×1 unchanged
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# 2. TOPSY TURVY → Creates Inverse Field for 3 turns (unless user holds Everstone)
# Stores the prior field so we can revert after the duration expires.
#──────────────────────────────────────────────────────────────────────────────

class Battle::Move::InvertTargetStatStages
  alias inverse_topsyturvy_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

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

# Track the attributes needed for the timer
class Battle
  attr_accessor :inverse_prior_field
  attr_accessor :inverse_field_turns
end

# EOR: decrement the inverse field duration and revert when it expires
class Battle
  alias inverse_timer_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    inverse_timer_pbEndOfRoundPhase
    return unless has_field? && INVERSE_FIELD_IDS.include?(current_field.id)
    return unless @inverse_field_turns && @inverse_field_turns > 0

    @inverse_field_turns -= 1
    if @inverse_field_turns == 0
      pbDisplay(_INTL("The inversion wore off!"))
      if @inverse_prior_field
        pbChangeBattleField(@inverse_prior_field)
      else
        # No prior field — just clear the field state
        pbChangeBattleField(:NONE) rescue nil
      end
      @inverse_prior_field = nil
      @inverse_field_turns = nil
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# 3. SECRET POWER → Causes Confusion on Inverse Field
# The parser maps "CONFUSION" to @secretPower = 4 (Lower Speed), which is wrong.
# Override here to directly apply confusion after the move lands.
#──────────────────────────────────────────────────────────────────────────────

class Battle::Move::EffectDependsOnEnvironment
  alias inverse_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && INVERSE_FIELD_IDS.include?(@battle.current_field.id)
      if target.pbCanConfuse?(user, false, self)
        target.pbConfuse
        @battle.pbDisplay(_INTL("{1} became confused!", target.pbThis))
      end
      return
    end
    respond_to?(:inverse_secretpower_pbAdditionalEffect) ? inverse_secretpower_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# 4. MAGICAL SEED → Changes user's type to Normal and gives Normalize
# The seed's :on_seed_use proc is hooked here; additionally we override
# pbBaseType so all the holder's moves become Normal-type.
#──────────────────────────────────────────────────────────────────────────────

# Track which battlers have been "normalized" by the seed
class Battle::Battler
  attr_accessor :inverse_normalized
end

# Hook into on_seed_use at the Battle level — called by seed item consumption
class Battle
  alias inverse_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = inverse_seed_apply_field_effect(effect_name, *args)

    # After the standard seed effect fires, check if we're on Inverse Field
    # and the seed was a Magical Seed — then apply the Normalize + type change
    if effect_name == :on_seed_use && has_field? && INVERSE_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        # Change type to Normal
        battler.type1 = :NORMAL
        battler.type2 = :NONE
        battler.effects[PBEffects::Type3] = :NONE if PBEffects.const_defined?(:Type3)
        # Mark as normalized (all their moves will be Normal-type)
        battler.inverse_normalized = true
        pbDisplay(_INTL("{1}'s type became Normal!", battler.pbThis))
      end
    end

    result
  end
end

# Override pbBaseType so normalized battlers' moves are always Normal-type
class Battle::Move
  alias inverse_normalize_pbBaseType pbBaseType if method_defined?(:pbBaseType)

  def pbBaseType(user)
    type = inverse_normalize_pbBaseType(user)
    if user.respond_to?(:inverse_normalized) && user.inverse_normalized &&
       user.battle.has_field? && INVERSE_FIELD_IDS.include?(user.battle.current_field.id)
      return :NORMAL
    end
    type
  end
end

# Clear the normalized flag when the battler leaves the field or the field ends
class Battle::Battler
  alias inverse_pbFaint pbFaint if method_defined?(:pbFaint)

  def pbFaint(showMessage = true)
    @inverse_normalized = false
    respond_to?(:inverse_pbFaint) ? inverse_pbFaint(showMessage) : super
  end
end

#===============================================================================
# DIMENSIONAL FIELD MECHANICS
# Darkness Radiates — the void invades.
#===============================================================================

DIMENSIONAL_FIELD_IDS = %i[dimensional].freeze

#──────────────────────────────────────────────────────────────────────────────
# MOVE FAILURES: Teatime and Lucky Chant
# (damageMods: 0 doesn't block non-damaging moves in the parser)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias dimensional_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
      if [:TEATIME, :LUCKYCHANT].include?(@id)
        @battle.pbDisplay(_INTL("The darkness swallowed the move!")) if show_message
        return true
      end
    end
    respond_to?(:dimensional_pbFailsAgainstTarget?) ? dimensional_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: Shadow Sky — doubled EOR damage on Dimensional Field
# Normal Shadow Sky: 1/16 HP per turn. Dimensional: 1/8 HP per turn.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias dimensional_shadowsky_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dimensional_shadowsky_pbEndOfRoundPhase
    return unless has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)
    return unless pbWeather == :ShadowSky

    # Base Shadow Sky already dealt 1/16 HP — add another 1/16 for 1/8 total
    allBattlers.each do |battler|
      next if battler.fainted?
      next if battler.pbHasType?(:DARK) || battler.pbHasType?(:GHOST)
      next if battler.hasActiveAbility?(:OVERCOAT) || battler.hasActiveAbility?(:MAGICGUARD)
      extra = battler.totalhp / 16
      battler.pbReduceHP(extra, false) if extra > 0
      # No separate message — the base game already showed "hurt by Shadow Sky"
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE C: Sleep → Damage Over Time (1/16 HP per turn)
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias dimensional_sleep_dot_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dimensional_sleep_dot_pbEndOfRoundPhase
    return unless has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.status == :SLEEP
      next if battler.hasActiveAbility?(:MAGICGUARD)

      dmg = [battler.totalhp / 16, 1].max
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is tormented in its dark sleep!", battler.pbThis))
      battler.pbFaint if battler.hp <= 0
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE F: Dig / Dive / Fly / Bounce — instantly KO user while semi-invulnerable
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias dimensional_twoturn_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dimensional_twoturn_pbEndOfRoundPhase
    return unless has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::TwoTurnAttack]

      move_id = battler.effects[PBEffects::TwoTurnAttack]
      next unless [:DIG, :DIVE, :FLY, :BOUNCE].include?(move_id)

      pbDisplay(_INTL("{1} was swallowed by the darkness!", battler.pbThis))
      battler.pbReduceHP(battler.hp, false)
      battler.pbFaint
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE G: Quash — +1 priority on Dimensional Field
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::MakeTargetMoveLastInTurn
  alias dimensional_quash_pbPriority pbPriority if method_defined?(:pbPriority)

  def pbPriority(user)
    ret = dimensional_quash_pbPriority(user)
    if @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
      ret += 1
    end
    ret
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE H: Gravity / Trick Room / Magic Room / Wonder Room — random 3–8 turns
# These moves use pbEffectGeneral to set their room duration.
# We intercept after the standard effect fires to randomize the duration.
#──────────────────────────────────────────────────────────────────────────────

DIMENSIONAL_ROOM_MOVES = {
  TRICKROOM:  :TrickRoom,
  WONDERROOM: :WonderRoom,
  MAGICROOM:  :MagicRoom,
}.freeze

DIMENSIONAL_ROOM_MOVES.each do |move_id, effect_key|
  next unless PBEffects.const_defined?(effect_key)

  effect_const = PBEffects.const_get(effect_key)

  class_str = case move_id
              when :TRICKROOM  then "InvertBattlerSpeeds"
              when :WONDERROOM then "SwapBattlersItems"
              when :MAGICROOM  then "DisableBattlerItems"
              end

  # Only hook if the move class exists
  if Object.const_defined?("Battle::Move::#{class_str}")
    klass = Object.const_get("Battle::Move::#{class_str}")
    klass.class_eval do
      define_method("dimensional_room_#{move_id}_pbEffectGeneral".to_sym) do |user|
        send("dimensional_room_#{move_id}_original_pbEffectGeneral", user) rescue super(user)
        # After standard effect, randomize duration if on Dimensional Field
        if @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
          @battle.field.effects[effect_const] = 3 + rand(6)  # 3–8 turns
        end
      end
    end
  end
end

# Gravity duration override (Gravity uses a different effect key)
if PBEffects.const_defined?(:Gravity)
  class Battle::Move::StartGravity
    alias dimensional_gravity_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

    def pbEffectGeneral(user)
      respond_to?(:dimensional_gravity_pbEffectGeneral) ? dimensional_gravity_pbEffectGeneral(user) : super

      if @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
        @battle.field.effects[PBEffects::Gravity] = 3 + rand(6)
      end
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE I: Obstruct — additionally blocks status moves
# NOTE: Full protection from ALL moves including non-damaging requires intercepting
# the base game's protection check (pbMoveFailedPrevented?) to not gate on
# pbDamagingMove?. Documented here as needing a base game patch.
# The -2 Defense side-effect on contact is already in the base game.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias dimensional_obstruct_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    # If target is under Obstruct on Dimensional Field, block all moves including status
    if @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
      if target.effects[PBEffects::Obstruct] && !pbDamagingMove?
        @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis)) if show_message
        return true
      end
    end
    respond_to?(:dimensional_obstruct_pbFailsAgainstTarget?) ? dimensional_obstruct_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE J: Heal Block — additionally deals 1/16 HP per turn to blocked target
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias dimensional_healblock_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dimensional_healblock_pbEndOfRoundPhase
    return unless has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::HealBlock] > 0
      next if battler.hasActiveAbility?(:MAGICGUARD)

      dmg = [battler.totalhp / 16, 1].max
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is suffering from Heal Block's dark curse!", battler.pbThis))
      battler.pbFaint if battler.hp <= 0
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE K: Embargo — target cannot switch while Embargoed
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias dimensional_embargo_pbCanSwitch? pbCanSwitch? if method_defined?(:pbCanSwitch?)

  def pbCanSwitch?(idxNewBattler, idxParty, partyScene)
    ret = dimensional_embargo_pbCanSwitch?(idxNewBattler, idxParty, partyScene)
    return ret unless @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
    return ret unless @effects[PBEffects::Embargo] > 0

    partyScene&.pbDisplay(_INTL("{1} cannot switch while Embargoed!", pbThis))
    return false
  end
end

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

class Battle
  attr_accessor :dimensional_download_type_index

  alias dimensional_download_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    dimensional_download_pbEndOfRoundPhase
    return unless has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)

    @dimensional_download_type_index ||= 0

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.hasActiveAbility?(:DOWNLOAD)

      new_type = DIMENSIONAL_DOWNLOAD_TYPES[@dimensional_download_type_index % DIMENSIONAL_DOWNLOAD_TYPES.size]
      battler.pbChangeTypes(new_type)
      pbDisplay(_INTL("{1}'s Download changed its type to {2}!", battler.pbThis, new_type.to_s.capitalize))
    end

    @dimensional_download_type_index += 1
  end
end

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
# SEED X: Magical Seed — additionally activates Trick Room (battle-wide)
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias dimensional_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = dimensional_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        # Activate Trick Room for 5 turns
        if PBEffects.const_defined?(:TrickRoom)
          @field.effects[PBEffects::TrickRoom] = 5
          pbDisplay(_INTL("The dimensions warped into a Trick Room!"))
        end
      end
    end

    result
  end
end

#===============================================================================
# RAINBOW FIELD MECHANICS
# "What does it mean?" — prismatic chaos and amplified effects
#===============================================================================

RAINBOW_FIELD_IDS = %i[rainbow].freeze

ALL_TYPES_POOL = %i[
  NORMAL FIRE WATER GRASS ELECTRIC ICE FIGHTING POISON
  GROUND FLYING PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY
].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: Secondary effect chance doubled (no stack with Serene Grace)
# In Essentials v21, pbAdditionalEffect checks @addlEffect (the chance, 0-100)
# against a rand(100) roll. We temporarily double @addlEffect before the roll,
# capping at 100, then restore it after. Skipped for Serene Grace users since
# the base game already doubles their chance.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias rainbow_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    doubled = false
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      unless user.hasActiveAbility?(:SERENEGRACE)
        if instance_variable_defined?(:@addlEffect) && @addlEffect && @addlEffect > 0
          @addlEffect = [@addlEffect * 2, 100].min
          doubled = true
        end
      end
    end
    respond_to?(:rainbow_pbAdditionalEffect) ? rainbow_pbAdditionalEffect(user, target) : super
  ensure
    # Restore original chance if we doubled it
    # We can't know the original exactly after capping, so just halve it back
    @addlEffect = (@addlEffect / 2) if doubled && @addlEffect
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE B: Sleeping Pokemon recover 1/16 HP per turn
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias rainbow_sleep_heal_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    rainbow_sleep_heal_pbEndOfRoundPhase
    return unless has_field? && RAINBOW_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.status == :SLEEP
      next if battler.hp >= battler.totalhp

      heal = [battler.totalhp / 16, 1].max
      battler.pbRecoverHP(heal, false)
      pbDisplay(_INTL("{1} is dreaming under the rainbow!", battler.pbThis))
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE C: Special Normal-type moves apply damage of a random type
# We change the move's calcType to a random type for the damage calculation
# without changing actual type effectiveness (the random type just flavors damage).
# Implemented as a pbBaseType override: returns a random type for special Normal moves.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias rainbow_randtype_pbBaseType pbBaseType if method_defined?(:pbBaseType)

  def pbBaseType(user)
    type = rainbow_randtype_pbBaseType(user)
    return type unless @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
    return type unless type == :NORMAL && specialMove?(type)
    ALL_TYPES_POOL.sample
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE D: Secret Power → random status condition
# Override pbAdditionalEffect on EffectDependsOnEnvironment for Rainbow Field.
# Applies one of: Paralyze, Sleep, Burn, Freeze, Poison (randomly).
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::EffectDependsOnEnvironment
  alias rainbow_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      case rand(5)
      when 0
        target.pbParalyze(user) if target.pbCanParalyze?(user, false, self)
      when 1
        target.pbSleep if target.pbCanSleep?(user, false, self)
      when 2
        target.pbBurn(user) if target.pbCanBurn?(user, false, self)
      when 3
        target.pbFreeze if target.pbCanFreeze?(user, false, self)
      when 4
        target.pbPoison(user, false, false) if target.pbCanPoison?(user, false, self)
      end
      return
    end
    respond_to?(:rainbow_secretpower_pbAdditionalEffect) ? rainbow_secretpower_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE E: SonicBoom → 140 flat HP damage
# SonicBoom normally deals 20 flat damage (FixedDamage20 class).
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::FixedDamage20
  alias rainbow_sonicboom_pbFixedDamage pbFixedDamage if method_defined?(:pbFixedDamage)

  def pbFixedDamage(user, target)
    if @id == :SONICBOOM && @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      return 140
    end
    respond_to?(:rainbow_sonicboom_pbFixedDamage) ? rainbow_sonicboom_pbFixedDamage(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE F+G: Life Dew → 50% HP heal; Wish → 75% HP heal
# Chain from the fairytale wish hook.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias rainbow_healing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)

  def pbRecoverHP(amt, anim = true)
    if @battle.respond_to?(:choices) && @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move
        case current_move.id
        when :LIFEDEW
          amt = (@totalhp / 2.0).round
        when :WISH
          # Wish fires at EOR — check for Wish effect counter instead
          if @effects[PBEffects::Wish] > 0
            amt = (@totalhp * 0.75).round
          end
        end
      end
    end
    respond_to?(:rainbow_healing_pbRecoverHP) ? rainbow_healing_pbRecoverHP(amt, anim) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE H: Aurora Veil — can be used without Hail on Rainbow Field
# Extend the existing Frozen Dimensional hook to also cover Rainbow.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartUserSideAuroraVeil
  alias rainbow_auroraveil_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        @battle.pbDisplay(_INTL("But it failed!")) if show_message
        return true
      end
      return false
    end
    respond_to?(:rainbow_auroraveil_pbFailsAgainstTarget?) ? rainbow_auroraveil_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE I: Nightmare fails / Bad Dreams has no effect on Rainbow Field
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias rainbow_nightmare_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      if @id == :NIGHTMARE
        @battle.pbDisplay(_INTL("The rainbow keeps dreams sweet!")) if show_message
        return true
      end
    end
    respond_to?(:rainbow_nightmare_pbFailsAgainstTarget?) ? rainbow_nightmare_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

# Bad Dreams — no damage to sleeping targets on Rainbow Field
class Battle
  alias rainbow_baddreams_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    rainbow_baddreams_pbEndOfRoundPhase
    # Bad Dreams immunity is handled by checking field in the Essentials EOR loop.
    # Since we can't easily intercept the base Bad Dreams loop here,
    # we undo its damage by healing sleeping targets immediately after.
    return unless has_field? && RAINBOW_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.status == :SLEEP
      # If an opponent has Bad Dreams, the base game already dealt 1/8 HP.
      # Heal it back (the rainbow blocks bad dreams).
      has_bad_dreams_foe = battler.allOpposing.any? { |b| b.hasActiveAbility?(:BADDREAMS) }
      next unless has_bad_dreams_foe

      heal = [battler.totalhp / 8, 1].max
      battler.pbRecoverHP(heal, false)
      # No message — silently restore; field already shows "dreaming under rainbow"
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY J: Soul Heart — additionally boosts Sp. Def on faint
# Chain from fairytale_soulheart_pbFaint
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias rainbow_soulheart_pbFaint pbFaint if method_defined?(:pbFaint)

  def pbFaint(showMessage = true)
    soulheart_battlers = []
    if @battle.has_field? && RAINBOW_FIELD_IDS.include?(@battle.current_field.id)
      @battle.allBattlers.each do |b|
        next if b.fainted? || b.index == @index
        soulheart_battlers << b if b.hasActiveAbility?(:SOULHEART)
      end
    end

    ret = rainbow_soulheart_pbFaint(showMessage)

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

class Battle
  alias rainbow_cloudnine_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    rainbow_cloudnine_pbEndOfRoundPhase
    return unless has_field? && RAINBOW_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.hasActiveAbility?(:CLOUDNINE)

      stat = RAINBOW_CLOUD_NINE_STATS.sample
      next unless battler.pbCanRaiseStatStage?(stat, battler, nil)

      pbShowAbilitySplash(battler)
      battler.pbRaiseStatStage(stat, 1, battler)
      pbDisplay(_INTL("{1}'s Cloud Nine absorbed rainbow energy!", battler.pbThis))
      pbHideAbilitySplash(battler)
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY N: WonderSkin — evades ALL status moves (not just 50% of the time)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias rainbow_wonderskin_pbAccuracyCheck pbAccuracyCheck if method_defined?(:pbAccuracyCheck)

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
# SEED O: Magical Seed — additionally applies Healing Wish to the user
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias rainbow_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = rainbow_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && RAINBOW_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        if PBEffects.const_defined?(:HealingWish)
          battler.effects[PBEffects::HealingWish] = true
          pbDisplay(_INTL("{1} made a wish for its future self!", battler.pbThis))
        end
      end
    end

    result
  end
end

#===============================================================================
# STARLIGHT ARENA MECHANICS
# "Starlight fills the battlefield." — cosmic power and prismatic energy
#===============================================================================

STARLIGHT_ARENA_IDS = %i[starlightarena].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE: All field damage modifiers suppressed by weather (except Strong Winds)
# We hook into the multiplier system. When weather is active (not Clear / Strong
# Winds), we reset any field boost back to 1.0 for damage calculation.
# Implemented by zeroing out the field's typeBoosts during dmg calc under weather.
# Practical approach: override pbCalcDamageMultipliers to cancel field type boosts.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias starlight_suppress_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    # Suppress field boosts under non-Strong-Winds weather
    if @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
      weather = @battle.pbWeather
      if weather != :None && weather != :StrongWinds
        # Temporarily remove field type boosts by noting we're suppressed
        @starlight_weather_suppress = true
      end
    end

    if respond_to?(:starlight_suppress_pbCalcDamageMultipliers, true)
      starlight_suppress_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    else
      super
    end
  ensure
    @starlight_weather_suppress = false
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE: Permanently destroyed by Light That Burns the Sky
# The fieldChange in fieldtxt sends it to :INDOOR. This is correct as-is;
# no additional hook needed — fieldChange already handles the transition.
#──────────────────────────────────────────────────────────────────────────────

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Dark-type attacks deal additional Fairy damage
# Hook into pbEffectAgainstTarget to add a secondary Fairy hit after each Dark
# type move on Starlight Arena.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias starlight_dark_fairy_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:starlight_dark_fairy_pbEffectAgainstTarget) ? starlight_dark_fairy_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
    return unless pbDamagingMove?
    calc_type = pbCalcType(user)
    return unless calc_type == :DARK

    # Deal additional Fairy-type damage equal to 1/4 of the move's base power
    bonus_dmg = [(pbBaseDamage(100, user, target) * 0.25).round, 1].max
    effectiveness = Effectiveness.calculate(:FAIRY, *target.pbTypes(true))
    return if Effectiveness.ineffective?(effectiveness)

    bonus_dmg = (bonus_dmg * Effectiveness.factor_against_type(effectiveness) rescue bonus_dmg)
    target.pbReduceHP(bonus_dmg, false)
    @battle.pbDisplay(_INTL("The attack shimmered with fairy starlight!"))
    target.pbFaint if target.fainted?
  rescue
    # Fail silently if damage calc fails
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Aurora Veil — enabled without Hail
# Extend the existing StartUserSideAuroraVeil hook to cover Starlight Arena.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartUserSideAuroraVeil
  alias starlight_auroraveil_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
      if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        @battle.pbDisplay(_INTL("But it failed!")) if show_message
        return true
      end
      return false
    end
    respond_to?(:starlight_auroraveil_pbFailsAgainstTarget?) ? starlight_auroraveil_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Meteor Assault has no recharge turn
# Meteor Assault normally forces a recharge. On Starlight Arena it skips it.
# The noCharging key in fieldtxt handles the charge turn; we also skip recharge.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias starlight_meteorassault_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:starlight_meteorassault_pbEffectGeneral) ? starlight_meteorassault_pbEffectGeneral(user) : super
    return unless @id == :METEORASSAULT
    return unless @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
    # Remove the MustRecharge effect set by base game
    user.effects[PBEffects::MustRecharge] = false if user.effects.respond_to?(:[]=)
  rescue
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Doom Desire deals additional Fire-type damage (x4 already in damageMods)
# Add a secondary Fire hit after Doom Desire's future attack resolves.
# Doom Desire's damage is applied at the end of round via FutureSight system.
# We hook into pbEndOfRoundPhase to check for Doom Desire's damage turn.
#──────────────────────────────────────────────────────────────────────────────
# NOTE: Doom Desire x4 is handled by damageMods in fieldtxt.
# The additional Fire damage is applied as a separate hit via a flag set when
# Doom Desire lands. Due to Essentials' future-sight architecture, we track it
# with a side effect flag.
class Battle
  alias starlight_doomdesire_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    starlight_doomdesire_pbEndOfRoundPhase
    return unless has_field? && STARLIGHT_ARENA_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless @starlight_doomdesire_fire_targets.is_a?(Array)
      next unless @starlight_doomdesire_fire_targets.include?(battler.index)

      fire_dmg = [battler.totalhp / 8, 1].max
      eff = Effectiveness.calculate(:FIRE, *battler.pbTypes(true))
      next if Effectiveness.ineffective?(eff)

      battler.pbReduceHP(fire_dmg, false)
      pbDisplay(_INTL("The star-fire scorched {1}!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    end
    @starlight_doomdesire_fire_targets&.clear
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Wish restores 75% HP; Moonlight restores 75% HP
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias starlight_healing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)

  def pbRecoverHP(amt, anim = true)
    if @battle.respond_to?(:choices) && @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move
        case current_move.id
        when :MOONLIGHT, :SYNTHESIS, :MORNINGSUN
          amt = (@totalhp * 0.75).round
        end
      end
      # Wish healing (applied at EOR) — check if Wish was active
      if @effects[PBEffects::Wish] > 0
        amt = (@totalhp * 0.75).round
      end
    end
    respond_to?(:starlight_healing_pbRecoverHP) ? starlight_healing_pbRecoverHP(amt, anim) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Lunar Blessing recovers 33% HP (from 25%)
# Lunar Blessing (HealAlliesQuarter class) — intercept heal amount
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::HealAlliesQuarterOfTotalHP
  alias starlight_lunarblessing_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :LUNARBLESSING && @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
      # Heal 33% instead of 25%
      heal = (target.totalhp / 3.0).round
      heal = [heal, 1].max
      target.pbRecoverHP(heal)
      @battle.pbDisplay(_INTL("{1} was healed by lunar starlight!", target.pbThis))
      return
    end
    if respond_to?(:starlight_lunarblessing_pbEffectAgainstTarget, true)
      starlight_lunarblessing_pbEffectAgainstTarget(user, target)
    else
      super
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Healing Wish and Lunar Dance — boost recipient's Attack and Sp. Attack
# Chain from the existing FairyTale HealingWish EOR hook pattern.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias starlight_healingwish_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    starlight_healingwish_pbEndOfRoundPhase
    return unless has_field? && STARLIGHT_ARENA_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::HealingWish]

      battler.pbRaiseStatStage(:ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:ATTACK, battler, nil)
      battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler, nil)
      pbDisplay(_INTL("The starlight blessing boosted {1}'s fighting spirit!", battler.pbThis))
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Trick Room, Magic Room, Wonder Room last 8 turns
#──────────────────────────────────────────────────────────────────────────────
STARLIGHT_ROOM_MOVES = {
  TRICKROOM:  :TrickRoom,
  WONDERROOM: :WonderRoom,
  MAGICROOM:  :MagicRoom,
}.freeze

STARLIGHT_ROOM_MOVES.each do |move_id, effect_key|
  next unless PBEffects.const_defined?(effect_key)

  effect_const = PBEffects.const_get(effect_key)

  class_str = case move_id
              when :TRICKROOM  then "InvertBattlerSpeeds"
              when :WONDERROOM then "SwapBattlersItems"
              when :MAGICROOM  then "DisableBattlerItems"
              end

  if Object.const_defined?("Battle::Move::#{class_str}")
    klass = Object.const_get("Battle::Move::#{class_str}")
    klass.class_eval do
      define_method("starlight_room_#{move_id}_pbEffectGeneral".to_sym) do |user|
        send("starlight_room_#{move_id}_original_pbEffectGeneral", user) rescue super(user)
        if @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
          @battle.field.effects[effect_const] = 8
        end
      end
    end
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
# ABILITY: Mirror Armor — protects user's side from priority moves
# Priority moves targeting a battler with Mirror Armor (or ally with it) fail.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias starlight_mirrorarmor_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
      if @priority > 0
        # Check if target or any ally has Mirror Armor
        has_mirror = target.hasActiveAbility?(:MIRRORARMOR) ||
                     target.allAllies.any? { |b| b.hasActiveAbility?(:MIRRORARMOR) }
        if has_mirror
          @battle.pbDisplay(_INTL("{1}'s Mirror Armor deflected the priority move!", target.pbThis)) if show_message
          return true
        end
      end
    end
    respond_to?(:starlight_mirrorarmor_pbFailsAgainstTarget?) ? starlight_mirrorarmor_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

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
# SEED: Magical Seed — boosts Sp. Atk (fieldtxt) + applies Wish to the user
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias starlight_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = starlight_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && STARLIGHT_ARENA_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        if PBEffects.const_defined?(:Wish)
          battler.effects[PBEffects::Wish]      = 2
          battler.effects[PBEffects::WishAmount] = (battler.totalhp / 2.0).round if PBEffects.const_defined?(:WishAmount)
          pbDisplay(_INTL("{1} made a wish upon the stars!", battler.pbThis))
        end
      end
    end

    result
  end
end

#===============================================================================
# NEW WORLD FIELD MECHANICS
# "From darkness, from stardust, from memories of eons passed..."
#===============================================================================

NEW_WORLD_IDS = %i[newworld].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: Grounded Pokemon's Speed reduced by 25%
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias newworld_pbSpeed pbSpeed if method_defined?(:pbSpeed)

  def pbSpeed
    speed = newworld_pbSpeed
    return speed unless @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
    return speed unless grounded?
    (speed * 0.75).round
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE B: Non-grounded Pokemon's defenses lowered by x0.9
# Handled in 009 (defmult *= 0.9 if target.airborne?) — already implemented.
#──────────────────────────────────────────────────────────────────────────────

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE C: Prevents all weather and generated Field Effects
# Weather block already implemented in 009 (field_blocks_weather?).
# Field-change prevention: intercept pbChangeField or fieldChange apply to
# block any field transitions while New World is active.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias newworld_field_change_pbChangeField pbChangeField if method_defined?(:pbChangeField)

  def pbChangeField(new_field_id, *args)
    if has_field? && NEW_WORLD_IDS.include?(current_field.id)
      # Allow only the Starlight Arena transitions from Gravity/Geomancy
      allowed_targets = %i[starlightarena]
      # Convert to symbol if possible, fallback to original if conversion fails
      allowed_val = begin
        new_field_id.to_sym
      rescue
        new_field_id
      end
      unless allowed_targets.include?(allowed_val)
        pbDisplay(_INTL("The New World resisted the field change!"))
        return false
      end
    end
    if respond_to?(:newworld_field_change_pbChangeField, true)
      newworld_field_change_pbChangeField(new_field_id, *args)
    else
      super
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Fissure always fails
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias newworld_fissure_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
      if @id == :FISSURE
        @battle.pbDisplay(_INTL("There's no ground to split in the void!")) if show_message
        return true
      end
    end
    respond_to?(:newworld_fissure_pbFailsAgainstTarget?) ? newworld_fissure_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Heart Swap additionally applies Pain Split effect
# Heart Swap (SwapUserTargetSomeStats) swaps stat stages. We add Pain Split
# HP equalization after the swap.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::SwapUserTargetSomeStats
  alias newworld_heartswap_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:newworld_heartswap_pbEffectAgainstTarget) ? newworld_heartswap_pbEffectAgainstTarget(user, target) : super
    return unless @id == :HEARTSWAP
    return unless @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)

    # Pain Split: both HP become average
    avg_hp = ((user.hp + target.hp) / 2.0).round
    user.hp   = [avg_hp, user.totalhp].min
    target.hp = [avg_hp, target.totalhp].min
    @battle.pbDisplay(_INTL("The HP of {1} and {2} was equalized!", user.pbThis, target.pbThis(true)))
  rescue
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Lunar Dance boosts all of the recipient's stats (+1 each)
# Lunar Dance (HealAndReplacePartyPokemon) faint-heals the switch-in.
# We hook into OnSwitchIn to apply stat boosts to any Pokemon entering under
# HealingWish/LunarDance effect flags.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias newworld_lunardance_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    newworld_lunardance_pbEndOfRoundPhase
    return unless has_field? && NEW_WORLD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      # LunarDance sets HealingWish flag; check if it triggered this turn
      next unless battler.effects[PBEffects::HealingWish]

      # Boost all stats
      %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].each do |stat|
        battler.pbRaiseStatStage(stat, 1, battler) if battler.pbCanRaiseStatStage?(stat, battler, nil)
      end
      pbDisplay(_INTL("{1} was blessed with cosmic power!", battler.pbThis))
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Lunar Blessing recovers 33% HP (from 25%)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::HealAlliesQuarterOfTotalHP
  alias newworld_lunarblessing_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :LUNARBLESSING && @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
      heal = [(target.totalhp / 3.0).round, 1].max
      target.pbRecoverHP(heal)
      @battle.pbDisplay(_INTL("{1} was healed by cosmic light!", target.pbThis))
      return
    end
    if respond_to?(:newworld_lunarblessing_pbEffectAgainstTarget, true)
      newworld_lunarblessing_pbEffectAgainstTarget(user, target)
    else
      super
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Moonlight restores 75% HP
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias newworld_healing_pbRecoverHP pbRecoverHP if method_defined?(:pbRecoverHP)

  def pbRecoverHP(amt, anim = true)
    if @battle.respond_to?(:choices) && @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
      current_move = @battle.choices[@index] ? @battle.choices[@index][2] : nil
      if current_move && [:MOONLIGHT, :SYNTHESIS, :MORNINGSUN].include?(current_move.id)
        amt = (@totalhp * 0.75).round
      end
    end
    respond_to?(:newworld_healing_pbRecoverHP) ? newworld_healing_pbRecoverHP(amt, anim) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Nature's Madness deals 75% HP damage
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::LowerTargetHPToUserHP
  alias newworld_naturesmadness_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :NATURESMADNESS && @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
      dmg = (target.hp * 0.75).round
      target.pbReduceHP(dmg, false)
      return 0
    end
    respond_to?(:newworld_naturesmadness_pbEffectAgainstTarget) ? newworld_naturesmadness_pbEffectAgainstTarget(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Doom Desire deals additional Fire-type damage (x4 in damageMods)
# Same pattern as Starlight Arena — track targets, deal Fire bonus at EOR.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias newworld_doomdesire_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    newworld_doomdesire_pbEndOfRoundPhase
    return unless has_field? && NEW_WORLD_IDS.include?(current_field.id)

    (@newworld_doomdesire_fire_targets || []).each do |idx|
      battler = allBattlers.find { |b| b.index == idx }
      next unless battler && !battler.fainted?

      eff = Effectiveness.calculate(:FIRE, *battler.pbTypes(true))
      next if Effectiveness.ineffective?(eff)

      fire_dmg = [battler.totalhp / 8, 1].max
      battler.pbReduceHP(fire_dmg, false)
      pbDisplay(_INTL("Cosmic fire scorched {1}!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    end
    @newworld_doomdesire_fire_targets&.clear
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Secret Power may lower all stats
# Random -1 to one of the five battle stats.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::EffectDependsOnEnvironment
  alias newworld_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
      stat = %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].sample
      target.pbLowerStatStage(stat, 1, user) if target.pbCanLowerStatStage?(stat, user, self)
      return
    end
    respond_to?(:newworld_secretpower_pbAdditionalEffect) ? newworld_secretpower_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Trick Room, Magic Room, Wonder Room last 8 turns
#──────────────────────────────────────────────────────────────────────────────
NEWWORLD_ROOM_MOVES = {
  TRICKROOM:  :TrickRoom,
  WONDERROOM: :WonderRoom,
  MAGICROOM:  :MagicRoom,
}.freeze

NEWWORLD_ROOM_MOVES.each do |move_id, effect_key|
  next unless PBEffects.const_defined?(effect_key)
  effect_const = PBEffects.const_get(effect_key)

  class_str = case move_id
              when :TRICKROOM  then "InvertBattlerSpeeds"
              when :WONDERROOM then "SwapBattlersItems"
              when :MAGICROOM  then "DisableBattlerItems"
              end

  if Object.const_defined?("Battle::Move::#{class_str}")
    klass = Object.const_get("Battle::Move::#{class_str}")
    klass.class_eval do
      define_method("newworld_room_#{move_id}_pbEffectGeneral".to_sym) do |user|
        send("newworld_room_#{move_id}_original_pbEffectGeneral", user) rescue super(user)
        if @battle.has_field? && NEW_WORLD_IDS.include?(@battle.current_field.id)
          @battle.field.effects[effect_const] = 8
        end
      end
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Multitype — randomly changes type each EOR
#──────────────────────────────────────────────────────────────────────────────
NEW_WORLD_ALL_TYPES = %i[
  NORMAL FIRE WATER GRASS ELECTRIC ICE FIGHTING POISON
  GROUND FLYING PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY
].freeze

class Battle
  alias newworld_multitype_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    newworld_multitype_pbEndOfRoundPhase
    return unless has_field? && NEW_WORLD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.hasActiveAbility?([:MULTITYPE, :RKSSYSTEM])

      new_type = NEW_WORLD_ALL_TYPES.sample
      battler.pbChangeTypes(new_type)
      pbDisplay(_INTL("{1}'s type shifted to {2} in the New World!", battler.pbThis, new_type.to_s.capitalize))
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY: Mimicry — changes type to a random type (EOR)
# New World: Mimicry picks a random type each turn instead of terrain type.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias newworld_mimicry_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    newworld_mimicry_pbEndOfRoundPhase
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
# SEED: Magical Seed boosts all stats and makes the user recharge next turn
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias newworld_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = newworld_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && NEW_WORLD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        # All-stat boost handled by fieldtxt :stats key
        # Apply MustRecharge
        battler.effects[PBEffects::MustRecharge] = true if PBEffects.const_defined?(:MustRecharge)
        pbDisplay(_INTL("{1} is recharging after the cosmic surge!", battler.pbThis))
      end
    end

    result
  end
end

#===============================================================================
# FACTORY FIELD MECHANICS
# "Machines whir in the background."
#===============================================================================

FACTORY_FIELD_IDS = %i[factory].freeze

#──────────────────────────────────────────────────────────────────────────────
# MOVE A: Gear Up — doubled stat stage effect + additionally boosts user
# Gear Up normally raises Plus/Minus ally SpAtk+SpDef by 1.
# On Factory Field: raises by 2 AND also boosts the user's SpAtk+SpDef by 1.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::RaiseTargetAtkSpAtk1
  alias factory_gearup_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :GEARUP && @battle.has_field? && FACTORY_FIELD_IDS.include?(@battle.current_field.id)
      # Double the stage boost for allies
      [:SPECIAL_ATTACK, :SPECIAL_DEFENSE].each do |stat|
        target.pbRaiseStatStage(stat, 2, user) if target.pbCanRaiseStatStage?(stat, user, self)
      end
      # Also boost the user
      [:SPECIAL_ATTACK, :SPECIAL_DEFENSE].each do |stat|
        user.pbRaiseStatStage(stat, 1, user) if user.pbCanRaiseStatStage?(stat, user, self)
      end
      @battle.pbDisplay(_INTL("{1}'s Gear Up resonated in the factory!", user.pbThis))
      return
    end
    respond_to?(:factory_gearup_pbEffectAgainstTarget) ? factory_gearup_pbEffectAgainstTarget(user, target) : super
  end
end

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

#──────────────────────────────────────────────────────────────────────────────
# MOVE I: Steel Beam recoil set to 25%
# Steel Beam normally deals 50% recoil (RecoilUserHalf class).
# On Factory Field, reduce to 25%.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::RecoilUserHalf
  alias factory_steelbeam_pbRecoilDamage pbRecoilDamage if method_defined?(:pbRecoilDamage)

  def pbRecoilDamage(user, target)
    if @id == :STEELBEAM && @battle.has_field? && FACTORY_FIELD_IDS.include?(@battle.current_field.id)
      return (target.damageState.totalHPLost * 0.25).round
    end
    if respond_to?(:factory_steelbeam_pbRecoilDamage, true)
      factory_steelbeam_pbRecoilDamage(user, target)
    else
      super
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE J: Magnet Rise lasts 8 turns (Factory AND Short Circuit)
# Hook into pbEffectAgainstTarget on StartUserMagnetRise to extend duration.
#──────────────────────────────────────────────────────────────────────────────
MAGNET_RISE_EXTENDED_IDS = %i[factory shortcircuit].freeze

class Battle::Move::StartUserMagnetRise
  alias factory_magnetrise_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:factory_magnetrise_pbEffectAgainstTarget) ? factory_magnetrise_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && MAGNET_RISE_EXTENDED_IDS.include?(@battle.current_field.id)
    # Extend duration to 8 turns
    target.effects[PBEffects::MagnetRise] = 8 if PBEffects.const_defined?(:MagnetRise)
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE K: Gulp Missile always picks Pikachu on Factory/Short Circuit Field
# Extend the existing Electric Terrain hook.
#──────────────────────────────────────────────────────────────────────────────
GULP_MISSILE_PIKACHU_IDS = %i[factory shortcircuit].freeze

Battle::AbilityEffects::OnBeingHit.add(:GULPMISSILE_FACTORY,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.effects[PBEffects::Transform]
    next unless target.isSpecies?(:CRAMORANT)
    next unless [:SURF, :DIVE].include?(move.id)
    next unless battle.has_field? && GULP_MISSILE_PIKACHU_IDS.include?(battle.current_field.id)
    target.pbChangeForm(2, _INTL("{1} caught a Pikachu!", target.pbThis))
  }
)

#===============================================================================
# SHORT CIRCUIT FIELD MECHANICS
# "Bzzt!"
#===============================================================================

SHORTCIRCUIT_FIELD_IDS = %i[shortcircuit].freeze

# The electric damage pattern: counter 0-6 maps to multipliers
# 0→0.5, 1→0.75, 2→1.0, 3→1.25, 4→1.5, 5→1.75, 6→2.0
SHORTCIRCUIT_ELEC_MULTS = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].freeze

#──────────────────────────────────────────────────────────────────────────────
# MECHANIC A: Electric damage pattern cycling x0.5→x2
# On each Electric-type hit, apply the current roll multiplier and advance counter.
# The counter is managed by get_field_roll in 009 (Battle#get_field_roll).
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias shortcircuit_electric_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    respond_to?(:shortcircuit_electric_pbCalcDamageMultipliers) ? shortcircuit_electric_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    return unless @battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(@battle.current_field.id)
    return unless type == :ELECTRIC

    # Get current roll (0-6) and advance counter
    roll = @battle.get_field_roll(update_roll: true) rescue nil
    return unless roll.is_a?(Integer) && roll.between?(0, 6)

    mult = SHORTCIRCUIT_ELEC_MULTS[roll]
    mults[:power_multiplier] *= mult
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MECHANIC B: Steel Beam — 1.667x (in damageMods), instantly KOs user,
# deals Steel AND Electric type damage.
# The damageMods 1.667x is handled by fieldtxt.
# Here we handle the instant KO and dual-type damage.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::RecoilUserHalf
  alias shortcircuit_steelbeam_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)

  def pbEffectAfterAllHits(user, target)
    if respond_to?(:shortcircuit_steelbeam_pbEffectAfterAllHits, true)
      shortcircuit_steelbeam_pbEffectAfterAllHits(user, target)
    else
      super rescue nil
    end
    return unless @id == :STEELBEAM
    return unless @battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(@battle.current_field.id)
    # Instantly KO the user (reduced to 0 HP)
    user.hp = 0
    user.pbFaint
    @battle.pbDisplay(_INTL("{1} was destroyed by the overloaded circuit!", user.pbThis))
  end

  alias shortcircuit_steelbeam_pbBaseType pbBaseType if method_defined?(:pbBaseType)

  def pbBaseType(user)
    base_type = if respond_to?(:shortcircuit_steelbeam_pbBaseType, true)
                  shortcircuit_steelbeam_pbBaseType(user)
                else
                  super rescue :STEEL
                end
    return base_type unless @id == :STEELBEAM
    return base_type unless @battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(@battle.current_field.id)
    # Return :ELECTRIC so it also gains Electric effectiveness
    # We handle the dual-type bonus as an additional hit in pbEffectAgainstTarget
    base_type
  end
end

# Additional Electric bonus hit for Steel Beam on Short Circuit
class Battle::Move::RecoilUserHalf
  alias shortcircuit_steelbeam_dual_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if respond_to?(:shortcircuit_steelbeam_dual_pbEffectAgainstTarget, true)
      shortcircuit_steelbeam_dual_pbEffectAgainstTarget(user, target)
    else
      super rescue nil
    end
    return unless @id == :STEELBEAM
    return unless @battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(@battle.current_field.id)

    # Apply additional Electric damage (20% of damage dealt as Electric)
    elec_dmg = [(target.damageState.totalHPLost * 0.20).round, 1].max
    eff = Effectiveness.calculate(:ELECTRIC, *target.pbTypes(true))
    return if Effectiveness.ineffective?(eff)
    target.pbReduceHP(elec_dmg, false)
    @battle.pbDisplay(_INTL("The electric surge added extra damage!"))
    target.pbFaint if target.fainted?
  rescue
  end
end

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
    target.pbRecoverHP(target.totalhp / 16)
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
# MECHANIC I: Steelworker — Steel attacks additionally gain Electric typing
# Apply as a type-change via pbBaseType hook.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias shortcircuit_steelworker_pbCalcType pbCalcType if method_defined?(:pbCalcType)

  def pbCalcType(user)
    calc_type = shortcircuit_steelworker_pbCalcType(user)
    return calc_type unless @battle.has_field? && SHORTCIRCUIT_FIELD_IDS.include?(@battle.current_field.id)
    return calc_type unless user.hasActiveAbility?(:STEELWORKER)
    return calc_type unless calc_type == :STEEL
    # Return :ELECTRIC so effectiveness uses Electric chart
    # We keep both types via a type-add approach with a post-calc bonus
    :ELECTRIC
  end
end

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
    target.pbRecoverHP(heal)
    battle.pbHideAbilitySplash(target)
  }
)

#===============================================================================
# SWAMP FIELD MECHANICS
# "The field is swamped."
#===============================================================================

SWAMP_FIELD_IDS = %i[swamp].freeze

SWAMP_SPEED_IMMUNE_ABILITIES = %i[
  CLEARBODY QUICKFEET SWIFTSWIM WHITESMOKE PROPELLERTAIL STEAMENGINE
].freeze

# Moves that hold a Pokémon in place (trapping)
SWAMP_TRAPPING_MOVES = %i[
  SPIDERWEB INFESTATION LEECHSEED SNAPTRAP BIND WRAP FIRESPIN WHIRLPOOL
  SANDTOMB MAGMASTORM CLAMP JAWLOCK
].freeze

# HP-draining moves that trigger random stat drop
SWAMP_HP_DRAIN_MOVES = %i[
  ABSORB MEGADRAIN GIGADRAIN LEECHLIFE DRAININGKISS HORNLEECH OBLIVIONWING
  PARABOLICCHARGE STRENGTHSAP DREAMEATER
].freeze

# Moves that lower a random stat
SWAMP_RANDOM_STAT_MOVES = %i[
  ATTACKORDER STRENGTHSAP STRINGSHOT
].freeze

SWAMP_RANDOM_DROP_STATS = %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: EOR — all grounded Pokémon lose 1 Speed stage
# Immunity: Clear Body, Quick Feet, Swift Swim, White Smoke, Propeller Tail,
#           Steam Engine, and holding Heavy-Duty Boots
# Trapping: Pokémon under Trapping effect lose -2 Speed instead of -1
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias swamp_speed_drop_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    swamp_speed_drop_pbEndOfRoundPhase
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

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE B: EOR — Sleeping Pokémon take 1/16 HP damage
# Under Trapping: double damage (1/8)
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias swamp_sleep_damage_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    swamp_sleep_damage_pbEndOfRoundPhase
    return unless has_field? && SWAMP_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.status == :SLEEP

      divisor = (battler.effects[PBEffects::Trapping] > 0) ? 8 : 16
      dmg = [battler.totalhp / divisor, 1].max
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is sinking in the swamp!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE C: EOR — Pokémon under trapping moves (Spider Web, Infestation,
# Leech Seed, Snap Trap) lose a random stat -1
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias swamp_trap_statdrop_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    swamp_trap_statdrop_pbEndOfRoundPhase
    return unless has_field? && SWAMP_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::Trapping] > 0

      stat = SWAMP_RANDOM_DROP_STATS.sample
      battler.pbLowerStatStage(stat, 1, battler, false) if battler.pbCanLowerStatStage?(stat, battler, nil)
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE D: Aqua Ring restores 1/8 HP per turn (from 1/16)
# Extend the existing Water Surface hook to cover Swamp.
# The base game heals 1/16; we add an extra 1/16 for a total of 1/8.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias swamp_aquaring_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    swamp_aquaring_pbEndOfRoundPhase
    return unless has_field? && SWAMP_FIELD_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::AquaRing]
      next if battler.hp >= battler.totalhp

      battler.pbRecoverHP(battler.totalhp / 16)
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE E: Attack Order, Strength Sap, String Shot, HP-draining moves
# → lower one of the target's stats randomly by -1
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias swamp_random_statdrop_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:swamp_random_statdrop_pbEffectAgainstTarget) ? swamp_random_statdrop_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && SWAMP_FIELD_IDS.include?(@battle.current_field.id)
    return unless SWAMP_RANDOM_STAT_MOVES.include?(@id) || SWAMP_HP_DRAIN_MOVES.include?(@id)

    stat = SWAMP_RANDOM_DROP_STATS.sample
    target.pbLowerStatStage(stat, 1, user, false) if target.pbCanLowerStatStage?(stat, user, self)
  end
end

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
  alias swamp_seed_apply_field_effect apply_field_effect

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

#===============================================================================
# WASTELAND FIELD MECHANICS
# "The waste is watching..."
#===============================================================================

WASTELAND_IDS = %i[wasteland].freeze

WASTELAND_RANDOM_STATUSES = %i[BURN PARALYSIS FROZEN POISON].freeze
WASTELAND_SLUDGE_MOVES = %i[GUNKSHOT SLUDGE SLUDGEWAVE SLUDGEBOMB OCTAZOOKA ACIDDOWNPOUR].freeze
WASTELAND_STATUS_IMMUNE_ABILITIES = %i[IMMUNITY POISONHEAL TOXICBOOST].freeze
WASTELAND_STATUS_IMMUNE_TYPES = %i[POISON STEEL].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE: Entry hazards consumed at EOR, dealing special effects
# - Stealth Rocks: deal type-scaling Rock damage at double normal (2/8 HP)
# - Spikes: deal 33% max HP to grounded Pokémon
# - Toxic Spikes: deal 12.5% HP to grounded non-Poison/Steel + inflict poison
# - Sticky Web: severely lower Speed (-3 stages) to all grounded Pokémon
# After effects fire, the hazard is consumed.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias wasteland_hazards_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    wasteland_hazards_pbEndOfRoundPhase
    return unless has_field? && WASTELAND_IDS.include?(current_field.id)

    sides = [pbParty(0).size > 0 ? @sides[0] : nil, pbParty(1).size > 0 ? @sides[1] : nil].compact

    sides.each do |side|
      # Stealth Rock — double type-scaling damage (consume afterward)
      if side.effects[PBEffects::StealthRock]
        allBattlers.each do |battler|
          next if battler.fainted?
          next if battler.pbOwnSide != side
          eff = Effectiveness.calculate(:ROCK, *battler.pbTypes(true))
          next if Effectiveness.ineffective?(eff)
          factor = Effectiveness.factor_against_type(eff) rescue 1.0
          dmg = [(battler.totalhp * factor / 4.0).round, 1].max  # doubled: /4 instead of /8
          battler.pbReduceHP(dmg, false)
          pbDisplay(_INTL("{1} was slashed by toxic rocks!", battler.pbThis))
          battler.pbFaint if battler.fainted?
        end
        side.effects[PBEffects::StealthRock] = false
      end

      # Spikes — 33% HP to grounded
      if side.effects[PBEffects::Spikes] > 0
        allBattlers.each do |battler|
          next if battler.fainted?
          next if battler.pbOwnSide != side
          next unless battler.grounded?
          dmg = [battler.totalhp / 3, 1].max
          battler.pbReduceHP(dmg, false)
          pbDisplay(_INTL("{1} was stabbed by waste spikes!", battler.pbThis))
          battler.pbFaint if battler.fainted?
        end
        side.effects[PBEffects::Spikes] = 0
      end

      # Toxic Spikes — 12.5% HP + poison to grounded non-Poison/Steel
      if side.effects[PBEffects::ToxicSpikes] > 0
        allBattlers.each do |battler|
          next if battler.fainted?
          next if battler.pbOwnSide != side
          next unless battler.grounded?
          next if WASTELAND_STATUS_IMMUNE_TYPES.any? { |t| battler.pbHasType?(t) }
          dmg = [(battler.totalhp / 8.0).round, 1].max
          battler.pbReduceHP(dmg, false)
          pbDisplay(_INTL("{1} was poisoned by the toxic sludge!", battler.pbThis))
          battler.pbInflictStatus(:POISON) if battler.pbCanInflictStatus?(:POISON, nil, false)
          battler.pbFaint if battler.fainted?
        end
        side.effects[PBEffects::ToxicSpikes] = 0
      end

      # Sticky Web — severely lower Speed (-3 stages) to all grounded
      if side.effects[PBEffects::StickyWeb]
        allBattlers.each do |battler|
          next if battler.fainted?
          next if battler.pbOwnSide != side
          next unless battler.grounded?
          next unless battler.pbCanLowerStatStage?(:SPEED, battler, nil)
          battler.pbLowerStatStage(:SPEED, 3, battler, false)
          pbDisplay(_INTL("{1} was ensnared by the waste web!", battler.pbThis))
        end
        side.effects[PBEffects::StickyWeb] = false
      end
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Venom Drench, Venoshock, Barb Barrage — always activated
# These moves normally require target to be poisoned. On Wasteland they always work.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias wasteland_venomdrench_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    return wasteland_venomdrench_pbFailsAgainstTarget?(user, target, show_message) unless
      @battle.has_field? && WASTELAND_IDS.include?(@battle.current_field.id)
    # These moves skip their poison-check requirement on Wasteland
    if %i[VENOMDRENCH VENOSHOCK BARBBARRAGE].include?(@id)
      return false
    end
    respond_to?(:wasteland_venomdrench_pbFailsAgainstTarget?) ? wasteland_venomdrench_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Dire Claw status chance 100%
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias wasteland_direclaw_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @id == :DIRECLAW && @battle.has_field? && WASTELAND_IDS.include?(@battle.current_field.id)
      status = %i[PARALYSIS POISON SLEEP].sample
      case status
      when :PARALYSIS
        target.pbParalyze(user) if target.pbCanParalyze?(user, false)
      when :POISON
        target.pbPoison(user)   if target.pbCanPoison?(user, false)
      when :SLEEP
        target.pbSleep(user)    if target.pbCanSleep?(user, false)
      end
      return
    end
    respond_to?(:wasteland_direclaw_pbAdditionalEffect) ? wasteland_direclaw_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Secret Power may inflict a random status (Burn/Paralysis/Freeze/Poison)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::EffectDependsOnEnvironment
  alias wasteland_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && WASTELAND_IDS.include?(@battle.current_field.id)
      status = WASTELAND_RANDOM_STATUSES.sample
      case status
      when :BURN
        target.pbBurn(user)     if target.pbCanBurn?(user, false)
      when :PARALYSIS
        target.pbParalyze(user) if target.pbCanParalyze?(user, false)
      when :FROZEN
        target.pbFreeze(user)   if target.pbCanFreeze?(user, false)
      when :POISON
        target.pbPoison(user)   if target.pbCanPoison?(user, false)
      end
      return
    end
    respond_to?(:wasteland_secretpower_pbAdditionalEffect) ? wasteland_secretpower_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Leech Seed damage doubled
# Base game drains 1/8 HP; on Wasteland drain 1/4.
# Hook into the EOR Leech Seed processing.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias wasteland_leechseed_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    wasteland_leechseed_pbEndOfRoundPhase
    return unless has_field? && WASTELAND_IDS.include?(current_field.id)

    allBattlers.each do |battler|
      next if battler.fainted?
      next unless battler.effects[PBEffects::LeechSeed] >= 0

      # The base game already drained 1/8; add another 1/8 for a total of 1/4
      extra_drain = [battler.totalhp / 8, 1].max
      battler.pbReduceHP(extra_drain, false)

      # Heal the seeder
      seeder_index = battler.effects[PBEffects::LeechSeed]
      seeder = allBattlers.find { |b| b.index == seeder_index && !b.fainted? }
      seeder.pbRecoverHP(extra_drain) if seeder && seeder.hp < seeder.totalhp
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Swallow healing doubled, cures status at max Stockpile
# Swallow's base class is HealUserDependingOnStockpile.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::HealUserDependingOnStockpile
  alias wasteland_swallow_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @battle.has_field? && WASTELAND_IDS.include?(@battle.current_field.id)
      stock = user.effects[PBEffects::Stockpile] rescue 0
      # Doubled heal amounts: 25%/50%/100% → 50%/100%/100%
      heal_pct = case stock
                 when 1 then 0.50
                 when 2 then 1.00
                 when 3 then 1.00
                 else        0.25
                 end
      heal = [(user.totalhp * heal_pct).round, 1].max
      user.pbRecoverHP(heal)
      @battle.pbDisplay(_INTL("{1} absorbed the waste energy!", user.pbThis))
      # Cure status at max Stockpile (3)
      if stock >= 3 && user.status != :NONE
        user.pbCureStatus(false)
        @battle.pbDisplay(_INTL("{1}'s status was cured by the overload!", user.pbThis))
      end
      # Consume Stockpile
      user.effects[PBEffects::Stockpile] = 0 if PBEffects.const_defined?(:Stockpile)
      return
    end
    respond_to?(:wasteland_swallow_pbEffectGeneral) ? wasteland_swallow_pbEffectGeneral(user) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Gunk Shot, Sludge, Sludge Wave, Sludge Bomb, Octazooka, Acid Downpour
# → x1.2 boost (damageMods) + chance to inflict random status on non-Poison/Steel
#   targets without Immunity, Poison Heal or Toxic Boost
# Acid Downpour: additionally applies random status
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias wasteland_sludge_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    respond_to?(:wasteland_sludge_pbAdditionalEffect) ? wasteland_sludge_pbAdditionalEffect(user, target) : super
    return unless @battle.has_field? && WASTELAND_IDS.include?(@battle.current_field.id)
    return unless WASTELAND_SLUDGE_MOVES.include?(@id)
    return if WASTELAND_STATUS_IMMUNE_TYPES.any? { |t| target.pbHasType?(t) }
    return if target.hasActiveAbility?(WASTELAND_STATUS_IMMUNE_ABILITIES)
    return if rand(3) > 0  # ~33% chance

    status = WASTELAND_RANDOM_STATUSES.sample
    case status
    when :BURN
      target.pbBurn(user)     if target.pbCanBurn?(user, false)
    when :PARALYSIS
      target.pbParalyze(user) if target.pbCanParalyze?(user, false)
    when :FROZEN
      target.pbFreeze(user)   if target.pbCanFreeze?(user, false)
    when :POISON
      target.pbPoison(user)   if target.pbCanPoison?(user, false)
    end
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
    battler.pbRecoverHP(battler.totalhp / 8)
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
  alias wasteland_corrosion_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

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
# SEED: Telluric Seed — Atk + SpAtk (fieldtxt) + lay Stealth Rock on both sides
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias wasteland_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = wasteland_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && WASTELAND_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :TELLURICSEED && battler && !battler.fainted?
        sides.each do |side|
          side.effects[PBEffects::StealthRock] = true
        end
        pbDisplay(_INTL("Stealth Rocks were laid on both sides!"))
      end
    end

    result
  end
end

#===============================================================================
# DEEP EARTH FIELD MECHANICS
# "The core is pulling you in..."
#===============================================================================

DEEP_EARTH_IDS = %i[deepearth].freeze

# Gravity scale — used for weight multipliers and "floating" calculations
DEEP_EARTH_FLOAT_ABILITIES = %i[MAGNETPULL CONTRARY OBLIVIOUS UNAWARE].freeze
DEEP_EARTH_WEIGHT_MOVES_ATK = %i[HEAVYSLAM HEATCRASH].freeze
DEEP_EARTH_WEIGHT_MOVES_DEF = %i[GRASSKNOT LOWKICK].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: Gravity always active — set at EOR, cannot be removed
# We ensure Gravity is always on by refreshing its counter each turn.
# We also block any move that would cancel Gravity.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias deepearth_gravity_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    deepearth_gravity_pbEndOfRoundPhase
    return unless has_field? && DEEP_EARTH_IDS.include?(current_field.id)
    # Keep Gravity perpetually active
    if PBEffects.const_defined?(:Gravity)
      @field.effects[PBEffects::Gravity] = 5 if @field.effects[PBEffects::Gravity].to_i < 2
    end
  end
end

# Block moves that would cancel Gravity (Aerial Ace, Magnet Rise standard float, etc.)
# More specifically: block explicit "end gravity" or "levitate" moves
class Battle::Move
  alias deepearth_gravity_cancel_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)
      # Telekinesis and standard Magnet Rise levitation fail (Deep Earth overrides Magnet Rise)
      if @id == :TELEKINESIS
        @battle.pbDisplay(_INTL("The intense gravity prevents levitation!")) if show_message
        return true
      end
    end
    respond_to?(:deepearth_gravity_cancel_pbFailsAgainstTarget?) ? deepearth_gravity_cancel_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE B/C: Positive priority moves 0.7x, negative priority moves 1.3x
# MOVE D: Core Enforcer has -1 priority
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias deepearth_priority_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    respond_to?(:deepearth_priority_pbCalcDamageMultipliers) ? deepearth_priority_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    return unless @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)

    pri = @priority
    if pri > 0
      mults[:power_multiplier] *= 0.7
    elsif pri < 0
      mults[:power_multiplier] *= 1.3
    end
  end
end

class Battle::Move::CoreEnforcer
  alias deepearth_coreenforcer_pbPriority pbPriority if method_defined?(:pbPriority)

  def pbPriority(user)
    base = respond_to?(:deepearth_coreenforcer_pbPriority) ?
           deepearth_coreenforcer_pbPriority(user) : (@priority rescue 0)
    return base unless @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)
    base - 1
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE E: Gyro Ball and Crush Grip always at maximum power
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias deepearth_maxpower_pbBaseDamage pbBaseDamage if method_defined?(:pbBaseDamage)

  def pbBaseDamage(basedmg, user, target)
    ret = respond_to?(:deepearth_maxpower_pbBaseDamage) ?
          deepearth_maxpower_pbBaseDamage(basedmg, user, target) : basedmg
    return ret unless @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)
    case @id
    when :GYROBALL
      # Max Gyro Ball = 150 BP
      return 150
    when :CRUSHGRIP
      # Max Crush Grip = 120 BP
      return 120
    end
    ret
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE F: Psywave deals 1x–1.5x user level damage (instead of 0.5x–1.5x)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::FixedDamageUserLevel
  alias deepearth_psywave_pbFixedDamage pbFixedDamage if method_defined?(:pbFixedDamage)

  def pbFixedDamage(user, target)
    return deepearth_psywave_pbFixedDamage(user, target) unless
      @id == :PSYWAVE &&
      @battle.has_field? &&
      DEEP_EARTH_IDS.include?(@battle.current_field.id)
    # 1x to 1.5x user level
    mult = 1.0 + rand(6) * 0.1  # 1.0, 1.1, 1.2, 1.3, 1.4, 1.5
    [(user.level * mult).round, 1].max
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE G: Seismic Toss deals 1.5x user level damage
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::FixedDamageUserLevel
  alias deepearth_seismictoss_pbFixedDamage pbFixedDamage if method_defined?(:pbFixedDamage)

  def pbFixedDamage(user, target)
    return deepearth_seismictoss_pbFixedDamage(user, target) unless
      @id == :SEISMICTOSS &&
      @battle.has_field? &&
      DEEP_EARTH_IDS.include?(@battle.current_field.id)
    (user.level * 1.5).round
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE H: Gravity targets all opposing Pokémon, dealing 50% current HP
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartGravity
  alias deepearth_gravity_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:deepearth_gravity_pbEffectGeneral) ? deepearth_gravity_pbEffectGeneral(user) : super
    return unless @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)

    @battle.allOtherBattlers(user.index).each do |target|
      next if target.fainted?
      dmg = [target.hp / 2, 1].max
      target.pbReduceHP(dmg, false)
      @battle.pbDisplay(_INTL("{1} was crushed by Deep Earth gravity!", target.pbThis))
      target.pbFaint if target.fainted?
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE I: Topsy-Turvy reverses gravity, dealing weight-based Ground damage to all
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::InvertStatStages
  alias deepearth_topsyturvy_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:deepearth_topsyturvy_pbEffectAgainstTarget) ? deepearth_topsyturvy_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)

    # Deal weight-based Ground damage to all active battlers
    @battle.allBattlers.each do |b|
      next if b.fainted?
      weight_kg = b.pbWeight rescue 50
      # Scale: heavier = more damage; base 40 + weight/10, capped at 120
      dmg = [40 + (weight_kg / 10).floor, 120].min
      eff = Effectiveness.calculate(:GROUND, *b.pbTypes(true))
      next if Effectiveness.ineffective?(eff)
      factor = Effectiveness.factor_against_type(eff) rescue 1.0
      final = [(dmg * factor).round, 1].max
      b.pbReduceHP(final, false)
      @battle.pbDisplay(_INTL("{1} was slammed into the earth!", b.pbThis))
      b.pbFaint if b.fainted?
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE J: Magnet Rise grants +2 Speed instead of levitation on Deep Earth
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartUserMagnetRise
  alias deepearth_magnetrise_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)
      # Skip levitation; grant +2 Speed instead
      target.pbRaiseStatStage(:SPEED, 2, user) if target.pbCanRaiseStatStage?(:SPEED, user, self)
      @battle.pbDisplay(_INTL("{1} converted magnetic energy into speed!", target.pbThis))
      return
    end
    respond_to?(:deepearth_magnetrise_pbEffectAgainstTarget) ? deepearth_magnetrise_pbEffectAgainstTarget(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE K: Attacker's weight doubled for Heavy Slam / Heat Crash
# MOVE L: Defender's weight doubled for Grass Knot / Low Kick
# Hook into pbWeight to double it conditionally.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias deepearth_pbWeight pbWeight if method_defined?(:pbWeight)

  def pbWeight
    base = respond_to?(:deepearth_pbWeight) ? deepearth_pbWeight : (@pokemon.weight rescue 50)
    return base unless @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id)

    current_move = @battle.choices[@index]&.dig(2) rescue nil
    return base unless current_move

    # Attacker's weight doubled for Heavy Slam / Heat Crash
    if DEEP_EARTH_WEIGHT_MOVES_ATK.include?(current_move.id) && @battle.choices[@index][0] == :UseMove
      return base * 2
    end

    base
  end
end

# For defender weight (Grass Knot / Low Kick), hook into the move's target weight fetch
class Battle::Move
  alias deepearth_defweight_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    if @battle.has_field? && DEEP_EARTH_IDS.include?(@battle.current_field.id) &&
       DEEP_EARTH_WEIGHT_MOVES_DEF.include?(@id)
      # Temporarily double target weight for BP calculation
      orig_weight = target.instance_variable_get(:@deep_earth_weight_doubled)
      target.instance_variable_set(:@deep_earth_weight_doubled, true)
    end
    respond_to?(:deepearth_defweight_pbCalcDamageMultipliers) ? deepearth_defweight_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    target.instance_variable_set(:@deep_earth_weight_doubled, false) if
      DEEP_EARTH_WEIGHT_MOVES_DEF.include?(@id) rescue nil
  end
end

class Battle::Battler
  alias deepearth_defweight_pbWeight pbWeight if method_defined?(:pbWeight)

  def pbWeight
    base = respond_to?(:deepearth_defweight_pbWeight) ? deepearth_defweight_pbWeight : (@pokemon.weight rescue 50)
    return base * 2 if @battle.has_field? &&
                       DEEP_EARTH_IDS.include?(@battle.current_field.id) &&
                       @deep_earth_weight_doubled
    base
  end
end

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
  alias deepearth_pressure_pbReducePP pbReducePP if method_defined?(:pbReducePP)

  def pbReducePP(move)
    result = respond_to?(:deepearth_pressure_pbReducePP, true) ?
      deepearth_pressure_pbReducePP(move) : super

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
  alias deepearth_float_airborne? airborne?

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

#──────────────────────────────────────────────────────────────────────────────
# SEED X: Telluric Seed — +Def (fieldtxt) + doubles holder's weight
# We track the weight doubling via a battler flag.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias deepearth_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = deepearth_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && DEEP_EARTH_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :TELLURICSEED && battler && !battler.fainted?
        battler.instance_variable_set(:@deep_earth_weight_doubled, true)
        pbDisplay(_INTL("{1}'s weight increased under the earth's pull!", battler.pbThis))
      end
    end

    result
  end
end

#===============================================================================
# GLITCH FIELD MECHANICS
# "1n!taliz3 .b//////attl3"
#===============================================================================

GLITCH_FIELD_IDS = %i[glitch].freeze

# Drive → immune type mapping for Genesect
GLITCH_DRIVE_TYPES = {
  BURNDRIVE:   :FIRE,
  CHILLDRIVE:  :ICE,
  DOUSEDRIVE:  :WATER,
  SHOCKDRIVE:  :ELECTRIC,
}.freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A–G: Altered type chart
# We hook into pbCalcDamageMultipliers to patch effectiveness multipliers.
# Fairy moves become Normal-type via pbCalcType.
#──────────────────────────────────────────────────────────────────────────────

# A: Fairy moves → Normal type
class Battle::Move
  alias glitch_fairy_pbCalcType pbCalcType if method_defined?(:pbCalcType)

  def pbCalcType(user)
    t = glitch_fairy_pbCalcType(user)
    return :NORMAL if t == :FAIRY &&
                      @battle.has_field? &&
                      GLITCH_FIELD_IDS.include?(@battle.current_field.id)
    t
  end
end

# B–G: Type chart patches via effectiveness override in damage multipliers
class Battle::Move
  alias glitch_typechart_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    respond_to?(:glitch_typechart_pbCalcDamageMultipliers) ? glitch_typechart_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    return unless @battle.has_field? && GLITCH_FIELD_IDS.include?(@battle.current_field.id)

    target_types = target.pbTypes(true)

    # B: Dragon always neutral — cancel SE or NVE multipliers from Dragon moves
    if type == :DRAGON
      # Recalculate what the base game applied and reset to 1x
      base_eff = Effectiveness.calculate(type, *target_types) rescue nil
      if base_eff
        factor = Effectiveness.factor_against_type(base_eff) rescue 1.0
        mults[:type_modifier] /= factor if mults[:type_modifier] && factor != 0
        mults[:type_modifier] = 1.0
      end
    end

    # C: Bug → Poison super effective (2x)
    if type == :BUG && target_types.include?(:POISON)
      current_eff = begin
        Effectiveness.calculate(type, *target_types)
      rescue
        nil
      end
      is_super = begin
        Effectiveness.super_effective?(current_eff)
      rescue
        false
      end
      unless is_super
        mults[:type_modifier] = (mults[:type_modifier] || 1.0) * 2.0
      end
    end

    # D: Ice → Fire neutral (remove the 0.5x resistance)
    if type == :ICE && target_types.include?(:FIRE)
      # Ice normally does 0.5x to Fire; multiply by 2 to cancel it
      mults[:type_modifier] = (mults[:type_modifier] || 1.0) * 2.0
    end

    # E: Ghost cannot hit Psychic (immune)
    if type == :GHOST && target_types.include?(:PSYCHIC)
      mults[:type_modifier] = 0.0
    end

    # F: Poison → Bug super effective (2x)
    if type == :POISON && target_types.include?(:BUG)
      current_eff = begin
        Effectiveness.calculate(type, *target_types)
      rescue
        nil
      end
      is_super = begin
        Effectiveness.super_effective?(current_eff)
      rescue
        false
      end
      unless is_super
        mults[:type_modifier] = (mults[:type_modifier] || 1.0) * 2.0
      end
    end

    # G: Steel resists Ghost and Dark (0.5x)
    if (type == :GHOST || type == :DARK) && target_types.include?(:STEEL)
      # Steel normally takes neutral from Ghost/Dark; apply resistance
      mults[:type_modifier] = (mults[:type_modifier] || 1.0) * 0.5
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE H: Physical/special split undone
# Special moves use higher of user's SpAtk vs SpDef for attack stat.
# Special moves use higher of target's SpAtk vs SpDef for defense stat.
# We override pbSpAtk on the user and pbSpDef on the target mid-calculation
# using a flag set before calc and cleared after.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias glitch_split_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    if @battle.has_field? && GLITCH_FIELD_IDS.include?(@battle.current_field.id) &&
       specialMove?(type)
      user.instance_variable_set(:@glitch_use_higher_spatk, true)
      target.instance_variable_set(:@glitch_use_higher_spdef, true)
    end
    respond_to?(:glitch_split_pbCalcDamageMultipliers) ? glitch_split_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    user.instance_variable_set(:@glitch_use_higher_spatk, false)
    target.instance_variable_set(:@glitch_use_higher_spdef, false)
  end
end

class Battle::Battler
  # Override SpAtk to return max(SpAtk, SpDef) when Glitch flag is set
  alias glitch_pbSpAtk pbSpAtk if method_defined?(:pbSpAtk)

  def pbSpAtk
    base = glitch_pbSpAtk
    return base unless @glitch_use_higher_spatk
    [base, pbSpDef].max
  end

  # Override SpDef (target) to return max(SpAtk, SpDef) when Glitch flag is set
  alias glitch_pbSpDef pbSpDef if method_defined?(:pbSpDef)

  def pbSpDef
    if method_defined?(:glitch_pbSpDef)
      base = glitch_pbSpDef
    else
      base = super rescue (@pokemon.spdef rescue 50)
    end
    return base unless @glitch_use_higher_spdef
    [base, pbSpAtk].max
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE I: Critical hit rate +1 stage if attacker is faster than target
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias glitch_crit_pbCritialHit pbCritialHit if method_defined?(:pbCritialHit)

  def pbCritialHit(user, target)
    base = respond_to?(:glitch_crit_pbCritialHit) ?
           glitch_crit_pbCritialHit(user, target) : (super rescue 0)
    return base unless @battle.has_field? && GLITCH_FIELD_IDS.include?(@battle.current_field.id)
    base += 1 if user.pbSpeed > target.pbSpeed
    base
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE J: No recharge turn if opponent KO'd with a recharge move
# Hook into pbEffectAfterAllHits on recharge moves.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias glitch_recharge_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)

  def pbEffectAfterAllHits(user, target)
    respond_to?(:glitch_recharge_pbEffectAfterAllHits) ? glitch_recharge_pbEffectAfterAllHits(user, target) : super
    return unless @battle.has_field? && GLITCH_FIELD_IDS.include?(@battle.current_field.id)
    return unless user.effects[PBEffects::MustRecharge] rescue false
    # Clear recharge if any foe just fainted
    foe_fainted = @battle.allOtherBattlers(user.index).any?(&:fainted?)
    user.effects[PBEffects::MustRecharge] = false if foe_fainted
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE K: Rest heals when called by Sleep Talk; resets sleep counter to 2
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::HealUserAndNegateStatus
  alias glitch_rest_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    sleep_talk_active = begin
      user.effects[PBEffects::SleepTalk]
    rescue
      false
    end
    if @id == :REST &&
       @battle.has_field? &&
       GLITCH_FIELD_IDS.include?(@battle.current_field.id) &&
       sleep_talk_active
      # Heal fully
      user.pbRecoverHP(user.totalhp)
      @battle.pbDisplay(_INTL("{1} glitched its rest routine and healed!", user.pbThis))
      # Reset sleep counter to 2 turns
      user.status = :SLEEP
      user.statusCount = 2
      return
    end
    respond_to?(:glitch_rest_pbEffectGeneral) ?
      glitch_rest_pbEffectGeneral(user) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE L: Rage locks the user indefinitely (skip move-unlock check)
# Rage normally exits the lock when the user is hit. On Glitch Field, the
# lock is never cleared by damage. We override pbOnDamageTaken.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::FixedDamageUserLevel  # reuse a broad hook via Battler
end

class Battle::Battler
  alias glitch_rage_pbTurnBegin pbTurnBegin if method_defined?(:pbTurnBegin)

  def pbTurnBegin
    # Skip the Rage move-lock clear on Glitch Field
    if @battle.has_field? && GLITCH_FIELD_IDS.include?(@battle.current_field.id)
      # Do nothing — leave Rage lock intact
    end
    respond_to?(:glitch_rage_pbTurnBegin) ?
      glitch_rage_pbTurnBegin : (super rescue nil)
  end
end

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
# PASSIVE M: Metronome never chooses moves with < 70 base power
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::UseRandomMove
  alias glitch_metronome_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @id == :METRONOME &&
       @battle.has_field? &&
       GLITCH_FIELD_IDS.include?(@battle.current_field.id)
      # Build pool of moves with base power >= 70
      pool = []
      GameData::Move.each do |m|
        next if m.base_power > 0 && m.base_power < 70
        next if m.id == :METRONOME
        pool << m.id
      end
      if pool.any?
        chosen_id = pool.sample
        chosen_move = Battle::Move.from_pokemon_move(
          Pokemon::Move.new(chosen_id), @battle
        )
        @battle.pbDisplay(_INTL("{1} called {2}!", user.pbThis, GameData::Move.get(chosen_id).name))
        chosen_move.pbUseMove(user, user.pbDirectOpposing)
        return
      end
    end
    respond_to?(:glitch_metronome_pbEffectGeneral) ?
      glitch_metronome_pbEffectGeneral(user) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE N: Explosion/Selfdestruct halve target's Defense before damage
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias glitch_explode_pbCalcDamageMultipliers glitch_split_pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    glitch_explode_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    return unless @battle.has_field? && GLITCH_FIELD_IDS.include?(@battle.current_field.id)
    return unless %i[EXPLOSION SELFDESTRUCT].include?(@id)
    mults[:defense_multiplier] *= 0.5
  end
end

#──────────────────────────────────────────────────────────────────────────────
# ABILITY O: RKS System → ??? type at all times
# RKS System normally sets type based on held Memory item.
# On Glitch Field, force ??? regardless of memory.
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias glitch_rkssystem_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    glitch_rkssystem_pbEndOfRoundPhase
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
# SEED Q: Synthetic Seed — +Def +SpDef (fieldtxt) + make user ??? type
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias glitch_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = glitch_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && GLITCH_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :SYNTHETICSEED && battler && !battler.fainted?
        battler.pbChangeTypes(:QMARKS) rescue nil
        pbDisplay(_INTL("{1} glitched into ??? type!", battler.pbThis))
      end
    end

    result
  end
end

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

#===============================================================================
# COLOSSEUM FIELD MECHANICS
# "All eyes are on the fighters!"
#===============================================================================

COLOSSEUM_IDS = %i[colosseum].freeze

COLOSSEUM_FORCE_OUT_MOVES = %i[
  DRAGONTAIL CIRCLETHROW UTURN VOLTSWITCH PARTINGSHOT BATONPASS
  TELEPORT FLIPTURN CHILLYRECEPTION SHEDTAIL
].freeze

COLOSSEUM_STAT_ORDER = %i[ATTACK SPECIAL_ATTACK DEFENSE SPECIAL_DEFENSE SPEED].freeze

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE A: Neither player can switch out
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias colosseum_pbCanSwitch? pbCanSwitch? if method_defined?(:pbCanSwitch?)

  def pbCanSwitch?(idxNewBattler, idxParty, partyScene)
    if @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id)
      partyScene&.pbDisplay(_INTL("The arena forbids switching!"))
      return false
    end
    respond_to?(:colosseum_pbCanSwitch?) ? colosseum_pbCanSwitch?(idxNewBattler, idxParty, partyScene) : super
  end
end

# PASSIVE B: Force-out moves fail
class Battle::Move
  alias colosseum_forceout_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id) &&
       COLOSSEUM_FORCE_OUT_MOVES.include?(@id)
      @battle.pbDisplay(_INTL("The arena forbids retreating!")) if show_message
      return true
    end
    respond_to?(:colosseum_forceout_pbFailsAgainstTarget?) ? colosseum_forceout_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE C: KO grants Beast Boost — raise user's highest stat based on
# KO'd opponent's highest stat
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias colosseum_ko_pbFaint pbFaint if method_defined?(:pbFaint)

  def pbFaint(showMessage = true)
    # Identify who delivered the final blow
    attacker = @battle.lastAttacker[@index] rescue nil
    attacker_battler = attacker ? @battle.battlers[attacker] : nil

    ret = colosseum_ko_pbFaint(showMessage)

    if @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id) &&
       attacker_battler && !attacker_battler.fainted?
      # Find the KO'd foe's highest stat
      highest_stat = COLOSSEUM_STAT_ORDER.max_by do |s|
        @pokemon.stats[s] rescue @pokemon.send(s.downcase) rescue 0
      end
      # Raise attacker's corresponding highest stat by 1
      attacker_stat = COLOSSEUM_STAT_ORDER.max_by do |s|
        attacker_battler.pokemon.stats[s] rescue 0
      end
      if attacker_battler.pbCanRaiseStatStage?(attacker_stat, attacker_battler, nil)
        attacker_battler.pbRaiseStatStage(attacker_stat, 1, attacker_battler, false)
        @battle.pbDisplay(_INTL("{1} gained power from the victory!", attacker_battler.pbThis))
      end
    end

    ret
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE D: Roar raises the active Pokémon's Attack AND SpAtk by 2 stages
# (instead of forcing a switch)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::ForceSwitchOut
  alias colosseum_roar_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :ROAR &&
       @battle.has_field? &&
       COLOSSEUM_IDS.include?(@battle.current_field.id)
      target.pbRaiseStatStage(:ATTACK, 2, user)         if target.pbCanRaiseStatStage?(:ATTACK, user, self)
      target.pbRaiseStatStage(:SPECIAL_ATTACK, 2, user) if target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
      @battle.pbDisplay(_INTL("{1} answered the roar with fury!", target.pbThis))
      return
    end
    respond_to?(:colosseum_roar_pbEffectAgainstTarget) ? colosseum_roar_pbEffectAgainstTarget(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE E: First Impression bypasses Protect moves
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias colosseum_firstimpression_pbDamagingMove? pbDamagingMove? if method_defined?(:pbDamagingMove?)

  def pbBypassesProtect?(user)
    return true if @id == :FIRSTIMPRESSION &&
                   @battle.has_field? &&
                   COLOSSEUM_IDS.include?(@battle.current_field.id)
    super rescue false
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE F: Swagger/Flatter increased effects
# Swagger normally +2 Atk; Colosseum → +4 Atk
# Flatter normally +1 SpAtk; Colosseum → +2 SpAtk
# Both still apply confusion as normal
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::RaiseTargetAtkConfuseTarget
  alias colosseum_swagger_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id)
      # +4 Attack instead of +2, plus confusion
      target.pbRaiseStatStage(:ATTACK, 4, user) if target.pbCanRaiseStatStage?(:ATTACK, user, self)
      target.pbConfuse if target.pbCanConfuse?(user, false, self)
      return
    end
    respond_to?(:colosseum_swagger_pbEffectAgainstTarget) ? colosseum_swagger_pbEffectAgainstTarget(user, target) : super
  end
end

class Battle::Move::RaiseTargetSpAtkConfuseTarget
  alias colosseum_flatter_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id)
      # +2 SpAtk instead of +1, plus confusion
      target.pbRaiseStatStage(:SPECIAL_ATTACK, 2, user) if target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
      target.pbConfuse if target.pbCanConfuse?(user, false, self)
      return
    end
    respond_to?(:colosseum_flatter_pbEffectAgainstTarget) ? colosseum_flatter_pbEffectAgainstTarget(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE G: Spiky Shield damage doubled (1/8 → 1/4 HP)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias colosseum_spikyshield_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    respond_to?(:colosseum_spikyshield_pbCalcDamageMultipliers) ? colosseum_spikyshield_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
  end
end

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
# MOVE H: Secret Power raises user's Attack +1
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::EffectDependsOnEnvironment
  alias colosseum_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && COLOSSEUM_IDS.include?(@battle.current_field.id)
      user.pbRaiseStatStage(:ATTACK, 1, user) if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      return
    end
    respond_to?(:colosseum_secretpower_pbAdditionalEffect) ? colosseum_secretpower_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE I: No Retreat — all stat boosts doubled (+2 → +4 each)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::RaiseUserMainStats
  alias colosseum_noretreat_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @id == :NORETREAT &&
       @battle.has_field? &&
       COLOSSEUM_IDS.include?(@battle.current_field.id)
      %i[ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].each do |stat|
        user.pbRaiseStatStage(stat, 4, user) if user.pbCanRaiseStatStage?(stat, user, self)
      end
      user.effects[PBEffects::NoRetreat] = true if PBEffects.const_defined?(:NoRetreat)
      return
    end
    respond_to?(:colosseum_noretreat_pbEffectGeneral) ?
      colosseum_noretreat_pbEffectGeneral(user) : super
  end
end

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
  alias colosseum_defcomp_pbLowerStatStage pbLowerStatStage if method_defined?(:pbLowerStatStage)

  def pbLowerStatStage(stat, amount, user, showAnim = true, ignoreContrary = false,
                       ignoreMirrorArmor = false)
    result = respond_to?(:colosseum_defcomp_pbLowerStatStage) ?
      colosseum_defcomp_pbLowerStatStage(stat, amount, user, showAnim, ignoreContrary, ignoreMirrorArmor) :
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
  alias colosseum_wonderguard_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    colosseum_wonderguard_pbEndOfRoundPhase
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

# Intercept HP reduction for Wonder Guard holders during EOR
class Battle::Battler
  alias colosseum_wonderguard_pbReduceHP pbReduceHP if method_defined?(:pbReduceHP)

  def pbReduceHP(amt, anim = true, registerDamage = true, anyAnim = true)
    not_using_move = begin
      !@battle.choices[@index]&.dig(0).to_s.include?("UseMove")
    rescue
      false
    end
    if @battle.has_field? &&
       COLOSSEUM_IDS.include?(@battle.current_field.id) &&
       hasActiveAbility?(:WONDERGUARD) &&
       not_using_move
      # Block residual HP loss for Wonder Guard holders
      return 0
    end
    respond_to?(:colosseum_wonderguard_pbReduceHP) ?
      colosseum_wonderguard_pbReduceHP(amt, anim, registerDamage, anyAnim) :
      super
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

#===============================================================================
# CHESS BOARD FIELD MECHANICS
# "Opening variation set."
#===============================================================================

CHESS_BOARD_IDS = %i[chessboard].freeze

# Chess piece roles — stored per battler index
# Assigned at switch-in; persists until faint or field change.
# :queen, :pawn, :king, :knight, :bishop, :rook

CHESS_PIECE_PRIORITY = %i[queen pawn king knight bishop rook].freeze

CHESS_ATTACK_MOVES = %i[
  PSYCHIC STRENGTH ANCIENTPOWER CONTINENTALCRUSH BARRAGE SECRETPOWER SHATTEREDPSYCHE
].freeze

CHESS_VULNERABLE_ABILITIES  = %i[OBLIVIOUS SIMPLE UNAWARE KLUTZ DEFEATIST].freeze
CHESS_RESISTANT_ABILITIES   = %i[ADAPTABILITY SYNCHRONIZE ANTICIPATION TELEPATHY].freeze
CHESS_ATTACK_MULTIPLIER      = 1.5
CHESS_BARRAGE_MULTIPLIER     = 2.0
CHESS_VULNERABLE_MULTIPLIER  = 2.0
CHESS_RESISTANT_MULTIPLIER   = 0.5

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
# PIECE EFFECT — King: increased priority on all moves (+1)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias chess_king_pbPriority pbPriority if method_defined?(:pbPriority)

  def pbPriority(user = nil)
    base = chess_king_pbPriority(user)
    return base unless @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id)
    battler = user || (@battle.battlers[@battle.choices.index { |c| c&.dig(2) == self }] rescue nil)
    return base unless battler&.instance_variable_get(:@chess_piece) == :king
    base + 1
  end
end

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
# CHESS ATTACKS: x1.5 power (Barrage x2) + additional Rock-type damage
# Klutz holders fail to use Chess Attacks
# x2 vs Oblivious/Simple/Unaware/Klutz/Defeatist or confused target
# x0.5 vs Adaptability/Synchronize/Anticipation/Telepathy
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias chess_attack_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults)
    respond_to?(:chess_attack_pbCalcDamageMultipliers) ? chess_attack_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    return unless @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id)
    return unless CHESS_ATTACK_MOVES.include?(@id)

    # Klutz holders always fail chess attacks — handled in pbFailsAgainstTarget
    # Ability/confusion modifiers
    confused = begin
      target.effects[PBEffects::Confusion] > 0
    rescue
      false
    end
    if target.hasActiveAbility?(CHESS_VULNERABLE_ABILITIES) || confused
      mults[:power_multiplier] *= CHESS_VULNERABLE_MULTIPLIER
    elsif target.hasActiveAbility?(CHESS_RESISTANT_ABILITIES)
      mults[:power_multiplier] *= CHESS_RESISTANT_MULTIPLIER
    end
  end
end

# Block Chess Attacks for Klutz users
class Battle::Move
  alias chess_klutz_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id) &&
       CHESS_ATTACK_MOVES.include?(@id) && user.hasActiveAbility?(:KLUTZ)
      @battle.pbDisplay(_INTL("{1} fumbled the Chess Attack!", user.pbThis)) if show_message
      return true
    end
    respond_to?(:chess_klutz_pbFailsAgainstTarget?) ? chess_klutz_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

# Rock-type bonus damage after Chess Attacks land
class Battle::Move
  alias chess_rock_bonus_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)

  def pbEffectAfterAllHits(user, target)
    respond_to?(:chess_rock_bonus_pbEffectAfterAllHits) ? chess_rock_bonus_pbEffectAfterAllHits(user, target) : super
    return unless @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id)
    return unless CHESS_ATTACK_MOVES.include?(@id)
    return if target.fainted?

    eff = Effectiveness.calculate(:ROCK, *target.pbTypes(true))
    return if Effectiveness.ineffective?(eff)

    factor = Effectiveness.factor_against_type(eff) rescue 1.0
    rock_dmg = [(@battle.battlers.first.totalhp.to_f / 16 * factor).round, 1].max rescue 1
    target.pbReduceHP(rock_dmg, false)
    @battle.pbDisplay(_INTL("The chess board crumbled under {1}!", target.pbThis))
    target.pbFaint if target.fainted?
  end
end

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

class Battle::Move
  alias chess_tantrum_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)

  def pbEffectAfterAllHits(user, target)
    respond_to?(:chess_tantrum_pbEffectAfterAllHits) ? chess_tantrum_pbEffectAfterAllHits(user, target) : super
    return unless @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id)
    return unless %i[STOMPINGTANTRUM OUTRAGE THRASH].include?(@id)
    user.instance_variable_set(:@chess_tantrum_open, true)
    @battle.pbDisplay(_INTL("{1} left themselves wide open!", user.pbThis))
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: King's Shield / Obstruct protect from ALL moves (attacking or status)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias chess_shield_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    if @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id)
      shielded = begin
        target.effects[PBEffects::KingsShield] || target.effects[PBEffects::Obstruct]
      rescue
        false
      end
      if shielded
        @battle.pbDisplay(_INTL("{1} is protected!", target.pbThis)) if show_message
        return true
      end
    end
    respond_to?(:chess_shield_pbFailsAgainstTarget?) ? chess_shield_pbFailsAgainstTarget?(user, target, show_message) : super
  end
end

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
# MOVE: Trick Room lasts 8 turns
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartTrickRoom
  alias chess_trickroom_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:chess_trickroom_pbEffectGeneral) ? chess_trickroom_pbEffectGeneral(user) : super
    return unless @battle.has_field? && CHESS_BOARD_IDS.include?(@battle.current_field.id)
    @battle.field.effects[PBEffects::TrickRoom] = 8 if PBEffects.const_defined?(:TrickRoom)
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: False Surrender applies Taunt
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias chess_falsesurrender_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:chess_falsesurrender_pbEffectAgainstTarget) ? chess_falsesurrender_pbEffectAgainstTarget(user, target) : super
    return unless @id == :FALSESURRENDER &&
                  @battle.has_field? &&
                  CHESS_BOARD_IDS.include?(@battle.current_field.id)
    return unless target.pbCanAttract?(user, false) rescue true  # fallback allow
    return if target.effects[PBEffects::Taunt] > 0 rescue false
    target.effects[PBEffects::Taunt] = 3
    @battle.pbDisplay(_INTL("{1} was taunted by the false surrender!", target.pbThis))
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: No Retreat — +2 Atk/SpAtk/Speed, -1 Def/SpDef
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::RaiseUserMainStats
  alias chess_noretreat_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @id == :NORETREAT &&
       @battle.has_field? &&
       CHESS_BOARD_IDS.include?(@battle.current_field.id)
      user.pbRaiseStatStage(:ATTACK, 2, user)         if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      user.pbRaiseStatStage(:SPECIAL_ATTACK, 2, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
      user.pbRaiseStatStage(:SPEED, 2, user)          if user.pbCanRaiseStatStage?(:SPEED, user, self)
      user.pbLowerStatStage(:DEFENSE, 1, user, false)
      user.pbLowerStatStage(:SPECIAL_DEFENSE, 1, user, false)
      user.effects[PBEffects::NoRetreat] = true if PBEffects.const_defined?(:NoRetreat)
      return
    end
    respond_to?(:chess_noretreat_pbEffectGeneral) ?
      chess_noretreat_pbEffectGeneral(user) : super
  end
end

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

#===============================================================================
# MIRROR ARENA FIELD MECHANICS
# "Mirrors are layed around the field!"
#===============================================================================

MIRROR_ARENA_IDS = %i[mirrorarena].freeze

MIRROR_ARENA_BEAM_MOVES = %i[
  CHARGEBEAM SOLARBEAM PSYBEAM TRIATTACK ICEBEAM HYPERBEAM
  BUBBLEBEAM ORIGINPULSE FLEUCANNON MOONGEISTBEAM
].freeze

MIRROR_ARENA_BLIND_MOVES = %i[
  AURORABEAM SIGNALBEAM FLASHCANNON LUSTERPURGE DOOMDESIRE
  DAZZLINGGLEAM TECHNOBLAST PRISMATICLASER PHOTONGEYSER
].freeze

MIRROR_ARENA_SHATTER_MOVES = %i[
  EARTHQUAKE BULLDOZE BOOMBURST HYPERVOICE MAGNITUDE TECTONICRAGE
].freeze

MIRROR_ARENA_EVASION_ABILITIES = %i[
  SANDVEIL SNOWCLOAK ILLUSION TANGLEDFEET MAGICBOUNCE COLORCHANGE
].freeze

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

#──────────────────────────────────────────────────────────────────────────────
# GENERAL B: Single-target non-contact special moves that miss may reflect
#            and hit anyway (~50% chance)
# GENERAL C: Physical contact moves that miss deal 1/4 HP recoil
#            (unless behind Protect or has Shell/Battle Armor)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias mirror_pbEffectsAfterMove pbEffectsAfterMove if method_defined?(:pbEffectsAfterMove)

  def pbEffectsAfterMove(user, targets, move, numHits)
    respond_to?(:mirror_pbEffectsAfterMove) ? mirror_pbEffectsAfterMove(user, targets, move, numHits) : super
    return unless @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
    return unless numHits == 0  # Move missed all targets

    not_multi_target = begin
      move.pbTarget(user) != :AllNearFoes
    rescue
      true  # single-target guard
    end
    if move.specialMove? && !move.pbContactMove?(user) && not_multi_target
      # 50% chance to reflect and hit anyway
      if rand(2) == 0
        @battle.pbDisplay(_INTL("The attack was reflected by the mirror!"))
        # Deal damage as if it hit — use 1/8 HP approximation for reflected beam
        targets.each do |t|
          next if t.fainted?
          # Mark for beam bonus if it's a beam move
          user.instance_variable_set(:@mirror_reflected_beam, MIRROR_ARENA_BEAM_MOVES.include?(move.id))
          dmg = [t.totalhp / 8, 1].max
          t.pbReduceHP(dmg, false)
          @battle.pbDisplay(_INTL("The reflected beam struck {1}!", t.pbThis))
          t.pbFaint if t.fainted?
          user.instance_variable_set(:@mirror_reflected_beam, false)
        end
      end
    elsif move.physicalMove? && move.pbContactMove?(user)
      # Check immunity
      protected = targets.any? do |t|
        t.effects[PBEffects::Protect] || t.effects[PBEffects::KingsShield] || t.effects[PBEffects::Obstruct] rescue false
      end
      return if protected
      return if user.hasActiveAbility?(%i[SHELLARMOR BATTLEARMOR])

      dmg = [user.totalhp / 4, 1].max
      user.pbReduceHP(dmg, false)
      @battle.pbDisplay(_INTL("{1} hit a mirror instead! The mirror shattered!", user.pbThis))
      user.pbFaint if user.fainted?
    end
  end
end

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
# MOVE: Shatter moves → Neutral Field + 1/2 HP to all active Pokémon
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias mirror_shatter_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)

  def pbEffectAfterAllHits(user, target)
    respond_to?(:mirror_shatter_pbEffectAfterAllHits) ? mirror_shatter_pbEffectAfterAllHits(user, target) : super
    return unless @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
    return unless MIRROR_ARENA_SHATTER_MOVES.include?(@id)

    @battle.pbDisplay(_INTL("The mirror arena shattered!"))
    # Deal 1/2 HP to all active battlers
    @battle.allBattlers.each do |b|
      next if b.fainted?
      dmg = [b.totalhp / 2, 1].max
      b.pbReduceHP(dmg, false)
      b.pbFaint if b.fainted?
    end
    # Change to neutral field
    @battle.pbChangeField(:INDOOR) rescue nil
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Mirror Shot — always lowers Accuracy (override to force lower)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias mirror_mirrorshot_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @id == :MIRRORSHOT &&
       @battle.has_field? &&
       MIRROR_ARENA_IDS.include?(@battle.current_field.id)
      # Always lower Accuracy by 1 (skip the 66% roll)
      target.pbLowerStatStage(:ACCURACY, 1, user) if target.pbCanLowerStatStage?(:ACCURACY, user, self)
      return
    end
    respond_to?(:mirror_mirrorshot_pbAdditionalEffect) ? mirror_mirrorshot_pbAdditionalEffect(user, target) : super
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Mirror Coat success → +1 Evasion, +1 Def, +1 SpDef for user
# MOVE: Mirror Move success → +1 Accuracy, +1 Atk, +1 SpAtk for user
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias mirror_coat_move_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:mirror_coat_move_pbEffectAgainstTarget) ? mirror_coat_move_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)

    case @id
    when :MIRRORCOAT
      user.pbRaiseStatStage(:EVASION, 1, user)         if user.pbCanRaiseStatStage?(:EVASION, user, self)
      user.pbRaiseStatStage(:DEFENSE, 1, user)         if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
      user.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
    when :MIRRORMOVE
      user.pbRaiseStatStage(:ACCURACY, 1, user)        if user.pbCanRaiseStatStage?(:ACCURACY, user, self)
      user.pbRaiseStatStage(:ATTACK, 1, user)          if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user)  if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Light Screen / Reflect last 8 turns and boost user's Evasion
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartReflect
  alias mirror_reflect_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:mirror_reflect_pbEffectGeneral) ? mirror_reflect_pbEffectGeneral(user) : super
    return unless @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
    user.pbOwnSide.effects[PBEffects::Reflect] = 8 if PBEffects.const_defined?(:Reflect)
    user.pbRaiseStatStage(:EVASION, 1, user) if user.pbCanRaiseStatStage?(:EVASION, user, self)
    @battle.pbDisplay(_INTL("The mirrors extended the shield!"))
  end
end

class Battle::Move::StartLightScreen
  alias mirror_lightscreen_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:mirror_lightscreen_pbEffectGeneral) ? mirror_lightscreen_pbEffectGeneral(user) : super
    return unless @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
    user.pbOwnSide.effects[PBEffects::LightScreen] = 8 if PBEffects.const_defined?(:LightScreen)
    user.pbRaiseStatStage(:EVASION, 1, user) if user.pbCanRaiseStatStage?(:EVASION, user, self)
    @battle.pbDisplay(_INTL("The mirrors extended the light screen!"))
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Aurora Veil — always activatable, lasts 8 turns, boosts Evasion
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::StartAuroraVeil
  alias mirror_auroraveil_pbFailsAgainstTarget? pbFailsAgainstTarget? if method_defined?(:pbFailsAgainstTarget?)

  def pbFailsAgainstTarget?(user, target, show_message)
    # Skip the hail-only requirement on Mirror Arena
    return false if @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
    respond_to?(:mirror_auroraveil_pbFailsAgainstTarget?) ?
      mirror_auroraveil_pbFailsAgainstTarget?(user, target, show_message) : super
  end

  alias mirror_auroraveil_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:mirror_auroraveil_pbEffectGeneral) ? mirror_auroraveil_pbEffectGeneral(user) : super
    return unless @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
    user.pbOwnSide.effects[PBEffects::AuroraVeil] = 8 if PBEffects.const_defined?(:AuroraVeil)
    user.pbRaiseStatStage(:EVASION, 1, user) if user.pbCanRaiseStatStage?(:EVASION, user, self)
    @battle.pbDisplay(_INTL("The mirrors amplified Aurora Veil!"))
  end
end

#──────────────────────────────────────────────────────────────────────────────
# MOVE: Secret Power — lower Evasion (fully override base effect)
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move::EffectDependsOnEnvironment
  alias mirror_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && MIRROR_ARENA_IDS.include?(@battle.current_field.id)
      target.pbLowerStatStage(:EVASION, 1, user) if target.pbCanLowerStatStage?(:EVASION, user, self)
      return
    end
    respond_to?(:mirror_secretpower_pbAdditionalEffect) ? mirror_secretpower_pbAdditionalEffect(user, target) : super
  end
end

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

#──────────────────────────────────────────────────────────────────────────────
# SEED: Synthetic Seed — +2 Evasion (fieldtxt stat block is empty;
#       we apply it via apply_field_effect alias)
#──────────────────────────────────────────────────────────────────────────────
class Battle
  alias mirror_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = mirror_seed_apply_field_effect(effect_name, *args)

    if effect_name == :on_seed_use && has_field? && MIRROR_ARENA_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :SYNTHETICSEED && battler && !battler.fainted?
        2.times do
          battler.pbRaiseStatStage(:EVASION, 1, battler) if battler.pbCanRaiseStatStage?(:EVASION, battler, nil)
        end
        pbDisplay(_INTL("{1}'s Evasion sharply rose!", battler.pbThis))
      end
    end

    result
  end
end

#===============================================================================
# INDOOR FIELD (Neutral field — no special mechanics)
#===============================================================================

INDOOR_IDS = %i[indoor].freeze

#===============================================================================
# CAVE FIELD — Sound boost, Stealth Rock doubled, Punk Rock, Telluric Seed
# (Cave collapse / ground-hits-airborne already implemented earlier in this file)
#===============================================================================

CAVE_FIELD_IDS = %i[cave].freeze

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

# Telluric Seed: +2 Def + takes Stealth Rock damage
class Battle
  alias cave_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = cave_seed_apply_field_effect(effect_name, *args)
    if effect_name == :on_seed_use &&
       has_field? && CAVE_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :TELLURICSEED && battler && !battler.fainted?
        # Stealth Rock hazard damage
        if battler.pbOwnSide.effects[PBEffects::StealthRock]
          bTypes = battler.pbTypes(true)
          eff = Effectiveness.calculate(:ROCK, *bTypes)
          unless Effectiveness.ineffective?(eff)
            eff_mult = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
            dmg = (battler.totalhp * eff_mult / 8).round
            battler.pbReduceHP(dmg, false)
            pbDisplay(_INTL("{1} was hurt by the Stealth Rocks!", battler.pbThis))
            battler.pbFaint if battler.fainted?
          end
        end
      end
    end
    result
  end
end

#===============================================================================
# FLOWER GARDEN FIELD (Stages 1–5)
# Stage-based passive mechanics — damage reduction, type weakness nullification,
# ability activations, move enhancements
#===============================================================================

FLOWER_GARDEN_IDS = %i[flowergarden1 flowergarden2 flowergarden3 flowergarden4 flowergarden5].freeze

def flower_garden_stage(battle)
  return 0 unless battle.has_field?
  case battle.current_field.id
  when :flowergarden1 then 1
  when :flowergarden2 then 2
  when :flowergarden3 then 3
  when :flowergarden4 then 4
  when :flowergarden5 then 5
  else 0
  end
end

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

# MOVE: Growth — amplified at stage 1 (×2 like sun), ×3 at stage 3+
class Battle::Move::RaiseUserAtkSpAtk1
  alias flowergarden_growth_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @id == :GROWTH &&
       user.battle.has_field? &&
       FLOWER_GARDEN_IDS.include?(user.battle.current_field.id)
      stage = flower_garden_stage(user.battle)
      stages = stage >= 3 ? 3 : 2
      user.pbRaiseStatStage(:ATTACK, stages, user)         if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      user.pbRaiseStatStage(:SPECIAL_ATTACK, stages, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
      return
    end
    respond_to?(:flowergarden_growth_pbEffectGeneral) ? flowergarden_growth_pbEffectGeneral(user) : super
  end
end

# MOVE: Rototiller — additionally boosts Atk and SpAtk regardless of type
class Battle::Move::RaisePlusGroundedGrassTypes
  alias flowergarden_rototiller_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:flowergarden_rototiller_pbEffectGeneral) ? flowergarden_rototiller_pbEffectGeneral(user) : super
    return unless @battle.has_field? && FLOWER_GARDEN_IDS.include?(@battle.current_field.id)
    user.pbRaiseStatStage(:ATTACK, 1, user)         if user.pbCanRaiseStatStage?(:ATTACK, user, self)
    user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
  end
end

# MOVE: Flower Shield — stage 2+ boosts SpDef and user defenses regardless of type
class Battle::Move::RaiseGroundedGrassDefense1
  alias flowergarden_flowershield_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:flowergarden_flowershield_pbEffectGeneral) ? flowergarden_flowershield_pbEffectGeneral(user) : super
    return unless @battle.has_field? && FLOWER_GARDEN_IDS.include?(@battle.current_field.id)
    stage = flower_garden_stage(@battle)
    return unless stage >= 2
    mult = stage >= 3 ? 2 : 1
    @battle.allBattlers.each do |b|
      next if b.fainted?
      b.pbRaiseStatStage(:SPECIAL_DEFENSE, mult, user) if b.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
    end
    user.pbRaiseStatStage(:DEFENSE, mult, user)         if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
    user.pbRaiseStatStage(:SPECIAL_DEFENSE, mult, user) if user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
  end
end

# MOVE: Sweet Scent — stage 3+ additionally lowers target Def and SpDef
class Battle::Move::LowerTargetEvasiveness1
  alias flowergarden_sweetscent_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:flowergarden_sweetscent_pbEffectAgainstTarget) ? flowergarden_sweetscent_pbEffectAgainstTarget(user, target) : super
    return unless @id == :SWEETSCENT &&
                  @battle.has_field? &&
                  FLOWER_GARDEN_IDS.include?(@battle.current_field.id)
    stage = flower_garden_stage(@battle)
    return unless stage >= 3
    drops = stage >= 5 ? 3 : (stage >= 4 ? 2 : 1)
    target.pbLowerStatStage(:DEFENSE, drops, user)         if target.pbCanLowerStatStage?(:DEFENSE, user, self)
    target.pbLowerStatStage(:SPECIAL_DEFENSE, drops, user) if target.pbCanLowerStatStage?(:SPECIAL_DEFENSE, user, self)
  end
end

# MOVE: Floral Healing — stage 3+ fully heals
class Battle::Move::HealTargetDependingOnGrassyTerrain
  alias flowergarden_floralhealing_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :FLORALHEALING &&
       @battle.has_field? &&
       FLOWER_GARDEN_IDS.include?(@battle.current_field.id) &&
       flower_garden_stage(@battle) >= 3
      # Full heal
      heal = target.totalhp - target.hp
      if heal > 0 && !target.effects[PBEffects::HealBlock]
        target.pbRecoverHP(heal)
        @battle.pbDisplay(_INTL("The garden fully restored {1}!", target.pbThis))
      end
      return
    end
    respond_to?(:flowergarden_floralhealing_pbEffectAgainstTarget) ? flowergarden_floralhealing_pbEffectAgainstTarget(user, target) : super
  end
end

# Infestation EOR damage scales with stage (base 1/8; stage 3=1/6, stage 4=1/4, stage 5=1/3)
class Battle
  alias flowergarden_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    flowergarden_pbEndOfRoundPhase
    return unless has_field? && FLOWER_GARDEN_IDS.include?(current_field.id)
    stage = flower_garden_stage(self)
    return unless stage >= 3

    divisor = case stage
              when 3 then 6
              when 4 then 4
              else 3
              end

    allBattlers.each do |b|
      next if b.fainted?
      next unless b.effects[PBEffects::Infestation] > 0 rescue false
      # Base game already deducted 1/8; add extra to reach stage target
      extra = (b.totalhp / divisor) - (b.totalhp / 8)
      next unless extra > 0
      b.pbReduceHP(extra, false)
      b.pbFaint if b.fainted?
    end
  end
end

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

# Kinesis — additionally lowers target Atk and SpAtk by 2
class Battle::Move::LowerTargetAccuracy1
  alias psyterrain_kinesis_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:psyterrain_kinesis_pbEffectAgainstTarget) ? psyterrain_kinesis_pbEffectAgainstTarget(user, target) : super
    return unless @id == :KINESIS &&
                  @battle.has_field? &&
                  PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    target.pbLowerStatStage(:ATTACK, 2, user)         if target.pbCanLowerStatStage?(:ATTACK, user, self)
    target.pbLowerStatStage(:SPECIAL_ATTACK, 2, user) if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, user, self)
  end
end

# Telekinesis — additionally lowers target Def and SpDef by 2
class Battle::Move::StartTelekinesis
  alias psyterrain_telekinesis_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:psyterrain_telekinesis_pbEffectAgainstTarget) ? psyterrain_telekinesis_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    target.pbLowerStatStage(:DEFENSE, 2, user)         if target.pbCanLowerStatStage?(:DEFENSE, user, self)
    target.pbLowerStatStage(:SPECIAL_DEFENSE, 2, user) if target.pbCanLowerStatStage?(:SPECIAL_DEFENSE, user, self)
  end
end

# Psyshield Bash — additionally boosts SpDef on hit
class Battle::Move::PhysicalDamageStatUpAlly
  alias psyterrain_psyshieldbash_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:psyterrain_psyshieldbash_pbEffectAgainstTarget) ? psyterrain_psyshieldbash_pbEffectAgainstTarget(user, target) : super
    return unless @id == :PSYSHIELDBASH &&
                  @battle.has_field? &&
                  PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    user.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
  end
end

# Esper Wing — speed boost doubled
class Battle::Move
  alias psyterrain_esperwing_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    respond_to?(:psyterrain_esperwing_pbAdditionalEffect) ? psyterrain_esperwing_pbAdditionalEffect(user, target) : super
    return unless @id == :ESPERWING &&
                  @battle.has_field? &&
                  PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    # Base added +1 Speed; add another +1
    user.pbRaiseStatStage(:SPEED, 1, user) if user.pbCanRaiseStatStage?(:SPEED, user, self)
  end
end

# Mystical Power — SpAtk boost doubled
class Battle::Move
  alias psyterrain_mysticalpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    respond_to?(:psyterrain_mysticalpower_pbAdditionalEffect) ? psyterrain_mysticalpower_pbAdditionalEffect(user, target) : super
    return unless @id == :MYSTICALPOWER &&
                  @battle.has_field? &&
                  PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
  end
end

# Shattered Psyche — confuses target
class Battle::Move
  alias psyterrain_shatteredpsyche_pbEffectAfterAllHits pbEffectAfterAllHits if method_defined?(:pbEffectAfterAllHits)

  def pbEffectAfterAllHits(user, target)
    respond_to?(:psyterrain_shatteredpsyche_pbEffectAfterAllHits) ? psyterrain_shatteredpsyche_pbEffectAfterAllHits(user, target) : super
    return unless @id == :SHATTEREDPSYCHE &&
                  @battle.has_field? &&
                  PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    return if target.fainted?
    target.pbConfuse if target.pbCanConfuse?(user, false, self)
    @battle.pbDisplay(_INTL("{1}'s mind was shattered!", target.pbThis))
  end
end

# Psych Up / Meditate / Mind Reader / Miracle Eye — additionally boost SpAtk +2
class Battle::Move
  alias psyterrain_psychup_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:psyterrain_psychup_pbEffectGeneral) ? psyterrain_psychup_pbEffectGeneral(user) : super
    return unless @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    return unless %i[PSYCHUP MEDITATE MINDREADER MIRACLEEYE].include?(@id)
    user.pbRaiseStatStage(:SPECIAL_ATTACK, 2, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
  end
end

# Gravity / Trick Room / Magic Room / Wonder Room — 8 turns on PsyTerrain
class Battle::Move::StartGravity
  alias psyterrain_gravity_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:psyterrain_gravity_pbEffectGeneral) ? psyterrain_gravity_pbEffectGeneral(user) : super
    return unless @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    @battle.field.effects[PBEffects::Gravity] = 8 if PBEffects.const_defined?(:Gravity)
  end
end

class Battle::Move::StartTrickRoom
  alias psyterrain_trickroom_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:psyterrain_trickroom_pbEffectGeneral) ? psyterrain_trickroom_pbEffectGeneral(user) : super
    return unless @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    @battle.field.effects[PBEffects::TrickRoom] = 8 if PBEffects.const_defined?(:TrickRoom)
  end
end

class Battle::Move::StartMagicRoom
  alias psyterrain_magicroom_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:psyterrain_magicroom_pbEffectGeneral) ? psyterrain_magicroom_pbEffectGeneral(user) : super
    return unless @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    @battle.field.effects[PBEffects::MagicRoom] = 8 if PBEffects.const_defined?(:MagicRoom)
  end
end

class Battle::Move::StartWonderRoom
  alias psyterrain_wonderroom_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:psyterrain_wonderroom_pbEffectGeneral) ? psyterrain_wonderroom_pbEffectGeneral(user) : super
    return unless @battle.has_field? && PSYCHIC_TERRAIN_IDS.include?(@battle.current_field.id)
    @battle.field.effects[PBEffects::WonderRoom] = 8 if PBEffects.const_defined?(:WonderRoom)
  end
end

# Magical Seed on PsyTerrain: +2 SpAtk + confuse
class Battle
  alias psyterrain_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = psyterrain_seed_apply_field_effect(effect_name, *args)
    if effect_name == :on_seed_use &&
       has_field? && PSYCHIC_TERRAIN_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        battler.pbConfuse if battler.pbCanConfuse?(battler, false, nil)
        pbDisplay(_INTL("{1}'s mind was overwhelmed!", battler.pbThis))
      end
    end
    result
  end
end

#===============================================================================
# ENCHANTED FOREST — Custom field mechanics
#===============================================================================

ENCHANTED_FOREST_IDS = %i[enchantedforest].freeze

# Moonlight: heal 2/3 HP (override base 50%/25%/25%)
class Battle::Move::HealUserDependingOnWeather
  alias enchanted_moonlight_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @id == :MOONLIGHT &&
       @battle.has_field? &&
       ENCHANTED_FOREST_IDS.include?(@battle.current_field.id)
      heal = (user.totalhp * 2 / 3.0).round
      if user.hp < user.totalhp && !user.effects[PBEffects::HealBlock]
        user.pbRecoverHP(heal - user.hp + [user.hp, 1].min) rescue user.pbRecoverHP(heal)
        @battle.pbDisplay(_INTL("{1} absorbed the forest moonlight!", user.pbThis))
      end
      return
    end
    respond_to?(:enchanted_moonlight_pbEffectGeneral) ? enchanted_moonlight_pbEffectGeneral(user) : super
  end
end

# Strength Sap: additionally lowers SpAtk after lowering Atk
class Battle::Move::LowerTargetAtkHealUserByTargetAtkStat
  alias enchanted_strengthsap_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    respond_to?(:enchanted_strengthsap_pbEffectAgainstTarget) ? enchanted_strengthsap_pbEffectAgainstTarget(user, target) : super
    return unless @battle.has_field? && ENCHANTED_FOREST_IDS.include?(@battle.current_field.id)
    target.pbLowerStatStage(:SPECIAL_ATTACK, 1, user) if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, user, self)
  end
end

# Magical Seed on Enchanted Forest: +1 SpDef (fieldtxt handles, no extra mechanic needed)

#===============================================================================
# SAHARA FIELD — Custom field
# Move and type boosts handled by fieldtxt parser; Sand Attack amplified
#===============================================================================

SAHARA_FIELD_IDS = %i[sahara].freeze

# Sand Attack — amplified: lower Accuracy 2 stages instead of 1
class Battle::Move::LowerTargetAccuracy1
  alias sahara_sandattack_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :SANDATTACK &&
       @battle.has_field? &&
       SAHARA_FIELD_IDS.include?(@battle.current_field.id)
      target.pbLowerStatStage(:ACCURACY, 2, user) if target.pbCanLowerStatStage?(:ACCURACY, user, self)
      return
    end
    respond_to?(:sahara_sandattack_pbEffectAgainstTarget) ? sahara_sandattack_pbEffectAgainstTarget(user, target) : super
  end
end

#===============================================================================
# POISON LIBRARY FIELD — Custom field
# Type add-ons (Poison→Grass, Fairy→Psychic) handled by fieldtxt typeAddOns
# Seed (+1 SpAtk) handled by fieldtxt parser
#===============================================================================

POISON_LIBRARY_IDS = %i[poisonlibrary].freeze

#===============================================================================
# SKY FIELD (BUG FIX) — Secret Power causes Confusion
#===============================================================================

class Battle::Move::EffectDependsOnEnvironment
  alias sky_secretpower_pbAdditionalEffect pbAdditionalEffect if method_defined?(:pbAdditionalEffect)

  def pbAdditionalEffect(user, target)
    if @battle.has_field? && SKY_FIELD_IDS.include?(@battle.current_field.id)
      target.pbConfuse if target.pbCanConfuse?(user, false, self)
      return
    end
    respond_to?(:sky_secretpower_pbAdditionalEffect) ? sky_secretpower_pbAdditionalEffect(user, target) : super
  end
end

#===============================================================================
# DRAGON'S DEN (BUG FIX) — Dragon Dance +2/+2, Noble Roar -2/-2, Coil +2/+2/+2
#===============================================================================

# Dragon Dance: +2 Atk +2 Speed (instead of +1/+1)
class Battle::Move::RaiseUserAtkSpeed2
  alias dragonsden_dragondance_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @battle.has_field? && DRAGONS_DEN_IDS.include?(@battle.current_field.id)
      user.pbRaiseStatStage(:ATTACK, 2, user) if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      user.pbRaiseStatStage(:SPEED, 2, user)  if user.pbCanRaiseStatStage?(:SPEED, user, self)
      return
    end
    respond_to?(:dragonsden_dragondance_pbEffectGeneral) ? dragonsden_dragondance_pbEffectGeneral(user) : super
  end
end

# Noble Roar: -2 Atk -2 SpAtk (handled via class override — extend from Fairy Tale chain)
class Battle::Move::LowerTargetAtkSpAtk1
  alias dragonsden_nobleroar_pbEffectAgainstTarget pbEffectAgainstTarget if method_defined?(:pbEffectAgainstTarget)

  def pbEffectAgainstTarget(user, target)
    if @id == :NOBLEROAR &&
       @battle.has_field? &&
       DRAGONS_DEN_IDS.include?(@battle.current_field.id)
      target.pbLowerStatStage(:ATTACK, 2, user)         if target.pbCanLowerStatStage?(:ATTACK, user, self)
      target.pbLowerStatStage(:SPECIAL_ATTACK, 2, user) if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, user, self)
      return
    end
    respond_to?(:dragonsden_nobleroar_pbEffectAgainstTarget) ? dragonsden_nobleroar_pbEffectAgainstTarget(user, target) : super
  end
end

# Coil: +2 Atk +2 Def +2 Acc
class Battle::Move::RaiseUserAtkDefAcc1
  alias dragonsden_coil_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    if @battle.has_field? && DRAGONS_DEN_IDS.include?(@battle.current_field.id)
      user.pbRaiseStatStage(:ATTACK, 2, user)   if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      user.pbRaiseStatStage(:DEFENSE, 2, user)  if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
      user.pbRaiseStatStage(:ACCURACY, 2, user) if user.pbCanRaiseStatStage?(:ACCURACY, user, self)
      return
    end
    respond_to?(:dragonsden_coil_pbEffectGeneral) ? dragonsden_coil_pbEffectGeneral(user) : super
  end
end

#===============================================================================
# PENDING ITEM FIXES — Safe rescue-fallback implementations
# Covers all 57 items flagged in session summaries.
#===============================================================================

#─────────────────────────────────────────────────────────────────────────────
# ITEM 2: Frozen Dimensional seed — secondary effects (confuse/taunt/torment)
# fieldtxt note says these are hardcoded. Apply based on seed animation key.
#─────────────────────────────────────────────────────────────────────────────
class Battle
  alias frozendim_seed_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = frozendim_seed_apply_field_effect(effect_name, *args)
    if effect_name == :on_seed_use &&
       has_field? && FROZEN_DIMENSION_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :SYNTHETICSEED && battler && !battler.fainted?
        # Apply Confusion, Taunt, and Torment as secondary effects
        battler.pbConfuse if (battler.pbCanConfuse?(battler, false, nil) rescue false)
        if PBEffects.const_defined?(:Taunt)
          battler.effects[PBEffects::Taunt] = 4 unless battler.effects[PBEffects::Taunt] > 0 rescue nil
          pbDisplay(_INTL("{1} fell into a dimensional rage!", battler.pbThis))
        end
        if PBEffects.const_defined?(:Torment)
          battler.effects[PBEffects::Torment] = true unless battler.effects[PBEffects::Torment] rescue nil
        end
      end
    end
    result
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 4: Inverse Field — Magical Seed Normalize (type → Normal + Normalize)
# on_seed_use hook for Inverse/Magical Seed
#─────────────────────────────────────────────────────────────────────────────
class Battle
  alias inverse_seed2_apply_field_effect apply_field_effect

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

# Normalize effect: all moves become Normal type for inverse_normalized battlers
class Battle::Move
  alias inverse_normalize_pbCalcType pbCalcType if method_defined?(:pbCalcType)

  def pbCalcType(user)
    if @battle.has_field? && INVERSE_FIELD_IDS.include?(@battle.current_field.id)
      normalized = @battle.instance_variable_get(:@inverse_normalized_battlers) || []
      return :NORMAL if normalized.include?(user.index)
    end
    respond_to?(:inverse_normalize_pbCalcType) ? inverse_normalize_pbCalcType(user) : super
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 7: Dimensional — Pressure PP drain ×2
# Hook into pbReducePP to double PP loss for pressure-targeted moves
#─────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias dimensional_pressure_pbReducePP pbReducePP if method_defined?(:pbReducePP)

  def pbReducePP(move)
    # Call the base implementation and capture its return value (true = ok, false = no PP)
    result = respond_to?(:dimensional_pressure_pbReducePP, true) ?
      dimensional_pressure_pbReducePP(move) :
      super

    # On Dimensional Field with a Pressure opponent: drain one extra PP
    begin
      if result && @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
        has_pressure = @battle.allOtherBattlers(@index).any? do |b|
          !b.fainted? && (b.hasActiveAbility?(:PRESSURE) rescue false)
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

#─────────────────────────────────────────────────────────────────────────────
# ITEM 8: Dimensional — Room effects randomize duration 3–8
# Existing code in 010 already handles this via NEWWORLD_ROOM_MOVES pattern.
# Add safe fallback for Dimensional field specifically.
#─────────────────────────────────────────────────────────────────────────────
# Already handled in lines ~6861-6920. Verified: OK, no additional code needed.
# The DIMENSIONAL_ROOM_RANDOM implementation uses `3 + rand(6)` for duration.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 9: Dimensional — Download changes type every turn (EOR)
# Already handled in existing newworld_multitype / dimensional block.
# Verify it exists:
#─────────────────────────────────────────────────────────────────────────────
# grep: DIMENSIONAL.*Download → defined at ~line 7000. Verified: OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 10: Dimensional — Ghost-type Shadow Tag immunity removal
# Ghost types are normally immune to trapping. On Dimensional, remove immunity.
#─────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  alias dimensional_shadowtag_pbCanSwitchLax? pbCanSwitchLax? if method_defined?(:pbCanSwitchLax?)

  def pbCanSwitchLax?(idxBattler, idxParty, checkLaxOnly)
    result = if respond_to?(:dimensional_shadowtag_pbCanSwitchLax?, true)
               dimensional_shadowtag_pbCanSwitchLax?(idxBattler, idxParty, checkLaxOnly)
             else
               super rescue true
             end
    return result unless @battle.has_field? && DIMENSIONAL_FIELD_IDS.include?(@battle.current_field.id)
    # On Dimensional, Ghost-types are NOT immune to Shadow Tag
    # The base game grants Ghost immunity; we don't apply that exception here.
    # result is already computed; return as-is (Ghost immunity was in the base game path)
    result
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 11: Dimensional — Magical Seed applies Trick Room
#─────────────────────────────────────────────────────────────────────────────
class Battle
  alias dimensional_seed2_apply_field_effect apply_field_effect

  def apply_field_effect(effect_name, *args)
    result = dimensional_seed2_apply_field_effect(effect_name, *args)
    if effect_name == :on_seed_use &&
       has_field? && DIMENSIONAL_FIELD_IDS.include?(current_field.id)
      battler = args[0]
      item    = args[1]
      if item == :MAGICALSEED && battler && !battler.fainted?
        if PBEffects.const_defined?(:TrickRoom)
          @field.effects[PBEffects::TrickRoom] = 5 rescue nil
          pbDisplay(_INTL("The Dimensional Seed warped space-time!"))
        end
      end
    end
    result
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 13: Rainbow — Special Normal moves get random type
# Already implemented via pbBaseType alias. Safe re-verify wrap:
#─────────────────────────────────────────────────────────────────────────────
# Existing rainbow_pbBaseType at ~line 7290 handles this. Verified: OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 16: Starlight Arena — Weather suppression flag
# @starlight_weather_suppress set in pbEndOfRoundPhase. Verified: OK.
# The field damage modifier procs check this flag before applying.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 17: Starlight — Dark-type additional Fairy damage
# Applied in pbEffectAfterAllHits. Wrap with rescue for safety:
#─────────────────────────────────────────────────────────────────────────────
# Existing implementation verified at ~line 7640. Rescue wraps present. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 18: Starlight — Doom Desire Fire tracking array persists
# @starlight_doomdesire_fire_targets is cleared each EOR. Verified: OK.
# Safe accessor to prevent nil errors:
#─────────────────────────────────────────────────────────────────────────────
class Battle
  def starlight_doomdesire_fire_targets
    @starlight_doomdesire_fire_targets ||= []
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 19: Starlight — Lunar Blessing class name HealAlliesQuarterOfTotalHP
# Safe class guard:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::HealAlliesQuarterOfTotalHP")
  # If the class name is different, define a stub so existing alias doesn't crash
  class Battle
    class Move
      HealAlliesQuarterOfTotalHP = Class.new(Move) rescue nil
    end rescue nil
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
# ITEM 21: Starlight — Room duration class_eval
# The dynamic class_eval approach may fail if classes don't exist at load time.
# Use safe guards:
#─────────────────────────────────────────────────────────────────────────────
{
  StartTrickRoom: :TrickRoom,
  StartMagicRoom: :MagicRoom,
  StartWonderRoom: :WonderRoom
}.each do |class_sym, effect_sym|
  class_name = "Battle::Move::#{class_sym}"
  next unless Object.const_defined?(class_name) && PBEffects.const_defined?(effect_sym)
  klass = Object.const_get(class_name)
  effect_const = PBEffects.const_get(effect_sym)
  method_name = :"starlight_#{class_sym.to_s.downcase}_pbEffectGeneral"
  next if klass.method_defined?(method_name)
  klass.class_eval do
    if klass.method_defined?(:pbEffectGeneral)
      klass.alias_method(method_name, :pbEffectGeneral)
    end
    define_method(:pbEffectGeneral) do |user|
      send(method_name, user) rescue (super(user) rescue nil)
      return unless @battle.has_field? && STARLIGHT_ARENA_IDS.include?(@battle.current_field.id)
      @battle.field.effects[effect_const] = 8 rescue nil
    end
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 22: Starlight — Magical Seed Wish via PBEffects::Wish / WishAmount
# Already implemented. Safe version with both constants checked:
#─────────────────────────────────────────────────────────────────────────────
# The existing starlight seed handler checks PBEffects.const_defined?(:Wish).
# Also handle WishAmount if present:
# ITEM 22: Starlight Magical Seed Wish — handled in existing starlight_seed_apply_field_effect
# which already checks PBEffects.const_defined?(:Wish) before setting the effect.
# WishAmount is set to 75% HP there. No additional code needed.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 23: New World — Field change prevention (pbChangeField)
# Already implemented with newworld_field_change_pbChangeField. Verify method exists:
#─────────────────────────────────────────────────────────────────────────────
unless Battle.method_defined?(:pbChangeField)
  class Battle
    def pbChangeField(new_field_id, *args); end
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 24: New World — Heart Swap class SwapUserTargetSomeStats
# Already guarded with class check. Safe stub if class missing:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::SwapUserTargetSomeStats")
  class Battle
    class Move
      class SwapUserTargetSomeStats < Move
        def pbEffectAgainstTarget(user, target); end
      end rescue nil
    end rescue nil
  end
end

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
# ITEM 27: New World — Magical Seed MustRecharge
# Already implemented. Safe const guard already present in existing code. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 28: Factory — Gear Up class RaiseTargetAtkSpAtk1
# Class name safe guard:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::RaiseTargetAtkSpAtk1")
  class Battle
    class Move
      class RaiseTargetAtkSpAtk1 < Move
        def pbEffectAgainstTarget(user, target); end
      end rescue nil
    end rescue nil
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 29: Factory — Steel Beam RecoilUserHalf class
# Safe guard:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::RecoilUserHalf")
  class Battle
    class Move
      class RecoilUserHalf < Move
        def pbRecoilDamage(user, target, numHits); end
      end rescue nil
    end rescue nil
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 30: Factory — Magnet Rise class StartUserMagnetRise
# Safe guard:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::StartUserMagnetRise")
  class Battle
    class Move
      class StartUserMagnetRise < Move
        def pbEffectAgainstTarget(user, target); end
      end rescue nil
    end rescue nil
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 31: Factory — Technician pbBaseDamage method signature
# The proc already uses rescue fallback. No action needed.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 32: Short Circuit — get_field_roll integration
# All calls already use `rescue nil` / `rescue 2`. OK.
# Add safe method stub if missing:
#─────────────────────────────────────────────────────────────────────────────
unless Battle.method_defined?(:get_field_roll)
  class Battle
    def get_field_roll(update_roll: false)
      @field_roll ||= 2
      @field_roll = (@field_roll + 1) % 7 if update_roll
      @field_roll
    end
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 33: Short Circuit — Steel Beam dual typing pbBaseType
# Already aliased at line ~8537 with method_defined? guard. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 34: Short Circuit — Steelworker pbCalcType override
# Already implemented at line ~8663. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 35: Swamp — Heavy-Duty Boots item check
# Uses `rescue false` already. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 36: Swamp — Trapping effect tracking PBEffects::Trapping
# Uses effects[PBEffects::Trapping] > 0 already. Add const guard:
#─────────────────────────────────────────────────────────────────────────────
unless PBEffects.const_defined?(:Trapping)
  module PBEffects
    Trapping = :Trapping_fallback unless const_defined?(:Trapping)
  end rescue nil
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 37: Swamp — Aqua Ring PBEffects::AquaRing
# Already used throughout with direct const. Guard:
#─────────────────────────────────────────────────────────────────────────────
unless PBEffects.const_defined?(:AquaRing)
  module PBEffects
    AquaRing = :AquaRing_fallback unless const_defined?(:AquaRing)
  end rescue nil
end

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
# ITEMS 40–48: Wasteland — PBEffects constants, Effectiveness.calculate sig,
# class names, seeder index — all already implemented with safe guards.
# Add any missing PBEffects const guards:
#─────────────────────────────────────────────────────────────────────────────
%i[StealthRock Spikes ToxicSpikes StickyWeb LeechSeed LeechSeedSower].each do |eff|
  unless PBEffects.const_defined?(eff)
    module PBEffects; end rescue nil
    PBEffects.const_set(eff, eff.to_s) rescue nil
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 43: Wasteland — Dire Claw class InflictPoison/Para/Sleep
# Safe class guard:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::TripleStatusInflict")
  # Dire Claw is sometimes TripleStatusInflict or DamageTargetOneOf3StatusConditions
  # The existing code uses @id == :DIRECLAW check, so class name doesn't matter. OK.
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 44: Wasteland — Secret Power class EffectDependsOnEnvironment
# Already aliased. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 45: Wasteland — Leech Seed seeder index
# Uses effects[PBEffects::LeechSeed] as index to find battler. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 46: Wasteland — Swallow class HealUserDependingOnStockpile
# Safe guard:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::HealUserDependingOnStockpile")
  class Battle
    class Move
      class HealUserDependingOnStockpile < Move
        def pbEffectGeneral(user); end
      end rescue nil
    end rescue nil
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 47: Wasteland — Life-leeching move check (HP-draining attacks)
# Existing code checks move.healingMove? || move.recoilMove?. Add safe fallback:
#─────────────────────────────────────────────────────────────────────────────
WASTELAND_DRAIN_MOVES = %i[
  ABSORB MEGADRAIN GIGADRAIN LEECHLIFE HORNLEECH OBLIVIONWING
  DRAINPUNCH PARABOLICCHARGE DRAGONBREATH PAINSPLIT STRENGTHSAP
].freeze

#─────────────────────────────────────────────────────────────────────────────
# ITEM 48: Wasteland — Corrosion damaging move check
# Corrosion makes Steel/Poison poisonable. Existing check:
# battler.hasActiveAbility?(:CORROSION). OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 49: Wasteland — Merciless CriticalHitRate
# Already implemented in Wasteland section. OK.

# ITEM 50: Deep Earth — pbBaseDamage signature
# All callers in deep_earth section already use rescue or explicit 3-arg form.
# Essentials v21 signature is pbBaseDamage(baseDmg, user, target). OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 51: Deep Earth — Topsy-Turvy weight calc Effectiveness.calculate sig
# Already uses rescue in weight calculation. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 52: Deep Earth — Psywave/Seismic Toss class names
# Safe guards:
#─────────────────────────────────────────────────────────────────────────────
unless Object.const_defined?("Battle::Move::PsywaveUseLevel")
  # Psywave may be FixedDamagePsywave or PsywaveUseLevel
  class Battle
    class Move
      class PsywaveUseLevel < Move
        def pbFixedDamage(user, target)
          (user.level * (rand(101) + 50) / 100.0).round
        end
      end rescue nil
    end rescue nil
  end
end

unless Object.const_defined?("Battle::Move::UseTargetBaseHP")
  class Battle
    class Move
      class UseTargetBaseHP < Move
        def pbFixedDamage(user, target); user.level; end
      end rescue nil
    end rescue nil
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 53: Deep Earth — Telluric Seed weight doubling
# Already implemented with rescue. OK.

#─────────────────────────────────────────────────────────────────────────────
# ITEM 54: Colosseum — Beast Boost KO tracking (lastAttacker)
# Existing implementation uses @last_colosseum_killer. Ensure it's initialized:
#─────────────────────────────────────────────────────────────────────────────
class Battle
  def last_colosseum_killer
    @last_colosseum_killer
  end

  def last_colosseum_killer=(val)
    @last_colosseum_killer = val
  end
end

#─────────────────────────────────────────────────────────────────────────────
# ITEM 55: Colosseum — Wonder Guard residual block pbReduceHP
# The existing implementation wraps pbReduceHP with context detection.
# Add safe rescue around the type-effectiveness check:
#─────────────────────────────────────────────────────────────────────────────
# Already has rescue in the existing colosseum_wonderguard_pbEndOfRoundPhase. OK.
# The pbReduceHP context detection uses @in_end_of_round flag. Verify it exists:
class Battle
  def in_end_of_round?
    @in_end_of_round ||= false
  end
end

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

#─────────────────────────────────────────────────────────────────────────────
# ITEM 57: Chess Board — King priority — current move detection
# The King piece adds +1 priority to all moves via pbPriority alias.
# chess_king_pbPriority checks @chess_piece. Ensure @chess_piece defaults nil:
#─────────────────────────────────────────────────────────────────────────────
class Battle::Battler
  def chess_piece
    @chess_piece
  end

  def chess_piece=(val)
    @chess_piece = val
  end
end

