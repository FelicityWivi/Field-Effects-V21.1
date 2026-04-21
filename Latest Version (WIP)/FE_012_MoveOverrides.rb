#===============================================================================
# Field Effects Plugin — Move Overrides & Healing Mechanics
# File: FE_012_MoveOverrides.rb
#
# Implements field-specific move behaviour not covered by data-hash entries:
#
#  1.  Wish / Floral Healing / Life Dew / Aqua Ring enhanced healing
#  2.  Tailwind 6 turns + Strong Winds (MOUNTAIN / SNOWYMOUNTAIN / VOLCANICTOP)
#  3.  Power Spot ×1.5 (HAUNTED / BEWITCHED / HOLY / PSYTERRAIN / DEEPEARTH)
#  4.  Corrosion ability ×1.5 damage (CORROSIVE / CORRUPTED / CORROSIVEMIST)
#  5.  Punk Rock on BIG TOP (was only CAVE)
#  6.  Aerilate on SKY field
#  7.  Gale Wings during Strong Winds (MOUNTAIN / SNOWYMOUNTAIN / VOLCANICTOP)
#  8.  Steel SE vs Dragon on FAIRYTALE
#  9.  Aurora Veil without Hail on FROZENDIMENSION
# 10.  Hustle in CITY (same as BACKALLEY)
# 11.  Marvel Scale on RAINBOW / FAIRYTALE / DRAGONSDEN / STARLIGHTARENA
# 12.  Effect Spore 60% on FOREST (already done for BEWITCHED; extend here)
# 13.  Swamp: Gulp Missile → Arrokuda / Water Compaction EOR / Dry Skin 1/16
# 14.  Priority attacks fail on grounded — PSYTERRAIN
#===============================================================================

#===============================================================================
# 1.  WISH / FLORAL HEALING / LIFE DEW — enhanced healing on specific fields
#===============================================================================

# Wish restores 75% HP (instead of 50%) on:
# MISTY, RAINBOW, WATERSURFACE, FAIRYTALE, HOLY, STARLIGHTARENA, NEWWORLD
FE_WISH_75_FIELDS = %i[MISTY RAINBOW WATERSURFACE FAIRYTALE HOLY
                        STARLIGHTARENA NEWWORLD].freeze

class Battle::Move::HealUserPositionNextTurn  # Wish
  alias_method :fe012_wish_original, :pbEffectGeneral

  def pbEffectGeneral(user)
    if FE_WISH_75_FIELDS.include?(@battle.FE)
      # Override Wish to store 75% rather than 50%
      if user.pbOwnSide.effects[PBEffects::Wish] == 0
        user.pbOwnSide.effects[PBEffects::Wish]       = 2
        user.pbOwnSide.effects[PBEffects::WishAmount] = (user.totalhp * 3 / 4.0).ceil
        user.pbOwnSide.effects[PBEffects::WishMaker]  = user.pokemonIndex
        @battle.pbDisplay(_INTL("{1} made a wish!", user.pbThis))
      end
    else
      fe012_wish_original(user)
    end
  end
end if defined?(Battle::Move::HealUserPositionNextTurn)

# Floral Healing: fully heals on FAIRYTALE + CORROSIVE (additionally poisons on CORROSIVE)
class Battle::Move::HealTargetDependingOnGrassyTerrain  # Floral Healing
  alias_method :fe012_floral_original, :pbEffectAgainstTarget

  def pbEffectAgainstTarget(user, target)
    case @battle.FE
    when :FAIRYTALE, :FLOWERGARDEN3, :FLOWERGARDEN4, :FLOWERGARDEN5
      target.pbRecoverHP(target.totalhp)
      @battle.pbDisplay(_INTL("{1} was fully healed by the floral energy!", target.pbThis))
    when :CORROSIVE
      fe012_floral_original(user, target)
      target.pbPoison(user) if target.pbCanPoison?(user, false)
      @battle.pbDisplay(_INTL("The floral energy is tainted with poison!"))
    else
      fe012_floral_original(user, target)
    end
  end
end if defined?(Battle::Move::HealTargetDependingOnGrassyTerrain)

