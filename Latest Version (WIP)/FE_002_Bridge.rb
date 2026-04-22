#===============================================================================
# Field Effects Plugin — Framework Bridge
# File: FE_002_Bridge.rb
#
# LOAD-ORDER SAFE DESIGN:
# Battle::Field is defined in the framework (002_Field.rb). If our plugin
# folder sorts before the framework folder alphabetically, Battle::Field won't
# exist at parse time. Every reference to Battle::Field is therefore deferred
# inside methods (called at runtime) rather than at the class/module body level.
#
# The class Battle::Field_RejuvData is created lazily the first time
# FieldFactory.create needs it, via FE_RejuvDataLoader.ensure!
#===============================================================================

#===============================================================================
# ALL INSTANCE METHODS FOR Battle::Field_RejuvData
# Defined in a plain module so this file can be parsed without Battle::Field.
#===============================================================================
module FE_RejuvDataMethods
  attr_reader :field_data

  def initialize(battle, field_id, duration = nil, *args)
    super(battle)
    sym  = field_id.to_sym
    data = FIELDEFFECTS[sym] || {}
    @id                  = sym
    @name                = _INTL(data[:name] || sym.to_s)
    @duration            = duration || (self.class.const_defined?(:DEFAULT_FIELD_DURATION) ?
                             self.class::DEFAULT_FIELD_DURATION : 0)
    @fieldback           = Array(data[:graphic]).first.to_s
    @nature_power_change = data[:naturePower]
    @field_data          = data

    msgs = Array(data[:fieldMessage])
    @field_announcement  = [msgs.first.to_s, msgs.first.to_s, ""]

    @move_msg_map = build_reverse_map(data[:moveMessages] || {})
    @type_msg_map = build_reverse_map(data[:typeMessages] || {})

    register_calc_damage(data)
    register_accuracy(data)
    register_type_procs(data)
    register_no_charging(data)
    register_eor(data)
    register_after_move(data)
    register_set_field(data)
    register_nature_secret(data)
  end

  private

  def build_reverse_map(hash)
    map = {}
    hash.each { |k, vs| Array(vs).each { |v| map[v] = k } }
    map
  end

  def register_calc_damage(data)
    (data[:damageMods] || {}).each do |mult, moves|
      m = mult.to_f
      Array(moves).each do |move_id|
        msg  = @move_msg_map[move_id]
        ekey = [:move, move_id, :power_multiplier, m, msg]
        @multipliers[ekey] = proc { |user, target, _n, move, _t, _p, _mults, _ai|
          move.id == move_id
        }
      end
    end

    (data[:typeBoosts] || {}).each do |mult, types|
      m = mult.to_f
      Array(types).each do |type_id|
        msg  = @type_msg_map[type_id]
        cond = (data[:typeCondition] || {})[type_id]
        ekey = [:type, type_id, :power_multiplier, m, msg]
        @multipliers[ekey] = proc { |user, target, _n, move, type, _p, _mults, _ai|
          next false unless type == type_id
          next evaluate_condition(cond, user) if cond && !cond.empty?
          true
        }
      end
    end

    ((data[:overlay] || {})[:typeBoosts] || {}).each do |mult, types|
      m = mult.to_f
      Array(types).each do |type_id|
        ekey = [:overlay_type, type_id, :power_multiplier, m, nil]
        @multipliers[ekey] = proc { |user, target, _n, move, type, _p, _mults, _ai|
          next false unless type == type_id
          next (@battle.field.terrain != :None rescue false)
        }
      end
    end
  end

  def register_accuracy(data)
    acc_mods = data[:accuracyMods] || {}
    return if acc_mods.empty?
    @effects[:accuracy_modify] = proc { |move|
      acc_mods.each { |acc, moves| next acc if Array(moves).include?(move.id) }
      nil
    }
  end

  def register_type_procs(data)
    type_mods = data[:typeMods] || {}
    unless type_mods.empty?
      @effects[:base_type_change] = proc { |move|
        type_mods.each { |type_id, moves| next type_id if Array(moves).include?(move.id) }
        nil
      }
    end

    type_adds = data[:typeAddOns] || {}
    unless type_adds.empty?
      @effects[:base_type_add] = proc { |move|
        type_adds.each { |type_id, moves| next type_id if Array(moves).include?(move.id) }
        nil
      }
    end
  end

  def register_no_charging(data)
    no_charge = Array(data[:noCharging])
    no_msgs   = data[:noChargingMessages] || {}
    return if no_charge.empty?
    @effects[:no_charging] = proc { |user, move|
      next false unless no_charge.include?(move.id)
      msg = no_msgs[move.id]
      @battle.pbDisplay(_INTL(msg)) if msg && !msg.empty?
      true
    }
  end

  def register_eor(data)
    fid = @id
    @effects[:EOR_field_battler] = proc { |battler|
      FieldEffect::EOR.process_battler(battler, @battle, fid)
    }
    @effects[:EOR_field_battle] = proc {
      FieldEffect::EOR.process_battle(@battle, fid)
    }
  end

  def register_after_move(data)
    move_effects   = data[:moveEffects]     || {}
    field_change   = data[:fieldChange]     || {}
    cond_map       = data[:changeCondition] || {}
    msg_map        = data[:changeMessage]   || {}
    change_effects = data[:changeEffects]   || {}
    return if move_effects.empty? && field_change.empty?

    @effects[:after_move] = proc { |user, move, targets|
      mid = move.id

      move_effects.each do |code, moves|
        next unless Array(moves).include?(mid)
        begin; @battle.instance_eval(code)
        rescue => e; echoln("[FE moveEffect] #{@id}/#{mid}: #{e.message}"); end
      end

      field_change.each do |new_field, moves|
        next unless Array(moves).include?(mid)
        cond = cond_map[new_field]
        if cond && !cond.empty?
          begin
            next unless @battle.instance_eval(cond)
          rescue => e
            echoln("[FE changeCondition] #{@id}->#{new_field}: #{e.message}")
            next
          end
        end
        msg = build_reverse_map(msg_map)[mid]
        @battle.pbDisplay(_INTL(msg)) if msg && !msg.empty?
        (change_effects[mid] || []).each do |code|
          begin; @battle.instance_eval(code); rescue; end
        end
        @battle.fe_transform_bonus_active = true
        @battle.create_new_field(new_field)
        break
      end
    }
  end

  def register_set_field(data)
    seed = data[:seed] || {}
    unless seed.empty?
      @effects[:set_field_battler] = proc { |battler|
        FieldEffect::Seeds.apply(battler, @battle, seed)
      }
    end
    @effects[:set_field_battler_universal] = proc { |battler|
      battler.pbItemHPHealCheck
    }
  end

  def register_nature_secret(data)
    @effects[:nature_power_change] = proc { |_move| @nature_power_change }
    @effects[:tailwind_duration]   = proc { |_battler| nil }
  end

  def evaluate_condition(cond, user)
    return true if cond.nil? || cond.empty?
    case cond
    when "user.grounded?", "grounded"     then return user&.grounded? || false
    when "!user.grounded?", "airborne"    then return !(user&.grounded? || false)
    when "!self.contactMove?"             then return true
    else
      begin; user.instance_eval(cond)
      rescue; true; end
    end
  end
