# Field effect
# This is a complicated but flexible Layered Field System plugin.
# Please check the code, especially def set_default_field, def create_new_field,
# def end_of_round_field_process, def remove_field, def apply_field_effect etc.

# search "recommend", and add the new lines to the original method is recommended.

# used for event setting a default field manually, for example set_field(:Misty, 4)
# :misty, :Misty, "misty", "MiSty" etc. are all acceptable
# then the next battle will start with Misty field(4 turns)
# it will reset/clear automatically, so only the next battle will have the field you set
def set_field(new_field = nil, duration = Battle::Field::INFINITE_FIELD_DURATION)
  $field = [new_field, duration]
end

def default_field; $field; end
def clear_default_field; $field = nil; end

class Battle
  attr_reader :stacked_fields # all field layers
  attr_reader :current_field # the topmost field
  attr_reader :field_counters # Field counters object (for field transitions)

  alias field_initialize initialize
  def initialize(scene, p1, p2, player, opponent) # recommend
    field_initialize(scene, p1, p2, player, opponent)
    @stacked_fields = []
    @suppress_field_announcements = true  # Suppress during initialization
    
    # Create field counters object (simple inline object)
    @field_counters = Object.new
    @field_counters.instance_variable_set(:@counter, 0)
    @field_counters.instance_variable_set(:@counter2, 0)
    @field_counters.instance_variable_set(:@counter3, 0)
    @field_counters.instance_variable_set(:@backup, nil)
    
    # Define getter and setter methods
    class << @field_counters
      attr_accessor :counter, :counter2, :counter3, :backup
    end
    
    create_base_field
    @fields_initialized = false
  end

  alias field_pbStartBattle pbStartBattle
  def pbStartBattle # recommend
    # Don't set fields yet - wait for scene to be ready
    field_pbStartBattle
  end
  
  # Initialize fields after the battle scene is fully set up
  alias field_pbBattleLoop pbBattleLoop
  def pbBattleLoop
    # Set default field at the very start of the battle loop
    # At this point, all sprites are guaranteed to exist
    unless @fields_initialized
      set_default_field
      apply_field_effect(:begin_battle)
      @fields_initialized = true
      
      # Now that sprites exist, show the field announcement
      @suppress_field_announcements = false
      if has_field? && !@current_field.is_base?
        field_announcement(:start)
      end
    end
    field_pbBattleLoop
  end

  def create_base_field
    create_new_field(:Base, Battle::Field::INFINITE_FIELD_DURATION)
  end

  # the test field now is Electric, field duration is 3
  def set_test_field(test_field = :beach, duration = 3)
    create_new_field(test_field, duration)
  end

  def set_default_field
    # used for setting a test field, press Ctrl when starts a battle
    if $DEBUG && Input.press?(Input::CTRL)
      set_test_field
      return
    end

    # used for setting the manual default field
    if default_field
      create_new_field(default_field[0], default_field[1])
      clear_default_field # clear $field
      return
    end

    duration = Battle::Field::INFINITE_FIELD_DURATION
    
    # Get backdrop - in V21.1 it's a property of Battle, not Scene
    backdrop_name = backdrop if respond_to?(:backdrop)
    
    # Debug output
    if $DEBUG
      Console.echo_li("=" * 50)
      Console.echo_li("FIELD ACTIVATION DEBUG")
      Console.echo_li("Backdrop (raw): #{backdrop_name.inspect}")
      Console.echo_li("Environment: #{environment rescue 'N/A'}")
      Console.echo_li("Available fields: #{all_fields.join(', ')}")
      Console.echo_li("Field data count: #{all_fields_data.size}")
      Console.echo_li("=" * 50)
    end
    
    # Only proceed if we have a valid backdrop name
    if backdrop_name && !backdrop_name.to_s.empty?
      backdrop_sym = backdrop_name.to_s.downcase.to_sym
      
      if $DEBUG
        Console.echo_li("Backdrop (processed): #{backdrop_sym}")
      end
      
      # Try to create field directly from backdrop name
      ret = create_new_field(backdrop_sym, duration, bg_change: false)
      return if ret
    else
      Console.echo_li("WARNING: No backdrop detected! This might be normal for some battle types.") if $DEBUG
    end

    return unless Battle::Field::ACTIVATE_VARIETY_FIELD_SETTING

    # used for setting trainer field, some trainer may has a specific field effect
    if trainerBattle?
      all_fields_data.each do |field, data|
        trainer_field = opponent.map { |t| t.trainer_type } & data[:trainer_name]
        next if trainer_field.empty?
        create_new_field(field, duration)
        return
      end
    end

    # used for setting a default field depending on environment
    if backdrop_name && !backdrop_name.to_s.empty?
      backdrop_sym = backdrop_name.to_s.downcase.to_sym
      env_sym = environment.to_s.downcase.to_sym rescue nil
      
      if $DEBUG
        Console.echo_li("Checking environment match...")
        Console.echo_li("Backdrop symbol: #{backdrop_sym}")
        Console.echo_li("Environment symbol: #{env_sym}")
      end
      
      all_fields_data.each do |field, data|
        # Check if backdrop matches any environment in the field's data
        if data[:environment].include?(backdrop_sym) || (env_sym && data[:environment].include?(env_sym))
          if $DEBUG
            Console.echo_li("Field #{field} matched! Environment list: #{data[:environment].inspect}")
          end
          create_new_field(field, duration, bg_change: false)
          return
        end
      end
    end

    # used for setting map field, every battle happens in the map will start with the field you set
    all_fields_data.each do |field, data|
      next unless data[:map_id].include?($game_map&.map_id)
      create_new_field(field, duration)
      return
    end

    # used for setting a field depending on opposing types
    return unless Battle::Field::OPPOSING_ADVANTAGEOUS_TYPE_FIELD
    opposing_types = party2_able_pkmn_types.clone
    opposing_advantageous_types = trainerBattle? ? opposing_types.max_by { |t| opposing_types.count(t) } : opposing_types
    advantageous_fields = []
    all_fields_data.each do |field, data|
      type_fields = [opposing_advantageous_types].flatten & data[:edge_type]
      next if type_fields.empty?
      advantageous_fields << field
    end
    advantageous_fields = all_fields if advantageous_fields.empty? # choose from all fields if there is no advantageous field
    create_new_field(advantageous_fields.sample, duration)
  end

  # Create a field overlay (like Electric Terrain transitioning on top of Grassy Terrain)
  # Overlays stack on top of the current field without removing it
  def create_field_overlay(field_id, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    return unless field_id
    return if try_create_zero_duration_field?(duration)
    formatted_field_id = field_id.to_s.downcase.to_sym
    return unless can_create_field?(formatted_field_id)
    field_class_name = "Battle::Field_#{formatted_field_id}"
    return if try_create_base_field?(field_class_name) && !can_create_base_field? # create Base only once
 
    # already exists a field, then try to create a new field
    if has_field? && try_create_current_field?(field_class_name) # new field is the same as the current field
      return if is_infinite?
      if try_create_infinite_field?(duration)
        remove_field(remove_all: true)
        set_field_duration(Battle::Field::INFINITE_FIELD_DURATION)
        add_field(@current_field)
        pbDisplay(_INTL("The field will exist forever!")) if Battle::Field::ANNOUNCE_FIELD_DURATION_INFINITE
        #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]")
      else
        expand_duration = Battle::Field::FIELD_DURATION_EXPANDED
        if duration > expand_duration # expand field duration
          add_field_duration(expand_duration)
        else
          add_field_duration(duration)
        end
        pbDisplay(_INTL("The field has already existed!")) if Battle::Field::ANNOUNCE_FIELD_EXISTED
        pbDisplay(_INTL("The field duration expanded to {1}!", field_duration)) if Battle::Field::ANNOUNCE_FIELD_DURATION_EXPAND
      end
      return
    end
    
    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }
    
    return new_field
  end


  def can_create_field?(field_id)
    return true unless has_field?
    creatable_field = @current_field.creatable_field
    return true if creatable_field.empty?
    return creatable_field.include?(field_id)
  end

  # if you wanna some abilities/items/moves or something else to create a new field, use this method
  def create_new_field(field_id, duration = Battle::Field::DEFAULT_FIELD_DURATION, bg_change: true)
    return unless field_id
    return if try_create_zero_duration_field?(duration)
    formatted_field_id = field_id.to_s.downcase.to_sym
    field_class_name = "Battle::Field_#{formatted_field_id}"
    
    # Debug output
    if $DEBUG
      Console.echo_li("Attempting to create field: #{field_id} -> #{formatted_field_id}")
      Console.echo_li("Class name: #{field_class_name}")
      Console.echo_li("Class exists: #{Object.const_defined?(field_class_name)}")
    end
    
    return unless can_create_field?(formatted_field_id)
    return if try_create_base_field?(field_class_name) && !can_create_base_field? # create Base only once
 
    # already exists a field, then try to create a new field
    if has_field? && try_create_current_field?(field_class_name) # new field is the same as the current field
      return if is_infinite?
      if try_create_infinite_field?(duration)
        remove_field(remove_all: true)
        set_field_duration(Battle::Field::INFINITE_FIELD_DURATION)
        add_field(@current_field)
        pbDisplay(_INTL("The field will exist forever!")) if Battle::Field::ANNOUNCE_FIELD_DURATION_INFINITE
        #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]")
      else
        expand_duration = Battle::Field::FIELD_DURATION_EXPANDED
        if duration > expand_duration # expand field duration
          add_field_duration(expand_duration)
        else
          add_field_duration(duration)
        end
        pbDisplay(_INTL("The field has already existed!")) if Battle::Field::ANNOUNCE_FIELD_EXISTED
        pbDisplay(_INTL("The field duration expanded to {1}!", field_duration)) if Battle::Field::ANNOUNCE_FIELD_DURATION_EXPAND
      end
      return
    end

    unless Object.const_defined?(field_class_name)
      Console.echo_li("Field class #{field_class_name} not found!") if $DEBUG
      return
    end

    # Create the field object. Rather than rely entirely on arity inspection (which
    # can be misleading if external plugins later redefine #initialize), we simply
    # attempt to call several common argument combinations until one succeeds. This
    # mirrors the flexibility of Field_base's own constructor and ensures the field
    # creation code never crashes due to an unexpected signature.
    field_klass = Object.const_get(field_class_name)
    # If we're about to instantiate the base field, make sure its initializer is
    # forgiving. Other plugins (such as Enhanced Battle UI) may reopen
    # Battle::Field_base after our plugin loads and redefine `initialize` to take
    # no arguments, which would crash when we pass `self` below.  Patch it here
    # to guarantee the splat-taking constructor is in place.
    if field_klass == Battle::Field_base
      field_klass.class_eval do
        def initialize(*args)
          battle   = args[0]
          duration = args[1] || Battle::Field::INFINITE_FIELD_DURATION
          super(battle, duration, :base)
          @name = _INTL("Base")
        end
      end
    end

    new_field = nil
    begin
      new_field = field_klass.new(self, duration)
    rescue ArgumentError
      begin
        new_field = field_klass.new(self)
      rescue ArgumentError
        new_field = field_klass.new
      end
    end
    # It's extremely unlikely we still don't have a field; raise if so so bugs surface
    raise "Unable to instantiate field class #{field_class_name}" if new_field.nil?

    removed_field = nil
    if has_field?
      end_field
      if try_create_infinite_field?(duration)
        remove_field(remove_all: true)
      else
        removed_field = remove_field(remove_field: new_field, ignore_infinite: false) # remove the same field in field layers
      end
    end

    add_field(new_field)
    set_current_field(new_field)
    add_field_duration(removed_field.duration) if removed_field # add the removed field duration

    # Base cant trigger
    if has_field?
      set_fieldback(bg_change)
      field_announcement(:start)
      #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]")
    end

    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }

    return new_field
  end

  # Hook into the end of round phase to trigger field effects
  alias field_pbEndOfRoundPhase pbEndOfRoundPhase
  def pbEndOfRoundPhase
    end_of_round_field_process # Process field effects before other end-of-round effects
    field_pbEndOfRoundPhase
  end

  def end_of_round_field_process
    return unless has_field?
    
    if $DEBUG
      Console.echo_li("=== End of Round Field Process ===")
      Console.echo_li("Current field: #{@current_field.name}")
      Console.echo_li("Field duration: #{@current_field.duration}")
    end

    apply_field_effect(:EOR_field_battle)
    eachBattler do |battler|
      next unless battler && !battler.fainted?
      if $DEBUG
        Console.echo_li("Processing EOR effects for #{battler.pbThis}")
      end
      apply_field_effect(:EOR_field_battler, battler)
      # Do NOT call battler.pbFaint here. The base game's pbEndOfRoundPhase
      # (which runs after this method) handles fainting with proper sprite
      # sequencing. Calling pbFaint early causes sprites to become invisible
      # before leech seed and other EOR effects try to animate against them.
      return if decision != 0 # end of battle
    end

    field_duration_countdown
    remove_field

    end_field_process
  end

  def end_field_process
    if has_field?
      if top_field_unchanged?
      #  field_announcement(:continue)
      else
        end_field
        set_top_field
      end
    else
      end_field
      set_base_field
    end
  end

  def set_base_field
    set_current_field(base_field)
    set_fieldback

    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }
  end

  def set_top_field
    set_current_field(top_field)
    set_fieldback
    field_announcement(:start)
    #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]")

    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }
  end

  def end_field
    return unless has_field?
    # field_announcement(:end)  # Commented out to make field transitions smoother
    apply_field_effect(:end_field_battle)
    eachBattler { |battler| apply_field_effect(:end_field_battler, battler) }
  end

  def try_create_zero_duration_field?(duration)
    return duration == 0
  end

  def try_create_base_field?(field_class_name)
    return field_class_name == "Battle::Field_base"
  end

  def can_create_base_field?
    return @stacked_fields.empty?
  end

  def try_create_current_field?(field_class_name)
    return field_class_name == @current_field.class.name
  end

  def try_create_infinite_field?(duration)
    return duration == Battle::Field::INFINITE_FIELD_DURATION
  end

  def add_field(new_field)
    @stacked_fields << new_field
  end

  def add_field_duration(amount = 1)
    @current_field.add_duration(amount)
  end

  def set_field_duration(amount = 5)
    @current_field.set_duration(amount)
  end

  def field_duration_countdown
    @stacked_fields.each { |field| field.reduce_duration unless field.is_infinite? }
  end

  def remove_field(remove_field: nil, ignore_infinite: true, remove_all: false)
    return unless has_field?

    if remove_field
      if ignore_infinite
        return @stacked_fields.delete_at(remove_field) if remove_field.is_a?(Integer)
        return @stacked_fields.delete(remove_field)
      else
        removed_field = nil
        @stacked_fields.delete_if do |field|
          if !field.is_infinite? && field == remove_field
            removed_field = field
            true
          end
        end
        return removed_field
      end
    end

    if remove_all
      @stacked_fields.keep_if { |f| f.is_base? }
      #echoln("[Field remove] All fields were removed!")
    else
      @stacked_fields.delete_if { |f| f.is_end? }
