#===============================================================================
# Field Data Converted from Battle_Field.rb to v21.1 Format
# This file converts the old FIELDEFFECTS hash structure into the new
# Battle::Field plugin format
#===============================================================================

#===============================================================================
# Helper module for converting old field data format to new format
#===============================================================================
module FieldDataConverter
  # Convert old damage mod format to new multiplier format
  # Old: { 1.5 => [:MOVE1, :MOVE2], 2.0 => [:MOVE3] }
  # New: Proc-based multipliers
  def self.convert_damage_mods(field_id, damage_mods, type_boosts, move_messages, type_messages, type_conditions)
    return {} if damage_mods.nil? && type_boosts.nil?
    
    multipliers = {}
    
    # Convert move-specific damage mods
    if damage_mods
      damage_mods.each do |mult, moves|
        moves.each do |move_id|
          message = move_messages&.find { |msg, mv_list| mv_list.include?(move_id) }&.first || ""
          
          multipliers[[:power_multiplier, mult, message]] = \
            proc { |user, target, numTargets, move, type, power, mults|
              next move.id == move_id
            }
        end
      end
    end
    
    # Convert type-specific boosts
    if type_boosts
      type_boosts.each do |mult, types|
        types.each do |type_sym|
          message = type_messages&.find { |msg, type_list| type_list.include?(type_sym) }&.first || ""
          condition = type_conditions&[type_sym]
          
          multipliers[[:power_multiplier, mult, message]] = \
            proc { |user, target, numTargets, move, type, power, mults|
              next false unless type == type_sym
              if condition
                # Evaluate condition
                attacker = user
                opponent = target
                begin
                  result = eval(condition)
                  next result
                rescue
                  next true
                end
              end
              next true
            }
        end
      end
    end
    
    multipliers
  end
  
  # Convert seed data
  def self.convert_seed_data(seed_hash)
    return {} if seed_hash.nil? || seed_hash.empty?
    {
      type: seed_hash[:seedtype],
      effect: seed_hash[:effect],
      duration: seed_hash[:duration],
      message: seed_hash[:message],
      animation: seed_hash[:animation],
      stats: seed_hash[:stats] || {}
    }
  end
  
  # Convert field change conditions
  def self.convert_field_changes(field_change_hash, change_condition_hash, change_message_hash)
    return {} if field_change_hash.nil? || field_change_hash.empty?
    
    changes = {}
    field_change_hash.each do |new_field, moves|
      moves.each do |move_id|
        condition = change_condition_hash&.find { |cond, mv_list| mv_list.include?(move_id) }&.first
        message = change_message_hash&.find { |msg, mv_list| mv_list.include?(move_id) }&.first
        
        changes[move_id] = {
          new_field: new_field,
          condition: condition,
          message: message
        }
      end
    end
    changes
  end
end

#===============================================================================
# Load field data from 005_fieldtxt.rb if available
#===============================================================================
# This would normally load from the FIELDEFFECTS constant
# For now, we'll provide a template showing how to convert each field

#===============================================================================
# Example: Electric Terrain Field Conversion
#===============================================================================
Battle::Field.register(:electerrain, {
  trainer_name: [],
  environment: [],
  map_id: [],
  edge_type: []
})

