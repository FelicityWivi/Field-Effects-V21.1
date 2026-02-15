# Field effect
# This is a complicated but flexible Layered Field System plugin.
# Please check the code, especially def set_default_field, def create_new_field,
# def end_of_round_field_process, def remove_field, def apply_field_effect etc.

# search "recommend", and add the new lines to the original method is recommended.

# used for event setting a default field manually, for exmple set_field(:Misty, 4)
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

  alias field_initialize initialize
  def initialize(scene, p1, p2, player, opponent) # recommend
    field_initialize(scene, p1, p2, player, opponent)
    @stacked_fields = []
    create_base_field
  end

  alias field_pbOnAllBattlersEnteringBattle pbOnAllBattlersEnteringBattle
  def pbOnAllBattlersEnteringBattle # recommend
    set_default_field
    apply_field_effect(:begin_battle)
    field_pbOnAllBattlersEnteringBattle
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
    if debugControl
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
    # used for setting a default field depending on backdrop
    ret = create_new_field(backdrop.to_s.downcase, duration, bg_change: false)
    return if ret

    return unless Battle::Field::ACTIVATE_VARIETY_FIELD_SETTING

    # used for setting trainer field, some trainer may has a specific field effect
    if trainerBattle?
      all_fields_data.each do |field, data|
        trainer_field = @opponent.map(&:name) & data[:trainer_name]
        next if trainer_field.empty?
        create_new_field(field, duration)
        return
      end
    end

    # used for setting a default field depending on environment
    all_fields_data.each do |field, data|
      next unless data[:environment].any? { |enviro| enviro.to_s.downcase == backdrop.to_s.downcase } ||
                  data[:environment].any? { |enviro| enviro.to_s.downcase == environment.to_s.downcase }
      create_new_field(field, duration, bg_change: false)
      return
    end

    # used for setting map field, every battle happens in the map will start with the field you set
    all_fields_data.each do |field, data|
      next unless data[:map_id].include?($game_map.map_id)
      create_new_field(field, duration)
      return
    end

    # used for setting a field depending on opposing types
    return unless Battle::Field::OPPOSING_ADVANTAGEOUS_TYPE_FIELD
    opposing_types = party2_able_pkmn_types.clone
    opposing_advantageous_types = trainerBattle? ? opposing_types.most_elements : opposing_types
    advantageous_fields = []
    all_fields_data.each do |field, data|
      type_fields = opposing_advantageous_types & data[:edge_type]
      next if type_fields.empty?
      advantageous_fields << field
    end
    advantageous_fields = all_fields if advantageous_fields.empty? # choose from all fields if there is no advantageous field
    create_new_field(advantageous_fields.sample, duration)
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

    return unless Object.const_defined?(field_class_name)
    new_field = Object.const_get(field_class_name).new(self, duration) # create the new field

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

=begin
  alias field_pbEORSwitch pbEORSwitch
  def pbEORSwitch(favorDraws = false) # recommend
    end_of_round_field_process # it is better to add this line in front of pbGainExp in pbEndOfRoundPhase
    field_pbEORSwitch(favorDraws)
  end
=end

  def end_of_round_field_process
    return unless has_field?

    apply_field_effect(:EOR_field_battle)
    eachBattler do |battler|
      apply_field_effect(:EOR_field_battler, battler)
      battler.pbFaint if battler.fainted?
      return if battler.owner_side_all_fainted? # end of battle
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
    field_announcement(:end)
    apply_field_effect(:end_field_battle)
    eachBattler { |battler| apply_field_effect(:end_field_battler, battler) }
  end

  def try_create_zero_duration_field?(duration)
    duration == 0
  end

  def try_create_infinite_field?(duration)
    duration == Battle::Field::INFINITE_FIELD_DURATION
  end

  def can_create_base_field?
    @stacked_fields.empty?
  end

  def try_create_base_field?(field_class_name)
    field_class_name == "Battle::Field_base"
  end

  def try_create_current_field?(field_class_name)
    field_class_name == @current_field.class.to_s
  end

  def add_field(new_field)
    @stacked_fields.push(new_field)
  end

  def add_field_duration(amount = 1)
    @current_field.add_duration(amount)
  end

  def reduce_field_duration(amount = 1)
    @current_field.reduce_duration(amount)
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
      @stacked_fields.keep_if(&:is_base?)
      #echoln("[Field remove] All fields were removed!")
    else
      @stacked_fields.delete_if(&:is_end?)
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
    if has_field? && change_bg
      @scene.set_fieldback
    else
      @scene.set_fieldback(true)
    end
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
end

