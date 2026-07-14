#===============================================================================
# Comprehensive Field Mechanics System - WEATHER
# Weather-related field mechanics: blocked/extended weather, weather-based
# field transitions, weather-dependent move/ability behavior.
# Requires: 000_Field_Mechanics_Shared.rb to be loaded first.
#===============================================================================


#===============================================================================
# 9. BLOCKED WEATHER
# Prevent certain weather conditions on specific fields
#===============================================================================
class Battle::Field
  alias blocked_weather_initialize initialize unless method_defined?(:blocked_weather_initialize)
  
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

# Sandstorm: 1/8 damage in a single hit (Field Effect Manual: "Sandstorm deals
# 1/8 Max HP damage per turn (from 1/16)").
#
# Strategy: override Battle#pbEORWeatherDamage so Desert Field sandstorm damage
# runs at the correct point in the EOR pipeline — inside pbEOREndWeather, which
# fires BEFORE pbEORSwitch. This fixes two bugs:
#
#   Bug 1 (Struggle / no-target): the post-chain EOR alias ran after pbEORSwitch
#          had already completed, so calling pbFaint there triggered a phantom
#          action on the opposing side.
#   Bug 2 (newly sent-out Pokémon hit): pbEORSwitch sent out the replacement
#          before the post-chain sandstorm block ran, so the new Pokémon was
#          iterated and took damage in the same turn it was sent out.
#
# Using pbEORWeatherDamage ensures the priority list is the pre-switch snapshot,
# PE's own faint/item/ability logic applies, and no post-switch battlers are hit.
#
# Both Desert Field (sandstorm 1/8) and Dimensional Field (shadow sky 1/8) are
# handled in ONE override so only a single pbEORWeatherDamage definition exists
# in this file. The Dimensional Field section is defined later in the file;
# splitting across two class reopens would cause the second def to silently
# overwrite the first. Combining them here keeps the alias chain clean.
class Battle
  alias field_base_pbEORWeatherDamage pbEORWeatherDamage unless method_defined?(:field_base_pbEORWeatherDamage)
  def pbEORWeatherDamage(battler)
    # ── Desert Field: sandstorm → 1/8 HP ──────────────────────────────────────
    # Immunity checks mirror takesSandstormDamage? exactly.
    if battler.effectiveWeather == :Sandstorm &&
       has_field? && DESERT_FIELD_IDS.include?(current_field.id)
      return if battler.fainted?
      return unless battler.takesIndirectDamage?
      return if battler.pbHasType?(:GROUND) || battler.pbHasType?(:ROCK) || battler.pbHasType?(:STEEL)
      return if battler.inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderground",
                                         "TwoTurnAttackInvulnerableUnderwater")
      return if battler.hasActiveAbility?([:OVERCOAT, :SANDFORCE, :SANDRUSH, :SANDVEIL])
      return if battler.hasActiveItem?(:SAFETYGOGGLES)
      amt = (battler.totalhp / 8.0).round
      return unless amt > 0
      pbDisplay(_INTL("{1} is buffeted by the sandstorm!", battler.pbThis))
      @scene.pbDamageAnimation(battler)
      battler.pbReduceHP(amt, false)
      battler.pbItemHPHealCheck
      battler.pbFaint if battler.fainted?
      return
    end
    # ── Dimensional Field: shadow sky → 1/8 HP, Dark/Ghost immune ─────────────
    if battler.effectiveWeather == :ShadowSky &&
       has_field? && defined?(DIMENSIONAL_FIELD_IDS) && DIMENSIONAL_FIELD_IDS.include?(current_field.id)
      return if battler.fainted?
      return unless battler.takesIndirectDamage?
      return if battler.shadowPokemon?
      return if battler.pbHasType?(:DARK) || battler.pbHasType?(:GHOST)
      return if battler.hasActiveAbility?([:OVERCOAT, :MAGICGUARD])
      amt = (battler.totalhp / 8.0).round
      return unless amt > 0
      pbDisplay(_INTL("{1} is hurt by the shadow sky!", battler.pbThis))
      @scene.pbDamageAnimation(battler)
      battler.pbReduceHP(amt, false)
      battler.pbItemHPHealCheck
      battler.pbFaint if battler.fainted?
      return
    end
    field_base_pbEORWeatherDamage(battler)
  end