class Battle::Field_electerrain < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id = :electerrain
    @name = _INTL("Electric Terrain")
    
    # Field announcement message
    @field_announcement[:start] = _INTL("The field is hyper-charged!")
    
    # Nature Power and related moves
    @nature_power_change = :THUNDERBOLT
    @mimicry_type = :ELECTRIC
    @camouflage_type = :ELECTRIC
    @secret_power_effect = :SHOCKWAVE
    @terrain_pulse_type = :ELECTRIC
    
    # Status moves boosted by this field
    @status_mods = [] # Add status moves that are boosted
    
    # Seed data
    @seed_type = nil # Set if this field has a special seed
    
    # Define multipliers using the new format
    # Format: key=[:mult_type, mult_value, "display message"], value=proc { ... }
    
    # Explosion/Self-Destruct get hyper-charged (1.5x, Electric type)
    @multipliers[[:power_multiplier, 1.5, _INTL("The explosion became hyper-charged!")]] = \
      proc { |user, target, numTargets, move, type, power, mults|
        next [:EXPLOSION, :SELFDESTRUCT].include?(move.id)
      }
    
    # Hurricane, Surf, etc. get hyper-charged (1.5x)
    @multipliers[[:power_multiplier, 1.5, _INTL("The attack became hyper-charged!")]] = \
      proc { |user, target, numTargets, move, type, power, mults|
        next [:HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS].include?(move.id)
      }
    
    # Magnet Bomb powered up (2.0x)
    @multipliers[[:power_multiplier, 2.0, _INTL("The attack powered up!")]] = \
      proc { |user, target, numTargets, move, type, power, mults|
        next move.id == :MAGNETBOMB
      }
    
    # Electric-type moves boosted (1.5x) if user is grounded
    @multipliers[[:power_multiplier, 1.5, _INTL("The Electric Terrain strengthened the attack!")]] = \
      proc { |user, target, numTargets, move, type, power, mults|
        next false unless type == :ELECTRIC
        next !user.airborne? # Grounded Pokemon only
      }
    
    # Add move type changes
    @effects[:base_type_change] = proc { |user, move, ret|
      if [:EXPLOSION, :SELFDESTRUCT, :SMACKDOWN, :SURF, :MUDDYWATER, :HURRICANE, :THOUSANDARROWS].include?(move.id)
        next :ELECTRIC
      end
      next nil
    }
    
    # Add move second type effects
    @effects[:move_second_type] = proc { |ret, move, moveType, defType, user, target|
      if [:EXPLOSION, :SELFDESTRUCT, :SMACKDOWN, :SURF, :MUDDYWATER, :HURRICANE, :THOUSANDARROWS].include?(move.id)
        next :ELECTRIC
      end
      next nil
    }
  end
end

#===============================================================================
# Template for Converting Other Fields
# Copy this template for each field in FIELDEFFECTS
#===============================================================================

# To convert a field from the old format, follow these steps:
#
# 1. Register the field:
#    Battle::Field.register(:fieldname, {
#      trainer_name: [],
#      environment: [],
#      map_id: [],
#      edge_type: []
#    })
#
# 2. Create the field class:
#    class Battle::Field_fieldname < Battle::Field
#      def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
#        super
#        @id = :fieldname
#        @name = _INTL("Field Display Name")
#
# 3. Convert field messages:
#    @field_announcement[:start] = _INTL("Message from :fieldMessage array")
#
# 4. Convert move changes:
#    @nature_power_change = :MOVEID  # from :naturePower
#    @mimicry_type = :TYPE           # from :mimicry
#    @secret_power_effect = :MOVEID  # from :secretPower
#
# 5. Convert damage mods and type boosts to multipliers:
#    For each entry in :damageMods:
#      @multipliers[[:power_multiplier, value, _INTL("Message from :moveMessages")]] = \
#        proc { |user, target, numTargets, move, type, power, mults|
#          next move.id == :MOVEID
#        }
#
#    For each entry in :typeBoosts:
#      @multipliers[[:power_multiplier, value, _INTL("Message from :typeMessages")]] = \
#        proc { |user, target, numTargets, move, type, power, mults|
#          next false unless type == :TYPENAME
#          # Add condition from :typeCondition if it exists
#          next true
#        }
#
# 6. Convert type mods:
#    @effects[:base_type_change] = proc { |user, move, ret|
#      if [:MOVE1, :MOVE2].include?(move.id)  # from :typeMods
#        next :NEWTYPE
#      end
#      next nil
#    }
#
# 7. Convert status mods:
#    @status_mods = [:MOVE1, :MOVE2]  # from :statusMods array
#
# 8. Convert seed data:
#    @seed_type = :SEEDTYPE        # from :seed[:seedtype]
#    @seed_effect = :EFFECT        # from :seed[:effect]
#    @seed_duration = duration     # from :seed[:duration]
#    @seed_message = _INTL("msg")  # from :seed[:message]
#    @seed_animation = :ANIM       # from :seed[:animation]
#    @seed_stats = {}              # from :seed[:stats]
#
# 9. Convert field changes:
#    # Field changes are handled through events in the new system
#    # Add to @effects[:end_of_move] or appropriate trigger
#
# 10. Convert accuracy mods:
#     @effects[:accuracy_modify] = proc { |user, target, move, modifiers, calcType|
#       if move.id == :MOVEID
#         modifiers[:accuracy_multiplier] = value
#       end
#     }
#
# 11. Handle overlay effects (for Rejuvenation):
#     @overlay_status_mods = [:MOVE1]  # from :overlay[:statusMods]
#     @overlay_type_mods = {}          # from :overlay[:typeMods]
#     # Similar conversion for other overlay properties