class Battle::Scene
  def set_fieldback(set_environment = false)
    if set_environment
      @sprites["battle_bg"].setBitmap(@environment_battleBG)
      @sprites["base_0"].setBitmap(@environment_playerBase)
      @sprites["base_1"].setBitmap(@environment_enemyBase)
    else
      field_id = @battle.current_field.id.to_s.downcase
      return if !field_id || field_id.empty?
      root = "Graphics/Battlebacks"
      battle_bg_path = "#{root}/#{field_id}_bg.png"
      return unless FileTest.exist?(battle_bg_path)
      @sprites["battle_bg"].setBitmap(battle_bg_path)
      @sprites["base_0"].setBitmap("#{root}/#{field_id + "_base0.png"}")
      @sprites["base_1"].setBitmap("#{root}/#{field_id + "_base1.png"}")
    end
  end

=begin
  def pbCreateBackdropSprites
    case @battle.time
    when 1 then time = "eve"
    when 2 then time = "night"
    end
    # Put everything together into backdrop, bases and message bar filenames
    backdropFilename = @battle.backdrop
    baseFilename = @battle.backdrop
    baseFilename = sprintf("%s_%s", baseFilename, @battle.backdropBase) if @battle.backdropBase
    messageFilename = @battle.backdrop
    if time
      trialName = sprintf("%s_%s", backdropFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_bg", trialName))
        backdropFilename = trialName
      end
      trialName = sprintf("%s_%s", baseFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", trialName))
        baseFilename = trialName
      end
      trialName = sprintf("%s_%s", messageFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_message", trialName))
        messageFilename = trialName
      end
    end
    if !pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", baseFilename)) &&
       @battle.backdropBase
      baseFilename = @battle.backdropBase
      if time
        trialName = sprintf("%s_%s", baseFilename, time)
        if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", trialName))
          baseFilename = trialName
        end
      end
    end
    # Finalise filenames
    battleBG   = "Graphics/Battlebacks/" + backdropFilename + "_bg"
    playerBase = "Graphics/Battlebacks/" + baseFilename + "_base0"
    enemyBase  = "Graphics/Battlebacks/" + baseFilename + "_base1"
    messageBG  = "Graphics/Battlebacks/" + "battleMessage"

    # add these three lines only, it is better to add these three lines to the original method
    @environment_battleBG   = battleBG # recommend
    @environment_playerBase = playerBase
    @environment_enemyBase  = enemyBase

    # Apply graphics
    bg = pbAddSprite("battle_bg", 0, 0, battleBG, @viewport)
    bg.z = 0
    bg = pbAddSprite("battle_bg2", -Graphics.width, 0, battleBG, @viewport)
    bg.z      = 0
    bg.mirror = true
    2.times do |side|
      baseX, baseY = Battle::Scene.pbBattlerPosition(side)
      base = pbAddSprite("base_#{side}", baseX, baseY,
                         (side == 0) ? playerBase : enemyBase, @viewport)
      base.z = 1
      if base.bitmap
        base.ox = base.bitmap.width / 2
        base.oy = (side == 0) ? base.bitmap.height : base.bitmap.height / 2
      end
    end
    cmdBarBG = pbAddSprite("cmdBar_bg", 0, Graphics.height - 96, messageBG, @viewport)
    cmdBarBG.z = 180
  end
=end
end