# Life Dew: 50% HP on HOLY; additionally poisons on CORROSIVEMIST
class Battle::Move::HealUserAndAlliesQuarterOfTotalHP  # Life Dew
  alias_method :fe012_lifedew_original, :pbEffectGeneral

  def pbEffectGeneral(user)
    fe012_lifedew_original(user)
    case @battle.FE
    when :HOLY
      # Life Dew normally heals 25%; on HOLY it heals 50% total (extra 25%)
      @battle.eachAlly(user.index) do |b|
        extra = (b.totalhp / 4.0).ceil
        b.pbRecoverHP(extra) if b.canHeal?
      end
    when :CORROSIVEMIST
      @battle.eachAlly(user.index) do |b|
        b.pbPoison(user) if b.pbCanPoison?(user, false)
      end
    end
  end
end if defined?(Battle::Move::HealUserAndAlliesQuarterOfTotalHP)

# Aqua Ring: heals 1/8 HP per turn (instead of 1/16) on MISTY / WATERSURFACE / UNDERWATER / SWAMP
# Implemented by hooking the EOR heal amount.
class Battle
  alias_method :fe012_aquaring_original_pbEORHealingEffects, :pbEORHealingEffects if method_defined?(:pbEORHealingEffects)

  def pbEORHealingEffects(priority)
    # Run the original first
    if respond_to?(:fe012_aquaring_original_pbEORHealingEffects)
      fe012_aquaring_original_pbEORHealingEffects(priority)
    end
    # On specific fields, extra Aqua Ring tick (original already gave 1/16; add another to reach 1/8)
    aqua_ring_boost_fields = %i[MISTY WATERSURFACE UNDERWATER SWAMP]
    return unless aqua_ring_boost_fields.include?(self.FE)
    priority.each do |b|
      next if b.fainted? || !b.canHeal?
      next unless b.effects[PBEffects::AquaRing]
      extra = [(b.totalhp / 16.0).ceil, 1].max
      b.pbRecoverHP(extra)
    end
  end
end

#===============================================================================
# 2.  TAILWIND 6 TURNS + STRONG WINDS (MOUNTAIN / SNOWYMOUNTAIN / VOLCANICTOP)
#===============================================================================
class Battle::Move::StartUserSideDoubleSpeed  # Tailwind
  alias_method :fe012_tailwind_original, :pbEffectGeneral

  def pbEffectGeneral(user)
    fe012_tailwind_original(user)
    case @battle.FE
    when :MOUNTAIN, :SNOWYMOUNTAIN, :VOLCANICTOP
      # Override to 6 turns and activate Strong Winds
      user.pbOwnSide.effects[PBEffects::Tailwind] = 6
      # Strong Winds is weather :StrongWinds in PE v21.1
      @battle.pbStartWeather(user, :StrongWinds, false) rescue nil
      @battle.pbDisplay(_INTL("Strong winds whipped up around {1}'s team!", user.pbThis))
    when :SKY
      # Sky already gives 8 turns (set in FE_008); ensure Strong Winds too
      @battle.pbStartWeather(user, :StrongWinds, false) rescue nil
    end
  end
end if defined?(Battle::Move::StartUserSideDoubleSpeed)

# Gale Wings activates during Strong Winds on MOUNTAIN / SNOWYMOUNTAIN / VOLCANICTOP
class Battle::Move
  alias_method :fe012_galewings_original, :pbPriority

  def pbPriority(user)
    base = fe012_galewings_original(user)
    return base unless user.hasActiveAbility?(:GALEWINGS)
    fields_with_winds = %i[MOUNTAIN SNOWYMOUNTAIN VOLCANICTOP SKY]
    return base unless fields_with_winds.include?(@battle.FE)
    # Strong Winds active OR Tailwind is up
    winds_active = (@battle.pbWeather == :StrongWinds rescue false) ||
                   (user.pbOwnSide.effects[PBEffects::Tailwind] > 0 rescue false)
    return base unless winds_active
    flyingMove? ? base + 1 : base
  end
end

#===============================================================================
# 3.  POWER SPOT ×1.5 on HAUNTED / BEWITCHED / HOLY / PSYTERRAIN / DEEPEARTH
#===============================================================================
FE_POWER_SPOT_FIELDS = %i[HAUNTED BEWITCHED HOLY PSYTERRAIN DEEPEARTH].freeze