#===============================================================================
# Conversion Script for All Fields
# This script can be used to automatically convert fields
#===============================================================================

# Uncomment and run this in the console to generate conversion templates:
=begin
if defined?(FIELDEFFECTS)
  FIELDEFFECTS.each do |field_id, field_data|
    next if field_id == :INDOOR # Skip base field
    
    puts "#" + "="*79
    puts "# #{field_data[:name] || field_id.to_s.capitalize}"
    puts "#" + "="*79
    puts ""
    puts "Battle::Field.register(:#{field_id.to_s.downcase}, {"
    puts "  trainer_name: [],"
    puts "  environment: [],"
    puts "  map_id: [],"
    puts "  edge_type: []"
    puts "})"
    puts ""
    puts "class Battle::Field_#{field_id.to_s.downcase} < Battle::Field"
    puts "  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)"
    puts "    super"
    puts "    @id = :#{field_id.to_s.downcase}"
    puts "    @name = _INTL(\"#{field_data[:name]}\")" if field_data[:name]
    puts ""
    
    # Field message
    if field_data[:fieldMessage] && !field_data[:fieldMessage].empty?
      puts "    @field_announcement[:start] = _INTL(\"#{field_data[:fieldMessage][0]}\")"
    end
    
    # Nature Power, etc.
    puts "    @nature_power_change = :#{field_data[:naturePower]}" if field_data[:naturePower]
    puts "    @mimicry_type = :#{field_data[:mimicry]}" if field_data[:mimicry]
    puts "    @secret_power_effect = :#{field_data[:secretPower]}" if field_data[:secretPower]
    puts ""
    
    # Status mods
    if field_data[:statusMods] && !field_data[:statusMods].empty?
      puts "    @status_mods = #{field_data[:statusMods].inspect}"
      puts ""
    end
    
    puts "    # TODO: Convert damage mods, type boosts, and other effects"
    puts "    # See template above for details"
    puts "  end"
    puts "end"
    puts ""
  end
end
=end

#===============================================================================
# Additional Field Effect Handlers
#===============================================================================

