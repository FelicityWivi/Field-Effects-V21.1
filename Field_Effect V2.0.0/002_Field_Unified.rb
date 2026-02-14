#===============================================================================
# Field System - Compatible with Rejuvenation FIELDEFFECTS Structure
#===============================================================================

# Ensure FIELDEFFECTS constant exists
if !defined?(FIELDEFFECTS)
  FIELDEFFECTS = {}
  puts "Warning: FIELDEFFECTS not loaded. Please ensure FIELDEFFECTS.rb loads before 002_Field_Unified.rb"
end

class Battle::Field
  attr_reader :battle
  attr_reader :id, :name, :duration, :data
  attr_reader :field_announcement
  attr_accessor :counter  # For field change conditions

  DEFAULT_FIELD_DURATION  = 5
  FIELD_DURATION_EXPANDED = 3
  INFINITE_FIELD_DURATION = -1

  ACTIVATE_VARIETY_FIELD_SETTING   = false
  OPPOSING_ADVANTAGEOUS_TYPE_FIELD = false

  ANNOUNCE_FIELD_EXISTED           = true
  ANNOUNCE_FIELD_DURATION          = false
  ANNOUNCE_FIELD_DURATION_INFINITE = false
  ANNOUNCE_FIELD_DURATION_EXPAND   = false

  def initialize(battle, field_id = :INDOOR, duration = nil)
    @battle = battle
    @id = field_id.to_s.upcase.to_sym
    @counter = 0  # Initialize counter for field change conditions
    
    # Get data from FIELDEFFECTS hash
    @data = FIELDEFFECTS[@id]
    raise "Field #{@id} not found in FIELDEFFECTS" if !@data
    
    @name = @data[:name] || ""
    @duration = duration || DEFAULT_FIELD_DURATION
    
    # Set up field announcement messages
    messages = @data[:fieldMessage] || ["", "", ""]
    @field_announcement = {
      :start    => messages[0] || "",
      :continue => messages[1] || "",
      :end      => messages[2] || ""
    }
  end

  #=============================================================================
  # Field Identification
  #=============================================================================

  def is_field?(field_id)
    @id == field_id.to_s.upcase.to_sym
  end

  # Dynamic method to check field type (e.g., is_beach?)
  def method_missing(method_name, *args, &block)
    if method_name.to_s.start_with?("is_") && method_name.to_s.end_with?("?")
      field_check = method_name.to_s.gsub("is_", "").gsub("?", "").upcase.to_sym
      return @id == field_check
    end
    super
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.start_with?("is_") && method_name.to_s.end_with?("?") || super
  end

  def is_base?
    @id == :INDOOR
  end

  #=============================================================================
  # Field Data Accessors (Rejuvenation-compatible)
  #=============================================================================
  
  def nature_power_change
    @data[:naturePower]
  end

  def mimicry_type
    @data[:mimicry]
  end

  def camouflage_type
    @data[:mimicry]  # Rejuvenation uses same as mimicry
  end

  def secret_power_effect
    # Convert move name to effect number if needed
    @data[:secretPower]
  end

  def terrain_pulse_type
    @data[:mimicry]  # Use mimicry type
  end

  def shelter_type
    @data[:mimicry]  # Use mimicry type
  end

  def ability_activation
    []  # Rejuvenation doesn't use this field
  end

  def creatable_field
    []  # Rejuvenation doesn't use this field
  end

  def always_online
    []  # Rejuvenation doesn't use this field
  end

  def tailwind_duration
    0  # Rejuvenation doesn't modify tailwind duration
  end

  def floral_heal_amount
    nil  # Use default
  end

  #=============================================================================
  # Field Effect Application
  #=============================================================================

  def apply_field_effect(key, *args)
    case key
    when :calc_damage
      apply_damage_calc(*args)
    when :accuracy_modify
      apply_accuracy_mods(*args)
    when :base_type_change
      apply_base_type_change(*args)
    when :move_second_type
      apply_secondary_type(*args)
    when :change_effectiveness
      return apply_effectiveness_change(*args)
    when :end_of_move_universal, :end_of_move
      apply_move_effects(*args)
    when :EOR_field_battler
      apply_end_of_round_battler(*args)
    when :switch_in
      apply_switch_in(*args)
    when :no_charging
      return apply_no_charging(*args)
    when :set_field_battler_universal
      battler = args[0]
      battler.pbItemHPHealCheck
    when :nature_power_change
      return nature_power_change
    when :mimicry_type
      return mimicry_type
    when :camouflage_type
      return camouflage_type
    when :secret_power_effect
      return secret_power_effect
    when :terrain_pulse_type
      return terrain_pulse_type
    when :tailwind_duration
      return tailwind_duration
    when :floral_heal_amount
      return floral_heal_amount
    when :shelter_type
      return shelter_type
    when :ability_activation
      return ability_activation
    end
  end

  #=============================================================================
  # Damage Calculation (Rejuvenation-compatible)
  #=============================================================================

  def apply_damage_calc(user, target, numTargets, move, type, power, mults)
    return if !@data[:damageMods] && !@data[:typeBoosts]
    
    attacker = user
    opponent = target
    
    # Apply move-specific damage modifiers
    if @data[:damageMods]
      @data[:damageMods].each do |multiplier, moves|
        next if multiplier == 1.0
        
        if moves.include?(move.id)
          # Check if move fails (multiplier of 0)
          if multiplier == 0
            mults[:base_damage_multiplier] = 0
          else
            mults[:power_multiplier] *= multiplier
          end
          
          # Show custom message if available
          if @data[:moveMessages]
            @data[:moveMessages].each do |msg, move_list|
              if move_list.include?(move.id)
                @battle.pbDisplay(msg)
                break
              end
            end
          end
          break
        end
      end
    end
    
    # Apply type-based damage boosts
    if @data[:typeBoosts]
      @data[:typeBoosts].each do |multiplier, types|
        next if multiplier == 1.0
        next unless types.include?(type)
        
        # Check type condition if it exists
        if @data[:typeCondition] && @data[:typeCondition][type]
          condition = @data[:typeCondition][type]
          begin
            next unless eval(condition)
          rescue
            # If condition fails to eval, skip this boost
            next
          end
        end
        
        mults[:power_multiplier] *= multiplier
        
        # Show custom message if available
        if @data[:typeMessages]
          @data[:typeMessages].each do |msg, type_list|
            if type_list.include?(type)
              @battle.pbDisplay(msg)
              break
            end
          end
        end
        break
      end
    end
  end

  #=============================================================================
  # Accuracy Modification (Rejuvenation-compatible)
  #=============================================================================

  def apply_accuracy_mods(user, target, move, modifiers, type)
    return unless @data[:accuracyMods]
    
    @data[:accuracyMods].each do |accuracy, moves|
      if moves.include?(move.id)
        if accuracy == 0
          modifiers[:base_accuracy] = 0 # Always hit
        else
          modifiers[:base_accuracy] = accuracy
        end
        break
      end
    end
  end

  #=============================================================================
  # Type Modification (Rejuvenation-compatible)
  #=============================================================================

  def apply_base_type_change(user, move, type)
    return nil unless @data[:typeMods]
    
    # Check if move should have its base type changed
    @data[:typeMods].each do |new_type, moves|
      return new_type if moves.include?(move.id)
    end
    
    return nil
  end

  def apply_secondary_type(effectiveness, move, moveType, defType, user, target)
    return nil unless @data[:typeAddOns]
    
    # Check if move's type should have a secondary type added
    @data[:typeAddOns].each do |second_type, type_list|
      return second_type if type_list.include?(moveType)
    end
    
    return nil
  end

  #=============================================================================
  # Effectiveness Changes (Custom fields)
  #=============================================================================

  def apply_effectiveness_change(effectiveness, move, moveType, defType, user, target)
    # ENCHANTEDFOREST - Fairy super-effective against Steel
    if @id == :ENCHANTEDFOREST
      if user.pbHasType?(:FAIRY) && target.pbHasType?(:STEEL)
        return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
      # Steel super-effective against Dragon
      if user.pbHasType?(:STEEL) && target.pbHasType?(:DRAGON)
        return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
      # Fairy deals neutral to Dark
      if user.pbHasType?(:FAIRY) && target.pbHasType?(:DARK)
        return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
      # Dark deals neutral to Fairy
      if user.pbHasType?(:DARK) && target.pbHasType?(:FAIRY)
        return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
    end
    
    return nil
  end

  #=============================================================================
  # Move Effects (Rejuvenation-compatible)
  #=============================================================================

  def apply_move_effects(user, targets, move, numHits)
    attacker = user
    
    # Execute moveEffects for specific moves
    if @data[:moveEffects]
      @data[:moveEffects].each do |effect_code, moves|
        if moves.include?(move.id)
          begin
            eval(effect_code)
          rescue => e
            # Silently fail if effect code has errors
          end
        end
      end
    end
    
    # Execute typeEffects for move type
    if @data[:typeEffects]
      move_type = move.calcType
      @data[:typeEffects].each do |effect_code, types|
        if types.include?(move_type)
          begin
            eval(effect_code)
          rescue => e
            # Silently fail if effect code has errors
          end
        end
      end
    end
    
    # Check for field changes
    check_field_changes(user, targets, move, numHits)
  end

  #=============================================================================
  # Field Changes (Rejuvenation-compatible)
  #=============================================================================

  def check_field_changes(user, targets, move, numHits)
    return unless @data[:fieldChange]
    
    @data[:fieldChange].each do |new_field, moves|
      if moves.include?(move.id)
        # Check change condition if it exists
        if @data[:changeCondition] && @data[:changeCondition][new_field]
          condition = @data[:changeCondition][new_field]
          begin
            # Handle special conditions
            if condition == "suncheck"
              next unless @battle.pbWeather == :Sun
            else
              next unless eval(condition)
            end
          rescue
            next
          end
        end
        
        # Execute change effects if they exist
        if @data[:changeEffects] && @data[:changeEffects][move.id]
          begin
            eval(@data[:changeEffects][move.id])
          rescue
            # Silently fail
          end
        end
        
        # Show change message
        if @data[:changeMessage]
          @data[:changeMessage].each do |msg, move_list|
            if move_list.include?(move.id)
              @battle.pbDisplay(msg)
              break
            end
          end
        end
        
        # Change the field
        duration = INFINITE_FIELD_DURATION
        @battle.create_new_field(new_field, duration)
        break
      end
    end
  end

  #=============================================================================
  # End of Round Effects (Custom fields)
  #=============================================================================

  def apply_end_of_round_battler(battler)
    attacker = battler
    opponent = battler
    
    # ENCHANTEDFOREST - Heal Grass/Poison types, damage sleeping Pokemon
    if @id == :ENCHANTEDFOREST
      if battler.grounded?
        if (battler.pbHasType?(:GRASS) || battler.pbHasType?(:POISON)) && battler.canHeal?
          battler.pbRecoverHP(battler.totalhp / 16)
          @battle.pbDisplay(_INTL("{1}'s HP was restored by the enchanted forest!", battler.pbThis))
        end
        
        if battler.status == :SLEEP
          battler.pbReduceHP(battler.totalhp / 16)
          @battle.pbDisplay(_INTL("The dream is corrupted by the evil in the woods!"))
        end
      end
    end
    
    # POISONLIBRARY - Damage Psychic types
    if @id == :POISONLIBRARY
      if battler.grounded? && battler.pbHasType?(:PSYCHIC)
        battler.pbReduceHP(battler.totalhp / 8)
        @battle.pbDisplay(_INTL("{1} was damaged by the toxic knowledge.", battler.pbThis))
      end
    end
  end

  #=============================================================================
  # Switch-In Effects (Custom fields)
  #=============================================================================

  def apply_switch_in(battler)
    # SAHARA - Lower Defense for Blaze/Overgrow/Torrent
    if @id == :SAHARA
      if battler.hasActiveAbility?([:BLAZE, :OVERGROW, :TORRENT]) && battler.pbCanLowerStatStage?(:DEFENSE)
        @battle.pbDisplay(_INTL("{1} lost power from the {2}!", battler.pbThis, @name))
        battler.pbLowerStatStage(:DEFENSE, 1, nil)
      end
    end
  end

  #=============================================================================
  # No Charging Effects (Custom fields)
  #=============================================================================

  def apply_no_charging(user, move)
    # SAHARA - Skip charging for Solar Beam/Blade
    if @id == :SAHARA
      return true if [:SOLARBEAM, :SOLARBLADE].include?(move.id) && user.grounded?
    end
    return false
  end

  #=============================================================================
  # Seed Effects (Rejuvenation-specific)
  #=============================================================================

  def seed_data
    @data[:seed]
  end

  def overlay_data
    @data[:overlay]
  end

  #=============================================================================
  # Field Duration Management
  #=============================================================================

  def add_duration(amount = 1)
    return if is_infinite?
    @duration += amount
  end

  def reduce_duration(amount = 1)
    return if is_infinite?
    @duration -= amount
  end

  def set_duration(amount = 5)
    @duration = amount
  end

  def ==(another_field)
    @id == another_field.id
  end

  def is_on_top?
    self == @battle.top_field
  end

  def is_default_duration?
    @duration == DEFAULT_FIELD_DURATION
  end

  def is_infinite?
    @duration == INFINITE_FIELD_DURATION
  end

  def is_end?
    @duration == 0
  end

  #=============================================================================
  # Class Methods
  #=============================================================================

  def self.register(field_id, registration_data)
    # This method is kept for backwards compatibility
    field_id = field_id.to_s.upcase.to_sym
    
    # Create dynamic is_xxx? method on Battle class
    Battle.class_eval do
      define_method("is_#{field_id.to_s.downcase}?") do
        @current_field && @current_field.is_field?(field_id)
      end
    end
  end

  def self.get_field_data(field_id)
    field_id = field_id.to_s.upcase.to_sym
    FIELDEFFECTS[field_id]
  end

  def self.all_fields
    FIELDEFFECTS.keys
  end

  # Get field ID from battle environment/backdrop
  # Usage: Battle::Field.field_from_environment(:Cave) => :CAVE
  def self.field_from_environment(environment)
    environment_str = environment.to_s.gsub(/[^A-Za-z0-9]/, '').upcase
    
    # Check each field's graphic setting to find a match
    FIELDEFFECTS.each do |field_id, field_data|
      graphics = field_data[:graphic] || []
      graphics.each do |graphic_name|
        graphic_str = graphic_name.to_s.gsub(/[^A-Za-z0-9]/, '').upcase
        return field_id if graphic_str == environment_str
      end
    end
    
    # Also try direct field ID match
    field_id = environment_str.to_sym
    return field_id if FIELDEFFECTS.key?(field_id)
    
    # Default to INDOOR if no match
    return :INDOOR
  end
end

#===============================================================================
# Auto-register all fields for Battle class methods
#===============================================================================
Battle.class_eval do
  FIELDEFFECTS.keys.each do |field_id|
    define_method("is_#{field_id.to_s.downcase}?") do
      @current_field && @current_field.is_field?(field_id)
    end
  end
end