class Battle::Move
  alias_method :fe012_powerspot_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe012_powerspot_original(user, target, numTargets, type, baseDmg, multipliers)
    return unless FE_POWER_SPOT_FIELDS.include?(@battle.FE)
    @battle.eachAlly(user.index) do |ally|
      if ally.hasActiveAbility?(:POWERSPOT)
        multipliers[:power_multiplier] *= 1.5
        break
      end
    end
  end
end

#===============================================================================
# 4.  CORROSION ABILITY ×1.5 DAMAGE on CORROSIVE / CORRUPTED / CORROSIVEMIST
#===============================================================================
FE_CORROSION_FIELDS = %i[CORROSIVE CORRUPTED CORROSIVEMIST].freeze

class Battle::Move
  alias_method :fe012_corrosion_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe012_corrosion_original(user, target, numTargets, type, baseDmg, multipliers)
    if FE_CORROSION_FIELDS.include?(@battle.FE) && user.hasActiveAbility?(:CORROSION)
      multipliers[:power_multiplier] *= 1.5
    end
  end
end

#===============================================================================
# 5.  PUNK ROCK ×1.5 SOUND MOVES on BIG TOP (extends existing CAVE check)
#===============================================================================
class Battle::Move
  alias_method :fe012_punkrock_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe012_punkrock_original(user, target, numTargets, type, baseDmg, multipliers)
    return unless @battle.FE == :BIGTOP
    if soundMove? && user.hasActiveAbility?(:PUNKROCK)
      multipliers[:power_multiplier] *= 1.5
    end
  end
end

#===============================================================================
# 6.  AERILATE ×1.5 on SKY FIELD
#===============================================================================
class Battle::Move
  alias_method :fe012_aerilate_sky_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe012_aerilate_sky_original(user, target, numTargets, type, baseDmg, multipliers)
    if @battle.FE == :SKY && user.hasActiveAbility?(:AERILATE) && type == :NORMAL
      multipliers[:power_multiplier] *= 1.5
    end
  end
end

#===============================================================================
# 7.  STEEL SUPER-EFFECTIVE vs DRAGON on FAIRYTALE
#===============================================================================
class Battle::Move
  alias_method :fe012_fairytale_steel_original, :pbCalcTypeModSingle if method_defined?(:pbCalcTypeModSingle)

  def pbCalcTypeModSingle(move_type, def_type, user, target)
    mod = respond_to?(:fe012_fairytale_steel_original) ?
          fe012_fairytale_steel_original(move_type, def_type, user, target) : super
    if @battle.FE == :FAIRYTALE && move_type == :STEEL && def_type == :DRAGON
      # Return 2x effectiveness (SE)
      return Effectiveness::SUPER_EFFECTIVE_ONE rescue 2.0
    end
    mod
  end
end

#===============================================================================
# 8.  AURORA VEIL WITHOUT HAIL on FROZENDIMENSION
#     (also DARKCRYSTALCAVERN, ICY, CRYSTALCAVERN, RAINBOW, STARLIGHTARENA
#      are already in statusMods data — this covers FROZENDIMENSION only)
#===============================================================================
class Battle::Move::StartWeakenDamageAgainstUserSideIfHail  # Aurora Veil
  alias_method :fe012_auroraveil_original, :pbMoveFailed?

  def pbMoveFailed?(user, targets)
    if @battle.FE == :FROZENDIMENSION
      return false  # Always succeeds on Frozen Dimensional
    end
    fe012_auroraveil_original(user, targets)
  end
end if defined?(Battle::Move::StartWeakenDamageAgainstUserSideIfHail)

#===============================================================================
# 9.  HUSTLE in CITY (same as BACKALLEY — already in FE_005 for BACKALLEY)
#===============================================================================
class Battle::Move
  alias_method :fe012_hustle_city_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe012_hustle_city_original(user, target, numTargets, type, baseDmg, multipliers)
    if @battle.FE == :CITY && user.hasActiveAbility?(:HUSTLE) && physicalMove?
      multipliers[:attack_multiplier] *= 1.75
    end
  end
end