end

# Sunny Day: Grass/Water take 1/8 damage EOR (unless Solar Power/Chlorophyll).
# This intentionally runs in the post-chain EOR alias (after pbEORSwitch) so
# only Pokémon that were present during the turn are affected.
# NOTE: pbFaint and pbAbilitiesOnDamageTaken are intentionally NOT called here —
# at this point in the chain pbEORSwitch has already run, so a mid-chain faint
# would leave a vacant slot until the next turn's start. PE's end-of-round
# judge checkpoint handles any resulting faint correctly.
class Battle
  alias desert_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:desert_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    respond_to?(:desert_pbEndOfRoundPhase) ? desert_pbEndOfRoundPhase : super
    return unless has_field? && DESERT_FIELD_IDS.include?(current_field.id)
    return unless [:Sun, :HarshSun].include?(pbWeather)
    allBattlers.each do |b|
      next if b.fainted?
      next unless b.pbHasType?(:GRASS) || b.pbHasType?(:WATER)
      next if b.hasActiveAbility?([:SOLARPOWER, :CHLOROPHYLL])
      dmg = b.totalhp / 8
      next unless dmg > 0
      b.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is hurt by the intense sun!", b.pbThis))
    end
  end
end

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

# Ice-type Defense boost during Hail (1.5x)
class Battle::Move
  alias snowy_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:snowy_pbCalcDamageMultipliers)
  
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

# Tailwind - Lasts 6 turns and creates Strong Winds (same as Volcanic Top)
# Already implemented in Volcanic Top section, reuse here

# Special Flying moves get additional 1.5x boost during Strong Winds
class Battle::Move
  alias mountain_flying_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:mountain_flying_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:mountain_flying_pbCalcDamageMultipliers) ? mountain_flying_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
    # On Mountain Field during Strong Winds, special Flying moves get extra boost
    return unless @battle.has_field? && MOUNTAIN_FIELD_IDS.include?(@battle.current_field.id)
    return unless @battle.field.weather == :StrongWinds
    return unless type == :FLYING && specialMove?(type)
    multipliers[:base_damage_multiplier] *= 1.5
  end
end

class Battle::Move
  alias mountain_wind_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:mountain_wind_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    respond_to?(:mountain_wind_pbCalcDamageMultipliers) ? mountain_wind_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers) : super
    # Wind moves get 1.5x boost during Strong Winds on Mountain Field
    return unless @battle.has_field? && MOUNTAIN_FIELD_IDS.include?(@battle.current_field.id)
    return unless @battle.field.weather == :StrongWinds
    return unless MOUNTAIN_WIND_MOVES.include?(@id)
    multipliers[:base_damage_multiplier] *= 1.5
  end
end

# Hail weather transformation to Snowy Mountain after 3 consecutive turns
class Battle
  alias mountain_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:mountain_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    respond_to?(:mountain_pbEndOfRoundPhase) ? mountain_pbEndOfRoundPhase : super
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

# Tailwind - Lasts 6 turns and creates Strong Winds on Volcanic Top
class Battle::Move::StartUserSideDoubleSpeed
  alias volcanictop_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral) && !method_defined?(:volcanictop_pbEffectGeneral)
  
  def pbEffectGeneral(user)
    ret = respond_to?(:volcanictop_pbEffectGeneral) ? volcanictop_pbEffectGeneral(user) : super
    
    # On Volcanic Top, Tailwind lasts 6 turns and creates Strong Winds
    if @battle.has_field? && VOLCANIC_TOP_IDS.include?(@battle.current_field.id)
      user.pbOwnSide.effects[PBEffects::Tailwind] = 6
      # Start Strong Winds weather
      @battle.pbStartWeather(user, :StrongWinds, true)
    end
    
    return ret
  end