=begin
      unless has_field?
        echoln("[Field remove] All ended fields were removed!")
      else
        echoln("[Field remove] All ended fields were removed! [#{stacked_fields_stat}]")
      end
=end
    end
  end

  def set_current_field(new_field)
    @current_field = new_field
  end

  def end_current_field # havent used
    return unless has_field?
    remove_field(-1)
    end_field_process
  end

  def set_fieldback(change_bg = true)
    return unless @scene  # Safety check
    
    if change_bg && has_field?
      # Change to field-specific background
      @scene.set_fieldback(false)
    elsif change_bg
      # Restore environment background
      @scene.set_fieldback(true)
    end
    # If change_bg is false, don't call scene method at all
  end

  def apply_field_effect(key, *args, apply_all: false)
    unless Battle::Field::PARADOX_KEYS.include?(key) # only top field will trigger paradox keys
      @stacked_fields.each do |field|
        next if field.is_on_top?
        next unless field.always_online.include?(key) || apply_all # always online keys always trigger
        field.apply_field_effect(key, *args)
      end
    end
    @current_field.apply_field_effect(key, *args)
  end

  def field_announcement(announcement_type)
    # Don't display announcements if suppressed (during initialization)
    return if @suppress_field_announcements
    
    case announcement_type
    when :start
      message = @current_field.field_announcement[:start]
      pbDisplay(message) if message && !message.empty?
      if is_infinite?
        pbDisplay(_INTL("The field will exist forever!")) if Battle::Field::ANNOUNCE_FIELD_DURATION_INFINITE
      else
        pbDisplay(_INTL("The field will last for {1} more turns!", field_duration)) if Battle::Field::ANNOUNCE_FIELD_DURATION
      end
    when :continue
      message = @current_field.field_announcement[:continue] || @current_field.field_announcement[:start]
      pbDisplay(message) if message && !message.empty?
      pbDisplay(_INTL("The field will last for {1} more turns!", field_duration)) if !is_infinite? && Battle::Field::ANNOUNCE_FIELD_DURATION
    when :end
      message = @current_field.field_announcement[:end]
      pbDisplay(message) if message && !message.empty?
    end
  end

  def all_fields
    Battle::Field.field_data.keys
  end

  def all_fields_data
    Battle::Field.field_data
  end

  def field_id
    @current_field.id
  end

  def field_name
    @current_field.name
  end

  def field_duration
    @current_field.duration
  end

  def base_field
    @stacked_fields[0]
  end

  def has_base? # havent used
    base_field&.is_base?
  end

  def top_field
    @stacked_fields[-1]
  end

  def top_field_unchanged?
    @current_field == top_field
  end

  def has_field?
    @stacked_fields.length >= 2
  end
  alias has_top_field? has_field?

  def stacked_fields_name
    @stacked_fields.map(&:name)[1..-1].join(", ")
  end

  def stacked_fields_stat
    @stacked_fields.map { |field| [field.name, field.duration] }[1..-1].join(", ")
  end

  def is_infinite?
    has_field? && @current_field.is_infinite?
  end

  # used for checking if a field is a specific field
  # you can use is_xxx? as well, for example is_electric?
  def is_field?(field_id)
    @current_field.is_field?(field_id)
  end

  def party2_able_pkmn_types
    types = []
    pbParty(1).each do |pkmn|
      next if !pkmn || pkmn.egg?
      types.concat(pkmn.types)
    end
    return types
  end