end

#===============================================================================
# LAZY CLASS CREATOR
# Battle::Field_RejuvData is created on first use, by which time Battle::Field
# is guaranteed to exist (all plugins have loaded before any battle starts).
#===============================================================================
module FE_RejuvDataLoader
  def self.ensure!
    return if defined?(Battle::Field_RejuvData) && Battle::Field_RejuvData
    unless defined?(Battle::Field)
      raise "[FieldEffects] Battle::Field is not defined. " \
            "Ensure the FieldFramework plugin loads before FieldEffects " \
            "(check meta.txt Requires, or rename the plugin folder)."
    end
    klass = Class.new(Battle::Field) { include FE_RejuvDataMethods }
    Battle.const_set(:Field_RejuvData, klass)
  end
end

#===============================================================================
# PATCH FIELDFACTORY — prepend so no alias_method needed at parse time
#===============================================================================
module Battle::FieldFactory
  module FEBridgeCreate
    def create(battle, field_id, *args)
      FE_RejuvDataLoader.ensure!
      sym = field_id.to_sym

      klass = get_field_class(sym) rescue nil
      return klass.new(battle, *args) if klass

      if defined?(FIELDEFFECTS) && FIELDEFFECTS.key?(sym)
        return Battle::Field_RejuvData.new(battle, sym, *args)
      end

      super
    end
  end
  singleton_class.prepend(FEBridgeCreate)