end

# Volcanic Eruption System
# Triggered by specific moves and Desolate Land ability
class Battle
  attr_accessor :volcanic_eruption_triggered
  
  alias volcanictop_eruption_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:volcanictop_eruption_pbEndOfRoundPhase)
  
  def pbEndOfRoundPhase
    respond_to?(:volcanictop_eruption_pbEndOfRoundPhase) ? volcanictop_eruption_pbEndOfRoundPhase : super
    
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
    @sides.each do |side|
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

# NOTE: Stealth Rock doubled damage (:hazardMultiplier key) needs manual implementation
# in the base game's entry hazard damage code (Battle::Battler#pbCheckEntryHazards or similar)
# by checking if @battle.has_field? && @battle.current_field.hazard_multiplier[:StealthRock]

#===============================================================================
# 16. WEATHER-BASED FIELD TRANSITIONS
# Fields can transition to other fields based on active weather at end of round
#===============================================================================

class Battle
  alias weather_field_change_pbEOREndWeather pbEOREndWeather if method_defined?(:pbEOREndWeather) && !method_defined?(:weather_field_change_pbEOREndWeather)
  
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
  alias field_weather_duration_pbStartWeather pbStartWeather if method_defined?(:pbStartWeather) && !method_defined?(:field_weather_duration_pbStartWeather)
  
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
    alias field_weather_custom_pbStartWeather customweather_pbStartWeather if method_defined?(:customweather_pbStartWeather) && !method_defined?(:field_weather_custom_pbStartWeather)
    
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
      respond_to?(:field_weather_custom_pbStartWeather) ? field_weather_custom_pbStartWeather(user, newWeather, fixedDuration, showAnimation) : super
      
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

# SHORE UP - Full HP restore instead of partial
# Shore Up's function code is "HealUserDependingOnSandstorm".
# We override pbEffectGeneral to fully restore HP on beach field.
class Battle::Move::HealUserDependingOnSandstorm
  alias beach_shore_up_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral) && !method_defined?(:beach_shore_up_pbEffectGeneral)

  def pbEffectGeneral(user)
    return respond_to?(:beach_shore_up_pbEffectGeneral) ? beach_shore_up_pbEffectGeneral(user) : super unless @battle.has_field? && BEACH_FIELD_IDS.include?(@battle.current_field.id)
    return unless id == :SHOREUP
    return unless user.canHeal?
    user.pbFieldRecoverHP(user.totalhp)
    @battle.pbDisplay(_INTL("{1} was fully restored by the Beach!", user.pbThis))
  end
end

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

# Ice-type Defense boost during Hail on Icy field
# Ice-types get 1.5x Defense when Hail/Snow is active
# Hook into damage calculation for the target
class Battle::Move
  alias icy_ice_defense_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:icy_ice_defense_pbCalcDamageMultipliers)
  
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

#===============================================================================
# FROZEN DIMENSIONAL FIELD MECHANICS
# Move failures, Hail damage doubling, Aurora Veil bypass, Rage dark type,
# Dragon Rage 140 damage, Power Trip 40bp/stage, Snarl -2, Parting Shot +Speed
#===============================================================================

FROZEN_DIMENSION_IDS = %i[frozendimension].freeze

# Hail/Shadow Sky - Double passive damage on Frozen Dimensional
# Hook into Battle's EOR weather damage. Normal hail = 1/16; on FZD = 1/8
class Battle
  alias frozendim_hail_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:frozendim_hail_pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    respond_to?(:frozendim_hail_pbEndOfRoundPhase) ? frozendim_hail_pbEndOfRoundPhase : super
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