# Handler for field-specific passive damage (burning fields, underwater, etc.)
class Battle::Battler
  def field_passive_damage?
    return false if fainted?
    
    case @battle.current_field&.id
    when :volcanic, :superheated, :volcanictop, :infernal
      # Burning field passive damage
      return false if pbHasType?(:FIRE) || @effects[PBEffects::AquaRing]
      return false if hasActiveAbility?([:FLAREBOOST, :MAGMAARMOR, :FLAMEBODY, :FLASHFIRE,
                                         :WATERVEIL, :MAGICGUARD, :HEATPROOF, :WATERBUBBLE])
      # Check if using Dig or Dive
      if @effects[PBEffects::TwoTurnAttack]
        move_data = GameData::Move.try_get(@effects[PBEffects::TwoTurnAttack])
        return false if move_data && [:DIG, :DIVE].include?(move_data.function_code)
      end
      return true
      
    when :underwater
      # Underwater field passive damage
      return false if pbHasType?(:WATER)
      return false if hasActiveAbility?([:SWIFTSWIM, :MAGICGUARD])
      effectiveness = Effectiveness.calculate(:WATER, *pbTypes(true))
      return false if effectiveness <= Effectiveness::NOT_VERY_EFFECTIVE_ONE
      return true
      
    when :murkwatersurface
      # Murky water surface passive damage (poison-like)
      return false if pbHasType?(:STEEL) || pbHasType?(:POISON)
      return false if hasActiveAbility?([:POISONHEAL, :MAGICGUARD, :WONDERGUARD, 
                                         :TOXICBOOST, :IMMUNITY, :PASTELVEIL, :SURGESURFER])
      return true
    end
    
    return false
  end
end

# Handler for field defense boosts
class Battle::Move
  def field_defense_boost(type, target)
    defmult = 1.0
    
    case @battle.current_field&.id
    when :misty
      defmult *= 1.5 if specialMove?(type) && target.pbHasType?(:FAIRY)
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
      if physicalMove?(type) && target.pbHasType?(:ICE) && @battle.pbWeather == :Hail
        defmult *= 1.5
      end
    when :desert
      defmult *= 1.5 if specialMove?(type) && target.pbHasType?(:GROUND)
    when :dimensional
      defmult *= 1.5 if target.pbHasType?(:GHOST)
    when :frozendimension
      defmult *= 1.2 if target.pbHasType?(:GHOST) || target.pbHasType?(:ICE)
      defmult *= 0.8 if target.pbHasType?(:FIRE)
    when :darkness2
      defmult *= 1.1 if target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
    when :darkness3
      defmult *= 1.2 if target.pbHasType?(:DARK) || target.pbHasType?(:GHOST)
    end
    
    return defmult
  end
end

#===============================================================================
# Field Counter Management (for fields like Crystal Cavern, Short Circuit)
#===============================================================================
class Battle
  # Get a roll value for fields that use rolling mechanics
  def get_field_roll(update_roll: true, maximize_roll: false)
    field = @current_field
    return nil unless field
    
    case field.id
    when :crystalcavern
      choices = [1, 2, 3, 4, 5, 6] # Example roll choices
      counter = @field_counters.counter
      result = choices[counter % choices.length]
      @field_counters.counter = (counter + 1) % choices.length if update_roll
      result = choices.max if maximize_roll
      return result
      
    when :shortcircuit
      choices = [1, 2, 3, 4, 5, 6] # Example roll choices
      counter = @field_counters.counter
      result = choices[counter % choices.length]
      @field_counters.counter = (counter + 1) % choices.length if update_roll
      result = choices.max if maximize_roll
      return result
    end
    
    return nil
  end
  
  # Reset field-specific counters
  def reset_field_counters
    @field_counters.counter = 0
    @field_counters.counter2 = 0
    @field_counters.counter3 = 0
  end
end

#===============================================================================
# Notes for Full Conversion
#===============================================================================

# The Battle_Field.rb file contains a PokeBattle_Field class with the following
# key features that need to be converted:
#
# 1. Field layers (@layer array) - Already handled by stacked_fields in new system
# 2. Field counters (@counter, @counter2, etc.) - Added as @field_counters object
# 3. Pledge moves (@pledge) - Needs to be added to Battle class
# 4. Field duration and conditions - Already handled in new system
# 5. Field overlay system - Already handled in new system
# 6. Roll system for certain fields - Added as get_field_roll method
#
# To complete the conversion:
# 1. Convert each field definition from FIELDEFFECTS hash to Battle::Field_xxx class
# 2. Test each field's mechanics in battle
# 3. Adjust multiplier conditions as needed
# 4. Add any missing field-specific effects
# 5. Verify field transitions work correctly
# 6. Test field counters and roll systems
