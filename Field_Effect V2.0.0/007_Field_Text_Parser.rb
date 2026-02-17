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
        
        # Parse accuracy drop on move (replaces broken typeEffects+typeCondition eval system)
        parse_accuracy_drop_on_move(data[:accuracyDropOnMove]) if data[:accuracyDropOnMove]
        
        # Parse change effects
        parse_change_effects(data[:changeEffects]) if data[:changeEffects]
        
        # Parse end-of-round healing
        parse_eor_healing(data[:eorHeal]) if data[:eorHeal]
        
        # Parse status move modifiers (for UI highlighting)
        parse_status_mods(data[:statusMods]) if data[:statusMods]
        
        # Parse don't change backup list
        parse_dont_change_backup(data[:dontChangeBackup]) if data[:dontChangeBackup]
        
        # Parse seed effects
        parse_seed_effects(data[:seed]) if data[:seed]
        
        # Parse overlay effects (Rejuvenation-style overlays)
        parse_overlay_effects(data[:overlay]) if data[:overlay]
        
        # Parse which fields should be created as overlays
        parse_overlay_fields_list(data[:overlayFields]) if data[:overlayFields]
        
        # Parse no charging moves
        if data[:noCharging]
          @no_charging_moves = data[:noCharging]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded noCharging for #{@name}: #{@no_charging_moves.inspect}")
          end
        end
        
        # Parse no charging messages
        if data[:noChargingMessages]
          @no_charging_messages = data[:noChargingMessages]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded noChargingMessages for #{@name}: #{@no_charging_messages.inspect}")
          end
        end
        
        # Parse status damage modifiers
        if data[:statusDamageMods]
          @status_damage_mods = data[:statusDamageMods]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded statusDamageMods for #{@name}: #{@status_damage_mods.inspect}")
          end
        end
        
        # Parse move stat boosts
        if data[:moveStatBoosts]
          @move_stat_boosts = data[:moveStatBoosts]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded moveStatBoosts for #{@name}: #{@move_stat_boosts.inspect}")
          end
        end
        
        # Parse blocked statuses
        if data[:blockedStatuses]
          @blocked_statuses = data[:blockedStatuses]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded blockedStatuses for #{@name}: #{@blocked_statuses.inspect}")
          end
        end
        
        # Parse blocked weather
        if data[:blockedWeather]
          @blocked_weather = data[:blockedWeather]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded blockedWeather for #{@name}: #{@blocked_weather.inspect}")
          end
        end
        
        # Parse health changes
        if data[:healthChanges]
          @health_changes = data[:healthChanges]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded healthChanges for #{@name}: #{@health_changes.inspect}")
          end
        end
        
        # Parse ability stat boosts
        if data[:abilityStatBoosts]
          @ability_stat_boosts = data[:abilityStatBoosts]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded abilityStatBoosts for #{@name}: #{@ability_stat_boosts.inspect}")
          end
        end
        
        # Parse ability form changes
        if data[:abilityFormChanges]
          @ability_form_changes = data[:abilityFormChanges]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded abilityFormChanges for #{@name}: #{@ability_form_changes.inspect}")
          end
        end
        
        # Parse move stat stage modifiers
        if data[:moveStatStageMods]
          @move_stat_stage_mods = data[:moveStatStageMods]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded moveStatStageMods for #{@name}: #{@move_stat_stage_mods.inspect}")
          end
        end
        
        # Parse ability activation
        if data[:abilityActivate]
          # Accepts either an array [:BLAZE, :FLAREBOOST] or a hash with config
          raw = data[:abilityActivate]
          @ability_activated = if raw.is_a?(Array)
            raw.each_with_object({}) { |ability, h| h[ability] = {} }
          elsif raw.is_a?(Hash)
            raw
          else
            {}
          end
          if $DEBUG
            Console.echo_li("[PARSER] Loaded abilityActivate for #{@name}: #{@ability_activated.keys.inspect}")
          end
        end
        
        # Parse abilities that ignore accuracy/evasion changes
        if data[:ignoreAccEvaChanges]
          @ignore_acc_eva_changes = Array(data[:ignoreAccEvaChanges])
          if $DEBUG
            Console.echo_li("[PARSER] Loaded ignoreAccEvaChanges for #{@name}: #{@ignore_acc_eva_changes.inspect}")
          end
        end
        
        # Parse status immunity by type/ability
        if data[:statusImmunity]
          @status_immunity = data[:statusImmunity]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded statusImmunity for #{@name}: #{@status_immunity.inspect}")
          end
        end
        
        # Parse weather duration extensions
        if data[:weatherDuration]
          @weather_duration = data[:weatherDuration]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded weatherDuration for #{@name}: #{@weather_duration.inspect}")
          end
        end
        
        # Parse item effect modifications
        if data[:itemEffectMods]
          @item_effect_mods = data[:itemEffectMods]
          if $DEBUG
            Console.echo_li("[PARSER] Loaded itemEffectMods for #{@name}: #{@item_effect_mods.inspect}")
          end
        end
        
        # Register no_charging field effect if we have no charging moves
        if @no_charging_moves && !@no_charging_moves.empty?
          register_no_charging_effect
        end
        
        # Register move stat boosts field effect
        if @move_stat_boosts && !@move_stat_boosts.empty?
          register_move_stat_boosts
        end
        
        # Register blocked status cure effect
        if @blocked_statuses && !@blocked_statuses.empty?
          register_blocked_status_cure
        end
        
        # Register blocked weather effect
        if @blocked_weather && !@blocked_weather.empty?
          register_blocked_weather
        end
        
        # Register health changes effect
        if @health_changes && !@health_changes.empty?
          register_health_changes
        end
        
        # Register ability stat boosts effect (must be near LAST to chain properly)
        if @ability_stat_boosts && !@ability_stat_boosts.empty?
          register_ability_stat_boosts
        end
        
        # Register ability form changes effect (must be LAST to chain properly)
        if @ability_form_changes && !@ability_form_changes.empty?
          register_ability_form_changes
        end
        
        # Register ability activation
        if @ability_activated && !@ability_activated.empty?
          register_ability_activation
        end
        
        # Register status immunity
        if @status_immunity && !@status_immunity.empty?
          register_status_immunity
        end
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
            
            # Check if this should be created as an overlay
            if @overlay_fields && @overlay_fields.include?(new_field)
              # Create as overlay (stacks on current field)
              @battle.create_field_overlay(new_field, Battle::Field::DEFAULT_FIELD_DURATION)
            else
              # Create as replacement (normal field transition)
              @battle.create_new_field(new_field, Battle::Field::DEFAULT_FIELD_DURATION)
            end
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
      
      define_method(:parse_accuracy_drop_on_move) do |config|
        # config: { message:, moves: [:MOVE,...], types: { :TYPE => { special_only: bool } } }
        return unless config
        
        trigger_moves   = Array(config[:moves])
        trigger_types   = config[:types] || {}
        drop_message    = config[:message]
        
        existing_eom = @effects[:end_of_move] || proc { |user, targets, move, numHits| }
        
        @effects[:end_of_move] = proc { |user, targets, move, numHits|
          existing_eom.call(user, targets, move, numHits)
          
          triggered = false
          
          # Check specific moves
          triggered = true if trigger_moves.include?(move.id)
          
          # Check type conditions
          unless triggered
            move_type = move.calcType
            if trigger_types.key?(move_type)
              opts = trigger_types[move_type]
              if opts[:special_only]
                triggered = move.specialMove?
              else
                triggered = true
              end
            end
          end
          
          next unless triggered
          
          # Collect all battlers that can have accuracy lowered
          all_battlers = ([user] + targets).flatten.compact.uniq
          lowering = all_battlers.select { |b| b.pbCanLowerStatStage?(:ACCURACY, user, move) }
          next if lowering.empty?
          
          @battle.pbDisplay(drop_message) if drop_message
          lowering.each { |b| b.pbLowerStatStage(:ACCURACY, 1, user) }
          
          if $DEBUG
            Console.echo_li("[ACCURACY DROP] #{move.id} (#{move.calcType}) triggered on #{@name}")
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
      
      define_method(:parse_eor_healing) do |eor_heal|
        return unless eor_heal
        
        # eorHeal format: { fraction: 16, condition: "!battler.airborne?", message: "{1} was healed!" }
        @eor_heal_fraction = eor_heal[:fraction] || eor_heal[:hp_fraction] || 16
        @eor_heal_condition = eor_heal[:condition]
        @eor_heal_message = eor_heal[:message]
      end
      
      define_method(:parse_status_mods) do |status_mods|
        return unless status_mods
        
        # Store status mods for UI highlighting and potential future use
        @status_mods = status_mods.is_a?(Array) ? status_mods : []
        
        # Could be used for move highlighting in the UI
        # Format: array of move symbols that are boosted/modified on this field
      end
      
      define_method(:parse_dont_change_backup) do |dont_change_backup|
        return unless dont_change_backup
        
        # Store moves that shouldn't backup the field when changing
        @dont_change_backup = dont_change_backup.is_a?(Array) ? dont_change_backup : []
        
        # This affects field change behavior - these moves create new fields without storing backup
        # Implementation would need to be added to field change logic if needed
      end
      
      define_method(:parse_seed_effects) do |seed_data|
        return unless seed_data && seed_data.is_a?(Hash)
        
        # Store seed configuration
        @seed_type = seed_data[:seedtype]
        @seed_effect = seed_data[:effect]
        @seed_duration = seed_data[:duration]
        @seed_message = seed_data[:message]
        @seed_animation = seed_data[:animation]
        @seed_stats = seed_data[:stats] || {}
        
        # Create effect for seed activation
        if @seed_type
          @effects[:on_seed_use] = proc { |battler, item|
            next unless item == @seed_type
            
            # Apply stat changes
            if @seed_stats && !@seed_stats.empty?
              @seed_stats.each do |stat, amount|
                battler.pbRaiseStatStage(stat, amount, battler)
              end
            end
            
            # Apply special effect
            if @seed_effect
              if @seed_duration == true
                battler.effects[@seed_effect] = -1  # Permanent effect
              elsif @seed_duration.is_a?(Integer)
                battler.effects[@seed_effect] = @seed_duration
              end
            end
            
            # Show message
            if @seed_message && !@seed_message.empty?
              @battle.pbDisplay(_INTL(@seed_message, battler.pbThis))
            end
            
            # Play animation
            if @seed_animation
              @battle.pbAnimation(@seed_animation, battler, battler)
            end
          }
        end
      end
      
      define_method(:parse_overlay_effects) do |overlay_data|
        return unless overlay_data && overlay_data.is_a?(Hash)
        
        # Parse overlay-specific damage mods (Rejuvenation feature)
        if overlay_data[:damageMods] && !overlay_data[:damageMods].empty?
          parse_overlay_damage_mods(overlay_data[:damageMods], overlay_data[:moveMessages])
        end
        
        # Parse overlay-specific type boosts
        if overlay_data[:typeBoosts] && !overlay_data[:typeBoosts].empty?
          parse_overlay_type_boosts(overlay_data[:typeBoosts], overlay_data[:typeMessages], overlay_data[:typeCondition])
        end
        
        # Parse overlay-specific type mods
        if overlay_data[:typeMods] && !overlay_data[:typeMods].empty?
          parse_overlay_type_mods(overlay_data[:typeMods])
        end
        
        # Store overlay status mods
        if overlay_data[:statusMods]
          @overlay_status_mods = overlay_data[:statusMods].is_a?(Array) ? overlay_data[:statusMods] : []
        end
      end
      
      define_method(:parse_overlay_damage_mods) do |damage_mods, move_messages|
        # Similar to regular damage mods but marked as overlay effects
        damage_mods.each do |multiplier, moves|
          next if moves.nil? || moves.empty?
          
          message = nil
          if move_messages
            move_messages.each do |msg, msg_moves|
              if (msg_moves & moves).any?
                message = msg
                break
              end
            end
          end
          
          mult_type = multiplier == 0 ? nil : :power_multiplier
          next unless mult_type
          
          # Mark these as overlay multipliers by adding metadata
          @multipliers[[mult_type, multiplier, message, :overlay]] = proc { |user, target, numTargets, move, type, power, mults|
            # Only apply if this field is active as an overlay
            next true if moves.include?(move.id)
          }
        end
      end
      
      define_method(:parse_overlay_type_boosts) do |type_boosts, type_messages, type_conditions|
        type_boosts.each do |multiplier, types|
          next if types.nil? || types.empty?
          
          message = nil
          if type_messages
            type_messages.each do |msg, msg_types|
              if (msg_types & types).any?
                message = msg
                break
              end
            end
          end
          
          # Mark as overlay multiplier
          @multipliers[[:power_multiplier, multiplier, message, :overlay]] = proc { |user, target, numTargets, move, type, power, mults|
            next false unless types.include?(type)
            
            if type_conditions && type_conditions[type]
              condition = type_conditions[type]
              begin
                condition_str = condition.dup
                condition_str.gsub!('attacker', 'user')
                condition_str.gsub!('opponent', 'target')
                condition_str.gsub!('self', 'move')
                condition_str.gsub!('isAirborne?', 'airborne?')
                condition_str.gsub!('!user.airborne?', 'user.grounded?')
                condition_str.gsub!('!target.airborne?', 'target.grounded?')
                
                result = eval(condition_str)
                next result
              rescue => e
                next true
              end
            end
            
            next true
          }
        end
      end
      
      define_method(:parse_overlay_type_mods) do |type_mods|
        # Store overlay type mods separately so they can be checked when field is an overlay
        @overlay_type_mods = type_mods
        
        # These would need special handling in the move_second_type effect
        # to check if the field is currently active as an overlay
      end
      
      define_method(:parse_overlay_fields_list) do |overlay_fields_list|
        return unless overlay_fields_list
        
        # Store list of fields that should be created as overlays instead of replacements
        @overlay_fields = overlay_fields_list.is_a?(Array) ? overlay_fields_list : []
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