class Battle::Move
  alias_method :fe012_hustle_city_acc_original, :pbBaseAccuracy

  def pbBaseAccuracy(user, target)
    acc = fe012_hustle_city_acc_original(user, target)
    if @battle.FE == :CITY && user.hasActiveAbility?(:HUSTLE) && physicalMove? && acc > 0
      acc = (acc * 0.67).round
    end
    acc
  end
end

#===============================================================================
# 10. MARVEL SCALE activated on RAINBOW / FAIRYTALE / DRAGONSDEN / STARLIGHTARENA
#===============================================================================
FE_MARVEL_SCALE_FIELDS = %i[RAINBOW FAIRYTALE DRAGONSDEN STARLIGHTARENA MISTY].freeze

class Battle::Move
  alias_method :fe012_marvelscale_original, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe012_marvelscale_original(user, target, numTargets, type, baseDmg, multipliers)
    if FE_MARVEL_SCALE_FIELDS.include?(@battle.FE) &&
       target.hasActiveAbility?(:MARVELSCALE) && physicalMove?
      multipliers[:defense_multiplier] *= 1.5
    end
  end
end

#===============================================================================
# 11. EFFECT SPORE 60% on FOREST
#     (BEWITCHED already handled in FE_010; same approach for FOREST)
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:EFFECTSPORE_FOREST,
  proc { |ability, user, target, move, battle|
    next unless battle.FE == :FOREST
    next unless target.hasActiveAbility?(:EFFECTSPORE)
    next unless move.pbContactMove?(user)
    next if battle.pbRandom(7) >= 3  # 3/7 extra chance → combined ~60% with base 30%
    r = battle.pbRandom(3)
    next if r == 0 && user.asleep?
    next if r == 1 && user.poisoned?
    next if r == 2 && user.paralyzed?
    battle.pbShowAbilitySplash(target)
    if user.affectedByPowder?(Battle::Scene::USE_ABILITY_SPLASH) &&
       user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      case r
      when 0; user.pbSleep    if user.pbCanSleep?(target,   Battle::Scene::USE_ABILITY_SPLASH)
      when 1; user.pbPoison(target) if user.pbCanPoison?(target, Battle::Scene::USE_ABILITY_SPLASH)
      when 2; user.pbParalyze(target) if user.pbCanParalyze?(target, Battle::Scene::USE_ABILITY_SPLASH)
      end
    end
    battle.pbHideAbilitySplash(target)
  }
)

#===============================================================================
# 12. SWAMP additional ability effects
#     Gulp Missile → Arrokuda / Water Compaction EOR / Dry Skin 1/16
#===============================================================================
module FieldEffect
  module EOR
    class << self
      alias_method :fe012_battler_original, :process_battler

      def process_battler(battler, battle, field_id)
        fe012_battler_original(battler, battle, field_id)
        return if battler.fainted?

        if field_id == :SWAMP
          # Dry Skin: 1/16 HP restore
          if battler.hasActiveAbility?(:DRYSKIN) && battler.canHeal?
            heal = [(battler.totalhp / 16.0).ceil, 1].max
            battler.pbRecoverHP(heal)
          end
          # Water Compaction: Def +2 each turn
          if battler.hasActiveAbility?(:WATERCOMPACTION)
            battler.pbRaiseStatStageBasic(:DEFENSE, 2) if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
          end
          # Gulp Missile → Arrokuda form
          if battler.isSpecies?(:CRAMORANT) && battler.hasActiveAbility?(:GULPMISSILE) && battler.form == 0
            battler.pbChangeForm(1, nil)
          end
        end
      end
    end
  end
end

#===============================================================================
# 13. PRIORITY ATTACKS FAIL ON GROUNDED — PSYTERRAIN
#===============================================================================
class Battle::Move
  alias_method :fe012_psyterrain_priority_original, :pbMoveFailed?

  def pbMoveFailed?(user, targets)
    if @battle.FE == :PSYTERRAIN && pbPriority(user) > 0
      # Check if any target is grounded
      grounded_target = targets.any? { |t| t.respond_to?(:airborne?) && !t.airborne? }
      if grounded_target
        @battle.pbDisplay(_INTL("The psychic terrain blocks priority moves!"))
        return true
      end
    end
    fe012_psyterrain_priority_original(user, targets)
  end
end
