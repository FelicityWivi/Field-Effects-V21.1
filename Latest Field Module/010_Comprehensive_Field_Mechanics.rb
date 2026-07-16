#===============================================================================
# Comprehensive Field Mechanics System - SHARED CORE
# Load this file FIRST (before the weather/moves/abilities/items files below).
# Contains the foundational Battle::Field / Battle::Battler / Battle extensions
# (attr_readers, initialize hook, generic helper methods) that the other four
# files all depend on.
#===============================================================================

#===============================================================================
# Comprehensive Field Mechanics System
# Combines: Move Failures, Mimicry, Ability Mods, Cave Collapse, No Charging
#===============================================================================

#===============================================================================
# HELPER: pbFieldRecoverHP
# Defined here so it's always available regardless of DBK load state.
# 011_DBK_Compatibility.rb aliases this to set @stopBoostedHPScaling when DBK
# is installed. If 011 isn't present or DBK isn't installed, this plain version
# is used instead.
#===============================================================================
class Battle::Battler
  def pbFieldRecoverHP(amt, anim = true, *args)
    pbRecoverHP(amt, anim, *args)
  end

  # PE21.1 defines airborne? but not grounded?. Add it here so field code can use both.
  def grounded?
    return !airborne?
  end
end

#===============================================================================
# HELPER: allOtherBattlers
# Returns all battlers (including fainted) except the one at the given index.
# PE v21.1 does not define this method natively; field mechanics use it widely.
# Fainted battlers are included so callers like the Glitch Field recharge-cancel
# check (.any?(&:fainted?)) work correctly. Callers that want only living
# battlers do their own `next if b.fainted?` guard inside their block.
#===============================================================================
class Battle
  def allOtherBattlers(index)
    # Returns all battlers except the one at the given index (including fainted).
    # Callers that only want living battlers do their own `next if b.fainted?` check.
    # Line 10200 (Glitch Field recharge cancel) specifically needs fainted battlers included.
    return @battlers.select { |b| b && b.index != index }
  end
end

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
  
  alias comprehensive_initialize initialize unless method_defined?(:comprehensive_initialize)
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