end

class Battle::Scene
  def set_fieldback(set_environment = false)
    # Safety check - return if sprites aren't initialized yet
    return unless @sprites
    
    if set_environment
      # Only restore environment if we have saved backdrops
      if @environment_battleBG
        @sprites["battle_bg"].setBitmap(@environment_battleBG)
        @sprites["base_0"].setBitmap(@environment_playerBase)
        @sprites["base_1"].setBitmap(@environment_enemyBase)
      end
    else
      field_id = @battle.current_field.id.to_s.downcase
      return if !field_id || field_id.empty?
      root = "Graphics/Battlebacks"
      battle_bg_path = "#{root}/#{field_id}_bg"
      return unless pbResolveBitmap(battle_bg_path)
      @sprites["battle_bg"].setBitmap(battle_bg_path) if @sprites["battle_bg"]
      base0_path = "#{root}/#{field_id}_base0"
      base1_path = "#{root}/#{field_id}_base1"
      @sprites["base_0"].setBitmap(base0_path) if @sprites["base_0"] && pbResolveBitmap(base0_path)
      @sprites["base_1"].setBitmap(base1_path) if @sprites["base_1"] && pbResolveBitmap(base1_path)
    end
  end

  alias field_pbCreateBackdropSprites pbCreateBackdropSprites
  def pbCreateBackdropSprites
    field_pbCreateBackdropSprites
    # Store environment backdrops for later restoration
    @environment_battleBG   = @sprites["battle_bg"].bitmap if @sprites["battle_bg"]
    @environment_playerBase = @sprites["base_0"].bitmap if @sprites["base_0"]
    @environment_enemyBase  = @sprites["base_1"].bitmap if @sprites["base_1"]
  end
end