end

#===============================================================================
# BATTLEBACK → FIELD AUTO-CREATION
#
# Problem: the framework's create_new_field converts the field ID to lowercase
# and looks for Battle::Field_cave, Battle::Field_volcanic, etc. Our plugin
# only defines Battle::Field_RejuvData — there are no per-field subclasses.
#
# Two-pronged fix:
#
# 1. FE_CreateFieldHook (prepend into create_new_field):
#    When the ID (upper or lower case) matches a key in FIELDEFFECTS, lazily
#    register a thin Battle::Field_<lowercase> subclass that delegates to
#    Battle::Field_RejuvData with the correct uppercase symbol. This means
#    create_new_field's Object.const_defined? check succeeds.
#
# 2. FE_BackdropFieldHook (prepend into set_default_field):
#    The framework already tries backdrop.downcase as a field ID; that handles
#    exact-match cases (e.g. "Cave" → :cave → :CAVE).
#    For non-exact names (e.g. "AshenBeach" → :BEACH) we consult the graphic
#    reverse map built from each field's :graphic array.
#===============================================================================

# Lazy graphic → field map (built once per process when first battle starts)
module FieldEffect
  def self.graphic_to_field_map
    @graphic_to_field_map ||= begin
      map = {}
      FIELDEFFECTS.each do |fid, data|
        next if fid == :INDOOR || fid == :PSYCHIC
        Array(data[:graphic]).each { |g| map[g.to_s] = fid if g && !g.empty? }
      end
      map.freeze
    end
  end
end

# 1. Lazily register Battle::Field_<lowercase> for any FIELDEFFECTS key
module Battle::FE_CreateFieldHook
  def create_new_field(field_id, *args, **kwargs)
    FE_RejuvDataLoader.ensure!

    lower_str  = field_id.to_s.downcase          # "cave"
    upper_sym  = field_id.to_s.upcase.to_sym     # :CAVE
    class_name = "Battle::Field_#{lower_str}"    # "Battle::Field_cave"

    if defined?(FIELDEFFECTS) && FIELDEFFECTS.key?(upper_sym) &&
       !Object.const_defined?(class_name)
      id_sym = upper_sym  # close over upper_sym for the subclass
      klass = Class.new(Battle::Field_RejuvData) do
        define_method(:initialize) do |battle, duration_arg = nil, *rest|
          super(battle, id_sym, duration_arg, *rest)
        end
      end
      Battle.const_set("Field_#{lower_str}", klass)
    end

    super
  end
end
Battle.prepend(Battle::FE_CreateFieldHook)

# 2. Catch non-exact battleback names via the graphic reverse map
module Battle::FE_BackdropFieldHook
  def set_default_field
    backdrop_name = @backdrop.to_s
    unless backdrop_name.empty?
      # Exact case-insensitive match (e.g. "Cave" → :CAVE) — handled by
      # FE_CreateFieldHook when the framework calls create_new_field(:cave).
      # We only need to intervene for non-exact graphic names.
      fid = FieldEffect.graphic_to_field_map[backdrop_name]
      if fid && fid.to_s.downcase != backdrop_name.downcase
        # Graphic name differs from field ID (e.g. "AshenBeach" → :BEACH)
        if create_new_field(fid, Battle::Field::INFINITE_FIELD_DURATION)
          return
        end
      end
    end
    super
  end
end
Battle.prepend(Battle::FE_BackdropFieldHook)

#===============================================================================
# HOOK pbEffectsAfterMove — fires our :after_move effect after each move
#===============================================================================
class Battle::Battler
  alias_method :fe_bridge_original_pbEffectsAfterMove, :pbEffectsAfterMove

  def pbEffectsAfterMove(user, targets, move, numHits)
    fe_bridge_original_pbEffectsAfterMove(user, targets, move, numHits)
    return unless @battle.respond_to?(:has_field?) && @battle.has_field?
    @battle.apply_field_effect(:after_move, user, move, targets)
  end
end
