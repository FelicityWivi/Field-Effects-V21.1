class Battle::Field
  attr_reader :battle
  attr_reader :id, :name, :duration, :effects, :field_announcement
  attr_reader :multipliers, :strengthened_message, :weakened_message
  attr_reader :nature_power_change, :mimicry_type, :camouflage_type, :secret_power_effect, :terrain_pulse_type
  attr_reader :tailwind_duration, :floral_heal_amount
  attr_reader :shelter_type, :ability_activation
  attr_reader :creatable_field, :always_online
  attr_reader :eor_heal_fraction, :eor_heal_condition, :eor_heal_message
  attr_reader :is_overlay
  attr_reader :status_mods, :dont_change_backup
  attr_reader :seed_type, :seed_effect, :seed_duration, :seed_message, :seed_animation, :seed_stats
  attr_reader :overlay_status_mods, :overlay_type_mods
  attr_reader :overlay_fields  # List of fields that should be created as overlays instead of replacements
  attr_reader :ability_mods    # Ability modifications for this field
  attr_reader :failed_moves    # Moves that fail on this field

  DEFAULT_FIELD_DURATION  = 5
  FIELD_DURATION_EXPANDED = 3
  INFINITE_FIELD_DURATION = -1

  ACTIVATE_VARIETY_FIELD_SETTING   = false # repu doesnt use them
  OPPOSING_ADVANTAGEOUS_TYPE_FIELD = false

  ANNOUNCE_FIELD_EXISTED           = true
  ANNOUNCE_FIELD_DURATION          = false
  ANNOUNCE_FIELD_DURATION_INFINITE = false
  ANNOUNCE_FIELD_DURATION_EXPAND   = false

  BASE_KEYS = %i[set_field_battler_universal ability_activation]

  PARADOX_KEYS = %i[begin_battle set_field_battle set_field_battler set_field_battler_universal
                   nature_power_change mimicry_type camouflage_type secret_power_effect terrain_pulse_type
                   tailwind_duration floral_heal_amount
                   shelter_type ability_activation
                   end_field_battle end_field_battler]

  @@field_data = {}
  def self.register(field, data)
    field = field.to_s.downcase.to_sym
    @@field_data[field] = data
    define_method("is_#{field}?") do # define is_xxx? Field instance method
      @id == field
    end
    Battle.class_eval do # define is_xxx? Battle instance method
      define_method("is_#{field}?") do
        @current_field.public_send("is_#{field}?")
      end
    end
  end

  def self.field_data
    @@field_data
  end

  def initialize(battle, duration, field_id = :base)
    @battle                    = battle
    @duration                  = duration
    @id                        = field_id
    
    # Initialize defaults before loading data
    @effects                   = {}
    @field_announcement        = {}
    @multipliers               = {}
    @base_strengthened_message = _INTL("The field strengthened the attack")
    @base_weakened_message     = _INTL("The field weakened the attack")
    @ability_activation        = []
    @creatable_field           = []
    @always_online             = []
    @eor_heal_fraction         = nil # Fraction of HP to heal (e.g., 16 for 1/16th HP)
    @eor_heal_condition        = nil # Condition string for healing (e.g., "!battler.airborne?")
    @eor_heal_message          = nil # Message to display when healing
    @is_overlay                = false # Whether this field is an overlay on another field
    @status_mods               = [] # List of status moves boosted/modified by this field
    @dont_change_backup        = [] # Moves that don't backup field when changing
    @seed_type                 = nil # Type of seed activated on this field
    @seed_effect               = nil # Effect applied by seed
    @seed_duration             = nil # Duration of seed effect
    @seed_message              = nil # Message shown when seed is used
    @seed_animation            = nil # Animation played when seed is used
    @seed_stats                = {} # Stat changes from seed
    @overlay_status_mods       = [] # Status moves for overlay mode
    @overlay_type_mods         = {} # Type modifications for overlay mode
    @overlay_fields            = [] # Fields that should stack as overlays (not replace)
    @ability_mods              = {} # Ability modifications for this field
    @failed_moves              = {} # Moves that fail on this field
    
    # Load registered field data
    initialize_from_data(self.class.field_data[@id] || {})

    @effects[:calc_damage] = proc { |user, target, numTargets, move, type, power, mults|
      # Safety check - ensure multipliers is initialized and not nil
      return unless @multipliers && @multipliers.is_a?(Hash)
      @multipliers.each do |mult_data, calc_proc|
        mult = mult_data[1]
        next if mult == 1.0
        ret = calc_proc&.call(user, target, numTargets, move, type, power, mults)
        next unless ret
        mult_type = mult_data[0]
        mult_msg = mult_data[2]
        mults[mult_type] *= mult
        #echoln(mults)
        multiplier = (mult_type == :defense_multiplier) ? (1.0 / mult) : mult
        if mult_msg && !mult_msg.empty?
          @battle.pbDisplay(mult_msg)
        elsif multiplier > 1.0
          unless @strengthened_message_displayed
            if @strengthened_message && !@strengthened_message.empty?
              @battle.pbDisplay(@strengthened_message)
            else
              @battle.pbDisplay(_INTL("{1} on {2}!", @base_strengthened_message, target.pbThis(true)))
            end
            @strengthened_message_displayed = true
          end
        else
          unless @weakened_message_displayed
            if @weakened_message && !@weakened_message.empty?
              @battle.pbDisplay(@weakened_message)
            else
              @battle.pbDisplay(_INTL("{1} on {2}!", @base_weakened_message, target.pbThis(true)))
            end
            @weakened_message_displayed = true
          end
        end
      end
      @strengthened_message_displayed = false
      @weakened_message_displayed = false
     }

    @effects[:set_field_battler_universal] = proc { |battler| battler.pbItemHPHealCheck }

    @effects[:nature_power_change] = proc { |_user, _targets, _move| next @nature_power_change }
    @effects[:mimicry_type]        = proc { |_ability, _battler|     next @mimicry_type }
    @effects[:camouflage_type]     = proc { |_user, _targets, _move| next @camouflage_type }
    @effects[:secret_power_effect] = proc { |_user, _targets, _move| next @secret_power_effect }
    @effects[:terrain_pulse_type]  = proc { |_user, _move|           next @terrain_pulse_type }
    @effects[:tailwind_duration]   = proc { |_user, _move|           next @tailwind_duration }
    @effects[:floral_heal_amount]  = proc { |_user, _target, _move|  next @floral_heal_amount }

    @effects[:shelter_type]        = proc { |_user, _targets, _move| next @shelter_type }
    @effects[:ability_activation]  = proc { |*_args|                 next @ability_activation } # really dont know what argument will be passed

    # End of round healing effect
    @effects[:EOR_field_battler] = proc { |battler|
      # Early exits before any logging — avoids console spam on non-healing fields
      next unless @eor_heal_fraction && @eor_heal_fraction > 0
      next if battler.fainted?

      # Only log once we know this field is actually configured to heal
      if $DEBUG
        Console.echo_li("  EOR_field_battler called for #{battler.pbThis}")
        Console.echo_li("  Heal fraction: #{@eor_heal_fraction}")
        Console.echo_li("  Heal condition: #{@eor_heal_condition}")
      end

      # Check condition if one exists
      if @eor_heal_condition
        begin
          condition_str = @eor_heal_condition.dup
          condition_str.gsub!('attacker', 'battler')
          condition_str.gsub!('opponent', 'battler')
          condition_str.gsub!('isAirborne?', 'airborne?')
          condition_str.gsub!('!battler.airborne?', 'battler.grounded?')
          result = eval(condition_str)
          Console.echo_li("  Condition result: #{result}") if $DEBUG
          next unless result
        rescue => e
          Console.echo_li("  Condition eval error: #{e.message}") if $DEBUG
          # If condition fails, don't heal
          next
        end
      end

      # Heal the battler
      if battler.canHeal?
        heal_amount = (battler.totalhp / @eor_heal_fraction.to_f).round
        if heal_amount > 0
          Console.echo_li("  Healing #{battler.pbThis} for #{heal_amount} HP (#{battler.hp}/#{battler.totalhp})") if $DEBUG
          battler.pbRecoverHP(heal_amount)
          if @eor_heal_message && !@eor_heal_message.empty?
            @battle.pbDisplay(_INTL(@eor_heal_message, battler.pbThis))
          else
            @battle.pbDisplay(_INTL("{1} was healed by the field!", battler.pbThis))
          end
        end
      else
        Console.echo_li("  Cannot heal #{battler.pbThis} - canHeal? returned false") if $DEBUG
      end
    }
  end

  def initialize_from_data(data)
    data.each do |key, value|
      case key
      when :name                    then @name                    = value
      when :duration                then @duration                = value unless @duration
      when :multipliers             then @multipliers             = value
      when :strengthened_message    then @strengthened_message    = value
      when :weakened_message        then @weakened_message        = value
      when :nature_power_change     then @nature_power_change     = value
      when :mimicry_type            then @mimicry_type            = value
      when :camouflage_type         then @camouflage_type         = value
      when :secret_power_effect     then @secret_power_effect     = value
      when :terrain_pulse_type      then @terrain_pulse_type      = value
      when :tailwind_duration       then @tailwind_duration       = value
      when :floral_heal_amount      then @floral_heal_amount      = value
      when :shelter_type            then @shelter_type            = value
      when :ability_activation      then @ability_activation      = value
      when :creatable_field         then @creatable_field         = value
      when :always_online           then @always_online           = value
      when :eor_heal_fraction       then @eor_heal_fraction       = value
      when :eor_heal_condition      then @eor_heal_condition      = value
      when :eor_heal_message        then @eor_heal_message        = value
      when :is_overlay              then @is_overlay              = value
      when :status_mods             then @status_mods             = value
      when :dont_change_backup      then @dont_change_backup      = value
      when :seed_type               then @seed_type               = value
      when :seed_effect             then @seed_effect             = value
      when :seed_duration           then @seed_duration           = value
      when :seed_message            then @seed_message            = value
      when :seed_animation          then @seed_animation          = value
      when :seed_stats              then @seed_stats              = value
      when :overlay_status_mods     then @overlay_status_mods     = value
      when :overlay_type_mods       then @overlay_type_mods       = value
      when :overlay_fields          then @overlay_fields          = value
      when :ability_mods            then @ability_mods            = value
      when :failed_moves            then @failed_moves            = value
      # Base field data
      when :trainer_name            then @trainer_name            = value
      when :environment             then @environment             = value
      when :map_id                  then @map_id                  = value
      when :edge_type               then @edge_type               = value
      end
    end
  end

  def self.method_missing(method_name, *args, &block)
    echoln("Undefined class method #{method_name} is called with args: #{args.inspect}")
  end

#  def method_missing(method_name, *args, &block)
#    echoln("Undefined instance method #{method_name} is called with args: #{args.inspect}")
#  end

  def apply_field_effect(key, *args)
    return if is_base? && !Battle::Field::BASE_KEYS.include?(key)
    #echoln("[Field effect apply] #{@name}'s key #{key.upcase} applied!")
    @effects[key]&.call(*args)
  end

  def add_duration(amount = 1)
    return if is_infinite?
    @duration += amount
    #echoln("[Field duration change] #{@name}'s duration is now #{@duration}!")
  end

  def reduce_duration(amount = 1)
    return if is_infinite?
    @duration -= amount
    #echoln("[Field duration change] #{@name}'s duration is now #{@duration}!")
  end

  def set_duration(amount = 5)
    @duration = amount
    #echoln("[Field duration change] #{@name}'s duration is now #{@duration}!")
  end

  def ==(another_field)
    @id == another_field.id
  end

  def is_on_top?
    self == @battle.top_field
  end

  def is_base?
    @id == :base
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

  def is_field?(field_id)
    @id == field_id.to_s.downcase.to_sym
  end
end
