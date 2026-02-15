#===============================================================================
# Field Text Parser
# Converts FIELDEFFECTS hash data into Battle::Field classes
#===============================================================================

class FieldTextParser
  MULTIPLIER_TYPE_MAP = {
    power: :power_multiplier,
    defense: :defense_multiplier,
    attack: :attack_multiplier,
    final_damage: :final_damage_multiplier
  }

  def self.parse_all_fields
    return unless defined?(FIELDEFFECTS)
    
    parsed_count = 0
    failed_count = 0
    
    FIELDEFFECTS.each do |field_id, field_data|
      next if field_id == :INDOOR # Skip base/indoor field as it's handled separately
      begin
        create_field_class(field_id, field_data)
        parsed_count += 1
      rescue => e
        failed_count += 1
        if $DEBUG
          Console.echo_li("Failed to parse field #{field_id}: #{e.message}")
          Console.echo_li(e.backtrace.first)
        end
      end
    end
    
    if $DEBUG
      Console.echo_li("Field Parser: #{parsed_count} fields parsed, #{failed_count} failed")
    end
  end

  def self.create_field_class(field_id, data)
    field_id_lower = field_id.to_s.downcase.to_sym
    class_name_short = "Field_#{field_id_lower}"
    
    # Skip if class already exists
    return if Battle.const_defined?(class_name_short)
    
    # Create the field class dynamically
    field_class = Class.new(Battle::Field) do
      define_method(:initialize) do |battle, duration = Battle::Field::DEFAULT_FIELD_DURATION|
        super(battle, duration)
        
        @id = field_id_lower
        @name = data[:name] || field_id.to_s.capitalize
        
        # Set field properties from text data
        @nature_power_change = data[:naturePower] if data[:naturePower]
        @mimicry_type = data[:mimicry] if data[:mimicry]
        @camouflage_type = data[:mimicry] if data[:mimicry] # Usually same as mimicry
        @secret_power_effect = parse_secret_power(data[:secretPower]) if data[:secretPower]
        @terrain_pulse_type = data[:mimicry] if data[:mimicry]
        
        # Field announcements
        if data[:fieldMessage] && data[:fieldMessage][0]
          @field_announcement = {
            start: data[:fieldMessage][0],
            end: data[:fieldMessage][1] || "The field effect ended!"
          }
        end
        
        # Parse damage modifiers into multipliers
        parse_damage_mods(data[:damageMods], data[:moveMessages]) if data[:damageMods]
        
        # Parse type boosts into multipliers
        parse_type_boosts(data[:typeBoosts], data[:typeMessages], data[:typeCondition]) if data[:typeBoosts]
        
        # Parse accuracy modifiers
        parse_accuracy_mods(data[:accuracyMods]) if data[:accuracyMods]
        
        # Parse move type changes
        parse_type_mods(data[:typeMods]) if data[:typeMods]
        
        # Parse type add-ons (secondary types)
        parse_type_addons(data[:typeAddOns]) if data[:typeAddOns]
        
        # Parse field changes
        parse_field_changes(data[:fieldChange], data[:changeMessage], data[:changeCondition]) if data[:fieldChange]
        
        # Parse move effects
        parse_move_effects(data[:moveEffects]) if data[:moveEffects]
        
        # Parse type effects
        parse_type_effects(data[:typeEffects]) if data[:typeEffects]
        
        # Parse change effects
        parse_change_effects(data[:changeEffects]) if data[:changeEffects]
      end
      
      # Helper methods for parsing
      define_method(:parse_secret_power) do |power_move|
        # Map move IDs to secret power effect numbers
        case power_move.to_s.upcase
        when "SHOCKWAVE", "THUNDERBOLT" then 1 # Paralyze
        when "SEEDBOMB", "ENERGYBALL" then 2 # Sleep
        when "MOONBLAST", "FAIRYWIND" then 3 # Lower Sp.Atk
        when "PSYCHIC", "CONFUSION" then 4 # Lower Speed
        when "HYDROPUMP", "WATERPULSE" then 5 # Lower Attack
        when "MUDBOMB", "MUDSHOT" then 6 # Lower Speed
        when "ROCKSLIDE", "ROCKTHROW" then 7 # Flinch
        when "EARTHQUAKE", "MUDSLAP" then 8 # Lower Accuracy
        when "BLIZZARD", "ICESHARD" then 9 # Freeze
        when "INCINERATE", "FLAMETHROWER" then 10 # Burn
        when "SHADOWBALL", "SHADOWSNEAK" then 11 # Flinch
        when "AIRSLASH", "GUST" then 12 # Lower Speed
        when "DRACOMETEOR", "SWIFT" then 13 # Flinch
        when "PSYSHOCK", "PSYWAVE" then 14 # Lower Defense
        when "SMOG", "SLUDGE" then 15 # Poison
        when "HEAVYSLAM", "IRONHEAD" then 16 # Flinch
        when "BEATUP", "PURSUIT" then 2 # Sleep (for backalley)
        else 0 # Paralyze (default)
        end
      end
      
      define_method(:parse_damage_mods) do |damage_mods, move_messages|
        damage_mods.each do |multiplier, moves|
          next if moves.nil? || moves.empty?
          
          # Get the message for these moves
          message = nil
          if move_messages
            move_messages.each do |msg, msg_moves|
              if (msg_moves & moves).any?
                message = msg
                break
              end
            end
          end
          
          # Determine multiplier type based on value
          mult_type = if multiplier == 0
            nil # Move fails
          elsif multiplier < 1.0
            :power_multiplier
          else
            :power_multiplier
          end
          
          next unless mult_type
          
          @multipliers[[mult_type, multiplier, message]] = proc { |user, target, numTargets, move, type, power, mults|
            next true if moves.include?(move.id)
          }
        end
      end
      
      define_method(:parse_type_boosts) do |type_boosts, type_messages, type_conditions|
        type_boosts.each do |multiplier, types|
          next if types.nil? || types.empty?
          
          # Get the message for these types
          message = nil
          if type_messages
            type_messages.each do |msg, msg_types|
              if (msg_types & types).any?
                message = msg
                break
              end
            end
          end
          
          @multipliers[[:power_multiplier, multiplier, message]] = proc { |user, target, numTargets, move, type, power, mults|
            next false unless types.include?(type)
            
            # Check type condition if exists
            if type_conditions && type_conditions[type]
              condition = type_conditions[type]
              
              # Parse and evaluate condition
              begin
                # Replace common condition variables
                condition_str = condition.dup
                condition_str.gsub!('attacker', 'user')
                condition_str.gsub!('opponent', 'target')
                condition_str.gsub!('self', 'move')
                condition_str.gsub!('isAirborne?', 'airborne?')
                condition_str.gsub!('!user.airborne?', 'user.grounded?')
                condition_str.gsub!('!target.airborne?', 'target.grounded?')
                
                # Evaluate condition in context
                result = eval(condition_str)
                next result
              rescue => e
                # If condition fails to evaluate, skip it
                next true
              end
            end
            
            next true
          }
        end
      end
      
      define_method(:parse_accuracy_mods) do |accuracy_mods|
        return unless accuracy_mods
        
        @effects[:accuracy_modify] = proc { |user, target, move, modifiers, type|
          accuracy_mods.each do |accuracy, moves|
            if moves.include?(move.id)
              if accuracy == 0
                modifiers[:base_accuracy] = 0 # Always hit
              else
                modifiers[:base_accuracy] = accuracy
              end
            end
          end
        }
      end
      
      define_method(:parse_type_mods) do |type_mods|
        return unless type_mods
        
        @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
          type_mods.each do |secondary_type, moves|
            next secondary_type if moves.include?(move.id)
          end
          next nil
        }
      end
      
      define_method(:parse_type_addons) do |type_addons|
        return unless type_addons
        
        existing_effect = @effects[:move_second_type]
        @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
          # Check existing type mods first
          result = existing_effect&.call(effectiveness, move, moveType, defType, user, target)
          return result if result
          
          # Then check type add-ons
          type_addons.each do |secondary_type, primary_types|
            next secondary_type if primary_types.include?(moveType)
          end
          next nil
        }
      end
      
      define_method(:parse_field_changes) do |field_changes, change_messages, change_conditions|
        return unless field_changes
        
        @effects[:end_of_move] = proc { |user, targets, move, numHits|
          field_changes.each do |new_field, moves|
            next unless moves.include?(move.id)
            
            # Check condition if it exists
            if change_conditions && change_conditions[new_field]
              condition = change_conditions[new_field]
              begin
                next unless eval(condition)
              rescue
                next
              end
            end
            
            # Display message if exists
            if change_messages
              change_messages.each do |msg, msg_moves|
                if msg_moves.include?(move.id)
                  @battle.pbDisplay(msg)
                  break
                end
              end
            end
            
            # Create the new field
            @battle.create_new_field(new_field, Battle::Field::DEFAULT_FIELD_DURATION)
          end
        }
      end
      
      define_method(:parse_move_effects) do |move_effects|
        return unless move_effects
        
        existing_effect = @effects[:end_of_move] || proc { |user, targets, move, numHits| }
        @effects[:end_of_move] = proc { |user, targets, move, numHits|
          existing_effect.call(user, targets, move, numHits)
          
          move_effects.each do |effect_code, moves|
            next unless moves.include?(move.id)
            begin
              eval(effect_code)
            rescue => e
              # Silent fail for eval errors
            end
          end
        }
      end
      
      define_method(:parse_type_effects) do |type_effects|
        return unless type_effects
        
        existing_effect = @effects[:end_of_move] || proc { |user, targets, move, numHits| }
        @effects[:end_of_move] = proc { |user, targets, move, numHits|
          existing_effect.call(user, targets, move, numHits)
          
          type = move.calcType
          type_effects.each do |effect_code, types|
            next unless types.include?(type)
            begin
              eval(effect_code)
            rescue => e
              # Silent fail for eval errors
            end
          end
        }
      end
      
      define_method(:parse_change_effects) do |change_effects|
        return unless change_effects
        
        existing_effect = @effects[:end_of_move] || proc { |user, targets, move, numHits| }
        @effects[:end_of_move] = proc { |user, targets, move, numHits|
          existing_effect.call(user, targets, move, numHits)
          
          change_effects.each do |effect_code, moves|
            next unless moves.include?(move.id)
            begin
              eval(effect_code)
            rescue => e
              # Silent fail for eval errors
            end
          end
        }
      end
    end
    
    # Register the field class in the Battle module
    Battle.const_set(class_name_short, field_class)
    
    # Register field data
    Battle::Field.register(field_id_lower, {
      trainer_name: [],
      environment: (data[:graphic] || []).map { |g| g.to_s.downcase.to_sym },
      map_id: [],
      edge_type: []
    })
  end
end

# Auto-parse all fields when the script loads
FieldTextParser.parse_all_fields if defined?(FIELDEFFECTS)
