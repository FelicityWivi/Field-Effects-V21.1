#===============================================================================
# Field Effects Plugin — Item Effects
# File: FE_006_ItemEffects.rb
#
#   1. Seed activation system (Elemental, Telluric, Magical, Synthetic seeds)
#   2. Big Root ×1.6 drain heal on GRASSY field  (instead of ×1.3)
#   3. Shell Bell heals 25% on BEACH field  (instead of 1/8)
#   4. Backalley: all passive healing ×0.67
#===============================================================================

#===============================================================================
# 1. SEED ACTIVATION MODULE
# Called from Battle::Field_RejuvData's :set_field_battler proc via
# FieldEffect::Seeds.apply(battler, battle, seed_data).
# Also called manually via battle.seedCheck(battler) for event scripts.
#===============================================================================
module FieldEffect
  module Seeds
    SEED_ITEM_MAP = {
      ELEMENTALSEED:  :ELEMENTALSEED,
      TELURICSEED:    :TELURICSEED,
      MAGICALSEED:    :MAGICALSEED,
      SYNTHETICSEED:  :SYNTHETICSEED,
    }.freeze

    module_function

    # Called once when the field activates, per battler.
    def apply(battler, battle, seed_data)
      return unless seed_data && !seed_data.empty?
      seed_type = seed_data[:seedtype]
      return unless seed_type
      return unless battler.hasActiveItem?(seed_type)
      return if battler.fainted?

      # Consume the seed
      battler.pbConsumeItem(false)

      # Apply stat changes
      (seed_data[:stats] || {}).each do |stat, stages|
        next unless stages && stages != 0
        if stages > 0
          battler.pbRaiseStatStageBasic(stat, stages)
        else
          battler.pbLowerStatStageBasic(stat, -stages)
        end
      end

      # Apply effect
      effect_sym = seed_data[:effect]
      duration   = seed_data[:duration]
      apply_effect(battler, battle, effect_sym, duration, seed_data)

      # Display message
      msg = seed_data[:message]
      battle.pbDisplay(_INTL(msg.to_s.gsub("{1}", battler.pbThis))) if msg && !msg.empty?

      # Play animation
      anim = seed_data[:animation]
      battle.pbCommonAnimation(anim.to_s, battler, nil) if anim
    end

    # Called via battle.seedCheck(battler) — same as apply but checks the
    # battler's held item against the active field's seed data.
    def check(battler, battle)
      return unless battle.has_field?
      field_data_entry = FIELDEFFECTS[battle.FE] rescue nil
      return unless field_data_entry
      seed = field_data_entry[:seed] || {}
      apply(battler, battle, seed)
    end

    private

    def apply_effect(battler, battle, effect_sym, duration, data)
      return unless effect_sym
      case effect_sym
      when :MagnetRise
        battler.effects[PBEffects::MagnetRise] = (duration || 5)
      when :MagicCoat
        battler.effects[PBEffects::MagicCoat] = true
      when :Ingrain
        battler.effects[PBEffects::Ingrain] = true
      when :Charge
        battler.effects[PBEffects::Charge] = (duration || 2)
      when :AquaRing
        battler.effects[PBEffects::AquaRing] = true
      when :FlashFire
        battler.effects[PBEffects::FlashFire] = true
      when :SandTomb
        battler.effects[PBEffects::TrappingMove] = :SANDTOMB
        battler.effects[PBEffects::Trapping] = (duration || 5)
      when :FireSpin
        battler.effects[PBEffects::TrappingMove] = :FIRESPIN
        battler.effects[PBEffects::Trapping] = (duration || 5)
      when :FocusEnergy
        battler.effects[PBEffects::FocusEnergy] = (duration || 3)
      when :Taunt
        battler.effects[PBEffects::Taunt] = (duration || 4)
      when :MeanLook
        battler.effects[PBEffects::MeanLook] = battler.index
      when :Wish
        battler.effects[PBEffects::Wish] = (duration || 2)
        battler.effects[PBEffects::WishAmount] = (battler.totalhp / 2.0).floor
      when :EndureThenStealth
        battler.effects[PBEffects::Endure] = true
        battle.pbStealth(battler.index) rescue nil
      when :Burned
        battler.pbBurn(nil) if battler.pbCanBurn?(nil, false, nil)
      when :Poisoned, :BadlyPoisoned
        battler.pbPoison(nil, nil, effect_sym == :BadlyPoisoned) if battler.pbCanPoison?(nil, false, nil)
      end
      module_function
    end
  end
end

#===============================================================================
# 2. BIG ROOT ×1.6 ON GRASSY
# Normally Big Root gives ×1.3 on drain heals. On GRASSY it gives ×1.6.
#===============================================================================
# (Big Root ×1.6 on GRASSY is handled by pbRecoverHPFromDrain below)

class Battle::Battler
  alias_method :fe_bigrootgrassy_original_pbRecoverHPFromDrain, :pbRecoverHPFromDrain

  def pbRecoverHPFromDrain(hpGained, target, msg = nil)
    # On GRASSY field, Big Root gives ×1.6 instead of the standard ×1.3
    if @battle.FE == :GRASSY && hasActiveItem?(:BIGROOT)
      hpGained = (hpGained / 1.3 * 1.6).floor   # undo ×1.3, apply ×1.6
    end
    fe_bigrootgrassy_original_pbRecoverHPFromDrain(hpGained, target, msg)
  end
end

#===============================================================================
# 3. SHELL BELL HEALS 25% ON BEACH (instead of 1/8)
#===============================================================================
# Shell Bell 25% on BEACH — override via the AfterMoveUseFromUser effect registry.
# The base Shell Bell entry heals 1/8; we override it to 1/4 on BEACH.
Battle::ItemEffects::AfterMoveUseFromUser.add(:SHELLBELL_BEACH,
  proc { |item, user, targets, move, numHits, battle|
    next unless battle.respond_to?(:FE) && battle.FE == :BEACH
    next unless user.hasActiveItem?(:SHELLBELL) && user.canHeal?
    totalDamage = 0
    targets.each { |b| totalDamage += b.damageState.totalHPLost }
    next if totalDamage <= 0
    user.pbRecoverHP(totalDamage / 4)
    battle.pbDisplay(_INTL("{1}'s Shell Bell restored HP!", user.pbThis))
  }
) if defined?(Battle::ItemEffects::AfterMoveUseFromUser)

#===============================================================================
# 4. BACKALLEY — ALL PASSIVE HEALING ×0.67
# Wraps pbRecoverHP so any animated (non-combat) recovery is reduced.
# Combat drain moves are excluded (they use pbRecoverHPFromDrain directly).
#===============================================================================
class Battle::Battler
  alias_method :fe_backalley_original_pbRecoverHP, :pbRecoverHP

  def pbRecoverHP(amt, anim = true, any_anim = true)
    if @battle.FE == :BACKALLEY && anim && amt > 0
      amt = [amt * 2 / 3, 1].max
    end
    fe_backalley_original_pbRecoverHP(amt, anim, any_anim)
  end
end
