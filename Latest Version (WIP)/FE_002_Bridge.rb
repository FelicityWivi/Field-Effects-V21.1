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
# The FieldFramework maps field IDs to classes via FieldFactory.get_field_class,
# but has no reverse mapping for FIELDEFFECTS-defined fields (which all use the
# dynamic Battle::Field_RejuvData rather than a registered subclass). This means
# battlebacks like "Sahara" are never linked to :SAHARA at battle start.
#
# Fix: build a reverse map at load time from each field's :graphic array, then
# hook Battle::Scene#set_fieldback — which IS called at battle start with the
# battleback name — to fire create_new_field when no non-default field is active.
#
# Guard: only auto-create when the current field is nil or :INDOOR, so
# mid-battle fieldback changes don't re-trigger this path. A reentrance flag
# prevents looping when create_new_field itself calls set_fieldback.
#===============================================================================

# Lazy builder — deferred to first call so FIELDEFFECTS (FE_003) is guaranteed loaded.
module FieldEffect
  def self.graphic_to_field_map
    @graphic_to_field_map ||= begin
      map = {}
      FIELDEFFECTS.each do |fid, data|
        next if fid == :INDOOR
        Array(data[:graphic]).each { |g| map[g.to_s] = fid }
      end
      map.freeze
    end
  end
end

module Battle::Scene::FE_BattlebackFieldHook
  def set_fieldback(name, *args)
    super
    return if @_fe_fieldback_creating
    return unless @battle&.respond_to?(:create_new_field)
    current_id = @battle.current_field&.id rescue nil
    return unless current_id.nil? || current_id == :INDOOR
    fid = FieldEffect.graphic_to_field_map[name.to_s]
    return unless fid
    @_fe_fieldback_creating = true
    begin
      @battle.create_new_field(fid)
    ensure
      @_fe_fieldback_creating = false
    end
  end
end
Battle::Scene.prepend(Battle::Scene::FE_BattlebackFieldHook)

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