# Tailwind - Creates Strong Winds on Sky Field (in addition to Volcanic Top)
class Battle::Move::StartUserSideDoubleSpeed
  alias sky_tailwind_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral) && !method_defined?(:sky_tailwind_pbEffectGeneral)

  def pbEffectGeneral(user)
    respond_to?(:sky_tailwind_pbEffectGeneral) ? sky_tailwind_pbEffectGeneral(user) : super

    if @battle.has_field? && SKY_FIELD_IDS.include?(@battle.current_field.id)
      @battle.pbStartWeather(user, :StrongWinds, true)
      @battle.pbDisplay(_INTL("The skies filled with powerful winds!"))
    end
  end
end

#──────────────────────────────────────────────────────────────────────────────
# PASSIVE: All field damage modifiers suppressed by weather (except Strong Winds)
# We hook into the multiplier system. When weather is active (not Clear / Strong
# Winds), we reset any field boost back to 1.0 for damage calculation.
# Implemented by zeroing out the field's typeBoosts during dmg calc under weather.
# Practical approach: override pbCalcDamageMultipliers to cancel field type boosts.
#──────────────────────────────────────────────────────────────────────────────
class Battle::Move
  alias starlight_suppress_pbCalcDamageMultipliers pbCalcDamageMultipliers if method_defined?(:pbCalcDamageMultipliers) && !method_defined?(:starlight_suppress_pbCalcDamageMultipliers)

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
      respond_to?(:starlight_suppress_pbCalcDamageMultipliers) ? starlight_suppress_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, mults) : super
    else
      super
    end
  ensure
    @starlight_weather_suppress = false
  end
end

# Moonlight: heal 2/3 HP (override base 50%/25%/25%)
class Battle::Move::HealUserDependingOnWeather
  alias enchanted_moonlight_pbEffectGeneral pbEffectGeneral if method_defined?(:pbEffectGeneral) && !method_defined?(:enchanted_moonlight_pbEffectGeneral)

  def pbEffectGeneral(user)
    if @id == :MOONLIGHT &&
       @battle.has_field? &&
       ENCHANTED_FOREST_IDS.include?(@battle.current_field.id)
      heal = (user.totalhp * 2 / 3.0).round
      if user.hp < user.totalhp && !user.effects[PBEffects::HealBlock]
        user.pbFieldRecoverHP(heal - user.hp + [user.hp, 1].min) rescue user.pbFieldRecoverHP(heal)
        @battle.pbDisplay(_INTL("{1} absorbed the forest moonlight!", user.pbThis))
      end
      return
    end
    respond_to?(:enchanted_moonlight_pbEffectGeneral) ? enchanted_moonlight_pbEffectGeneral(user) : super
  end
end

#===============================================================================
# SUPER-HEATED FIELD MECHANICS
# (Field data defined in 005_fieldtxt.rb; parsed automatically by 007)
#
# Hardcoded effects not expressible in fieldtxt:
#   1. Steam generation — certain Water moves lower all active battlers'
#      Accuracy by 1 stage (semi-invulnerable Pokémon are unaffected).
#   2. Outrage / Thrash / Petal Dance fatigue after only 1 turn instead of 2–3.
#   3. EOR — Hail weather is terminated.
#===============================================================================

SUPERHEATED_IDS = %i[superheated].freeze

# ---------------------------------------------------------------------------
# End of round: terminate Hail / Snow weather on the Super-Heated Field.
# ---------------------------------------------------------------------------
class Battle
  alias superheated_eor_pbEndOfRoundPhase pbEndOfRoundPhase if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:superheated_eor_pbEndOfRoundPhase)

  def pbEndOfRoundPhase
    respond_to?(:superheated_eor_pbEndOfRoundPhase) ? superheated_eor_pbEndOfRoundPhase : super
    return unless has_field? && SUPERHEATED_IDS.include?(current_field.id)

    if [:Hail, :Snow].include?(pbWeather)
      pbDisplay(_INTL("The hail melted away!"))
      pbStartWeather(nil, :None, false) rescue (@field.weather = :None; @field.weatherDuration = 0)
    end
  end
end