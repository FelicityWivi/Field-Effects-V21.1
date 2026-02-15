class Battle::Field
  attr_reader :battle
  attr_reader :id, :name, :duration, :effects, :field_announcement
  attr_reader :multipliers, :strengthened_message, :weakened_message
  attr_reader :nature_power_change, :mimicry_type, :camouflage_type, :secret_power_effect, :terrain_pulse_type
  attr_reader :tailwind_duration, :floral_heal_amount
  attr_reader :shelter_type, :ability_activation
  attr_reader :creatable_field, :always_online

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

  def initialize(battle, duration)
    @battle                    = battle
    @duration                  = duration
    @effects                   = {}
    @field_announcement        = {}
    @multipliers               = {}
    @base_strengthened_message = _INTL("The field strengthened the attack")
    @base_weakened_message     = _INTL("The field weakened the attack")
    @ability_activation        = []
    @creatable_field           = []
    @always_online             = []

    @effects[:calc_damage] = proc { |user, target, numTargets, move, type, power, mults|
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
