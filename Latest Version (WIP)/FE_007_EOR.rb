#===============================================================================
# Field Effects Plugin — End of Round Effects
# File: FE_007_EOR.rb
#
# All EOR passive damage, healing and field transitions.
# These are invoked through Battle::Field_RejuvData's :EOR_field_battler and
# :EOR_field_battle procs (registered in FE_002_Bridge).
# Their 005_Battle#end_of_round_field_process calls apply_field_effect for both.
#
# PASSIVE DAMAGE AMOUNTS (per Field Effect Manual):
#   VOLCANIC            → 1/8 HP  fire damage  (non-Fire grounded)
#   SUPERHEATED         → 1/16 HP fire damage  (non-Fire grounded)
#   INFERNAL            → 1/16 HP fire damage  (non-Fire grounded)
#   VOLCANICTOP         → 1/16 HP fire damage  (non-Fire grounded)
#   DRAGONSDEN          → 1/16 HP draconic     (non-Dragon; blocked by Sun)
#   DESERT              → 1/16 HP sandstorm    (non-Rock/Ground/Steel grounded)
#   ICY / SNOWYMOUNTAIN → 1/16 HP hail         (non-Ice grounded)
#   UNDERWATER          → 1/8  HP water        (non-Water types)
#   MURKWATERSURFACE    → 1/8  HP poison       (non-Steel/Poison)
#
# EOR HEALING:
#   GRASSY → 1/16 HP (grounded)   MISTY → 1/16 HP (grounded)
#
# EOR FIELD TRANSITIONS:
#   VOLCANIC:         Rain/Sandstorm active → Cave
#   DARKCRYSTALCAVERN:Sun/HarshSun active   → Crystal Cavern
#
# Grassy Terrain EOR healing for the terrain overlay is already in their
# 016_FieldAutoHooks; we handle the GRASSY full-field version here.
#===============================================================================

module FieldEffect
  module EOR
    module_function

    #===========================================================================
    # PROCESS_BATTLER — called once per battler per round.
    #===========================================================================
    def process_battler(battler, battle, field_id)
      return if battler.fainted?

      case field_id

      #-------------------------------------------------------------------------
      # VOLCANIC — 1/8 HP fire damage to non-Fire grounded types
      #-------------------------------------------------------------------------
      when :VOLCANIC
        return unless fire_passive_eligible?(battler)
        deal_passive(battler, battle, battler.totalhp / 8, "fire",
                     "{1} was scorched by the volcanic field!")

      #-------------------------------------------------------------------------
      # SUPERHEATED / INFERNAL / VOLCANICTOP — 1/16 HP fire
      #-------------------------------------------------------------------------
      when :SUPERHEATED, :INFERNAL, :VOLCANICTOP
        return unless fire_passive_eligible?(battler)
        msg = case field_id
              when :SUPERHEATED then "{1} was hurt by the superheated air!"
              when :INFERNAL    then "{1} was hurt by the hellish flames!"
              else                   "{1} was hurt by the volcanic heat!"
              end
        deal_passive(battler, battle, battler.totalhp / 16, "fire", msg)

      #-------------------------------------------------------------------------
      # DRAGON'S DEN — 1/16 HP draconic energy (non-Dragon; immune in Sun)
      #-------------------------------------------------------------------------
      when :DRAGONSDEN
        return if battler.pbHasType?(:DRAGON)
        return if [:Sun, :HarshSun].include?(battle.pbWeather)
        return if passive_immune_generic?(battler)
        deal_passive(battler, battle, battler.totalhp / 16, "dragon",
                     "{1} was hurt by the draconic energy!")

      #-------------------------------------------------------------------------
      # DESERT — 1/16 HP sandstorm-like damage
      #-------------------------------------------------------------------------
      when :DESERT
        return if battler.pbHasType?(:ROCK) || battler.pbHasType?(:GROUND) || battler.pbHasType?(:STEEL)
        return if battler.hasActiveAbility?(:SANDVEIL) || battler.hasActiveAbility?(:SANDFORCE) ||
                  battler.hasActiveAbility?(:SANDRUSH)  || battler.hasActiveAbility?(:OVERCOAT)
        return if passive_immune_generic?(battler) || battler.airborne?
        deal_passive(battler, battle, battler.totalhp / 16, nil,
                     "{1} was buffeted by the sandstorm!")

      #-------------------------------------------------------------------------
      # ICY / SNOWY MOUNTAIN — 1/16 HP hail-like damage
      #-------------------------------------------------------------------------
      when :ICY, :SNOWYMOUNTAIN
        return if battler.pbHasType?(:ICE)
        return if battler.hasActiveAbility?(:ICEBODY)  || battler.hasActiveAbility?(:SNOWCLOAK) ||
                  battler.hasActiveAbility?(:OVERCOAT)
        return if passive_immune_generic?(battler) || battler.airborne?
        deal_passive(battler, battle, battler.totalhp / 16, nil,
                     "{1} was buffeted by the hail!")

      #-------------------------------------------------------------------------
      # UNDERWATER — 1/8 HP (non-Water types)
      #-------------------------------------------------------------------------
      when :UNDERWATER
        return if battler.pbHasType?(:WATER) || passive_immune_generic?(battler)
        deal_passive(battler, battle, battler.totalhp / 8, nil,
                     "{1} struggled to breathe underwater!")

      #-------------------------------------------------------------------------
      # MURKWATER SURFACE — 1/8 HP poison (non-Steel/Poison)
      #-------------------------------------------------------------------------
      when :MURKWATERSURFACE
        return if battler.pbHasType?(:STEEL) || battler.pbHasType?(:POISON)
        return if battler.hasActiveAbility?(:POISONHEAL) || passive_immune_generic?(battler)
        deal_passive(battler, battle, battler.totalhp / 8, nil,
                     "{1} was hurt by the toxic water!")

      #-------------------------------------------------------------------------
      # GRASSY (full field) — 1/16 HP healing for grounded Pokémon
      #-------------------------------------------------------------------------
      when :GRASSY
        return if battler.airborne? || battler.hp >= battler.totalhp || battler.fainted?
        heal = [battler.totalhp / 16, 1].max
        battler.pbRecoverHP(heal)
        battle.pbDisplay(_INTL("{1} was healed by the Grassy Terrain!", battler.pbThis))

      #-------------------------------------------------------------------------
      # MISTY (full field) — 1/16 HP healing for grounded Pokémon
      #-------------------------------------------------------------------------
      when :MISTY
        return if battler.airborne? || battler.hp >= battler.totalhp || battler.fainted?
        heal = [battler.totalhp / 16, 1].max
        battler.pbRecoverHP(heal)
        battle.pbDisplay(_INTL("{1} was soothed by the Misty Terrain!", battler.pbThis))

      #-------------------------------------------------------------------------
      # HAUNTED — Wandering Spirit loses 1 Speed stage per round
      #-------------------------------------------------------------------------
      when :HAUNTED
        return unless battler.hasActiveAbility?(:WANDERINGSPIRIT)
        return unless battler.pbCanLowerStatStage?(:SPEED, battler)
        battler.pbLowerStatStageBasic(:SPEED, 1)
        battle.pbDisplay(_INTL("{1}'s Wandering Spirit drained its speed!", battler.pbThis))
      end
    end

    #===========================================================================
    # PROCESS_BATTLE — called once per round for battle-wide EOR transitions.
    #===========================================================================
    def process_battle(battle, field_id)
      case field_id

      when :VOLCANIC
        weather = battle.pbWeather
        if [:Rain, :HeavyRain].include?(weather)
          battle.pbDisplay(_INTL("The rain snuffed out the volcanic flame!"))
          battle.create_new_field(:CAVE)
        elsif weather == :Sandstorm
          battle.pbDisplay(_INTL("The sandstorm smothered the volcanic field!"))
          battle.create_new_field(:CAVE)
        end

      when :DARKCRYSTALCAVERN
        if [:Sun, :HarshSun].include?(battle.pbWeather)
          battle.pbDisplay(_INTL("The sunlight purified the dark crystals!"))
          battle.create_new_field(:CRYSTALCAVERN)
        end
      end
    end

    #---------------------------------------------------------------------------
    # Helpers
    #---------------------------------------------------------------------------
    def deal_passive(battler, battle, divisor, _type_label, msg)
      hp = [(battler.totalhp.to_f / [divisor, 1].max).ceil, 1].max
      battle.scene.pbDamageAnimation(battler) rescue nil
      battler.pbReduceHP(hp, false)
      battle.pbDisplay(_INTL(msg, battler.pbThis))
      battler.pbFaint if battler.fainted?
    end

    def fire_passive_eligible?(battler)
      return false if battler.pbHasType?(:FIRE)
      return false if battler.effects[PBEffects::AquaRing]
      return false if [:FLAREBOOST, :MAGMAARMOR, :FLAMEBODY, :FLASHFIRE,
                       :WATERVEIL, :MAGICGUARD, :HEATPROOF, :WATERBUBBLE].any? do |ab|
        battler.hasActiveAbility?(ab)
      end
      return false if FE_TWOTURNMOVES.include?(battler.effects[PBEffects::TwoTurnAttack])
      true
    end

    def passive_immune_generic?(battler)
      battler.hasActiveAbility?(:MAGICGUARD)
    end
  end
end

#===============================================================================
# EOR ABILITY EFFECTS — extended process_battler for ability-driven EOR
# Appended to FE_007; called from same :EOR_field_battler proc chain.
#===============================================================================
module FieldEffect
  module EOR
    # Called from process_battler dispatch — extend with ability EOR checks.
    def self.process_ability_eor(battler, battle, field_id)
      return if battler.fainted?
      return unless battler.canHeal? || battler.takesIndirectDamage?

      case field_id

      when :ELECTERRAIN
        # Volt Absorb: heals 1/16 HP each round on Electric field
        if battler.hasActiveAbility?(:VOLTABSORB) && battler.canHeal?
          heal = [(battler.totalhp / 16.0).ceil, 1].max
          battler.pbRecoverHP(heal)
          battle.pbDisplay(_INTL("{1}'s Volt Absorb restored HP!", battler.pbThis))
        end
        # Motor Drive: Speed +1 each round
        if battler.hasActiveAbility?(:MOTORDRIVE) && battler.pbCanRaiseStatStage?(:SPEED, battler)
          battler.pbRaiseStatStageBasic(:SPEED, 1)
          battle.pbDisplay(_INTL("{1}'s Motor Drive kicked in!", battler.pbThis))
        end
        # Slow Start: counter -2 per turn
        if battler.hasActiveAbility?(:SLOWSTART)
          cnt = battler.effects[PBEffects::SlowStart] || 0
          battler.effects[PBEffects::SlowStart] = [cnt - 2, 0].max if cnt > 0
        end

      when :GRASSY
        # Sap Sipper: heals 1/16 EOR
        if battler.hasActiveAbility?(:SAPSIPPER) && battler.canHeal?
          heal = [(battler.totalhp / 16.0).ceil, 1].max
          battler.pbRecoverHP(heal)
          battle.pbDisplay(_INTL("{1}'s Sap Sipper restored HP!", battler.pbThis))
        end
        # Harvest: attempt to restore a consumed Berry
        if battler.hasActiveAbility?(:HARVEST) && battler.item == :NONE
          if (battler.respond_to?(:pbConsumedItem) && battler.pbConsumedItem&.is_a?(Symbol) &&
              GameData::Item.get(battler.pbConsumedItem)&.pocket == :BERRIES rescue false)
            battler.item = battler.pbConsumedItem
            battle.pbDisplay(_INTL("{1} harvested a {2}!", battler.pbThis, battler.itemName))
          end
        end
        # Overgrow: always "active" (passive — no EOR action needed; boosts Grass moves)
        # Swarm: same

      when :MISTY
        # Dry Skin: heals 1/16 HP in Misty field
        if battler.hasActiveAbility?(:DRYSKIN) && battler.canHeal?
          heal = [(battler.totalhp / 16.0).ceil, 1].max
          battler.pbRecoverHP(heal)
          battle.pbDisplay(_INTL("{1}'s Dry Skin restored HP!", battler.pbThis))
        end

      when :BEWITCHED
        # Natural Cure: cures status each round
        if battler.hasActiveAbility?(:NATURALCURE) && battler.status != :NONE
          old_status = battler.status
          battler.pbCureStatus(false)
          status_name = begin; GameData::Status.get(old_status).name; rescue; "status"; end
          battle.pbDisplay(_INTL("{1}'s Natural Cure cured its {2}!", battler.pbThis, status_name))
        end

      when :HAUNTED
        # Fire Spin deals 1/6 instead of 1/8 — override trapping damage
        # (handled separately in pbEORTrappingDamage hook below)

      when :INFERNAL
        # Torment: battler under Torment takes 1/16 damage each turn
        taunt_active = begin; (battler.effects[PBEffects::Taunt] || 0) > 0; rescue; false; end
        if taunt_active
          # Actually Torment effect
        end
        nightmare_active = begin; battler.effects[PBEffects::Nightmare]; rescue; false; end
        if nightmare_active
          # Nightmare under Infernal deals extra 1/16 damage
          dmg = [(battler.totalhp / 16.0).ceil, 1].max
          battler.pbReduceHP(dmg, false)
          battle.pbDisplay(_INTL("{1} was consumed by the infernal nightmare!", battler.pbThis))
          battler.pbFaint if battler.fainted?
        end

      when :WATERSURFACE
        # Hydration: cures status each round
        if battler.hasActiveAbility?(:HYDRATION) && battler.status != :NONE
          battler.pbCureStatus(false)
          battle.pbDisplay(_INTL("{1}'s Hydration cured its status!", battler.pbThis))
        end
        # Steam Engine: Speed +1
        if battler.hasActiveAbility?(:STEAMENGINE)
          if battler.pbCanRaiseStatStage?(:SPEED, battler)
            battler.pbRaiseStatStageBasic(:SPEED, 1)
          end
        end
        # Water Compaction: each turn activation
        if battler.hasActiveAbility?(:WATERCOMPACTION)
          battler.pbRaiseStatStageBasic(:DEFENSE, 2) if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
        end
        # Water Absorb / Dry Skin: gradual restore
        if battler.hasActiveAbility?(:WATERABSORB) || battler.hasActiveAbility?(:DRYSKIN)
          heal = [(battler.totalhp / 16.0).ceil, 1].max
          battler.pbRecoverHP(heal) if battler.canHeal?
          battle.pbDisplay(_INTL("{1} absorbed water!", battler.pbThis))
        end

      when :VOLCANIC, :VOLCANICTOP
        # Steam Engine: Speed +1
        if battler.hasActiveAbility?(:STEAMENGINE) && battler.pbCanRaiseStatStage?(:SPEED, battler)
          battler.pbRaiseStatStageBasic(:SPEED, 1)
        end

      when :CITY
        # Pickup: Speed +1 EOR
        if battler.hasActiveAbility?(:PICKUP) && battler.pbCanRaiseStatStage?(:SPEED, battler)
          battler.pbRaiseStatStageBasic(:SPEED, 1)
        end
      end
    end
  end
end

# Hook ability EOR into the existing :EOR_field_battler by patching Bridge's proc.
# Since procs are already registered, we patch at the Battle level instead.
module Battle::FE_EOR_AbilityHook
  def end_of_round_field_process
    super
    return unless respond_to?(:has_field?) && has_field?
    fid = current_field.id
    eachBattler { |b| FieldEffect::EOR.process_ability_eor(b, self, fid) }
  end
end
Battle.prepend(Battle::FE_EOR_AbilityHook)

# HAUNTED — Fire Spin deals 1/6 EOR damage instead of 1/8
class Battle
  alias_method :fe_haunted_trapping_original, :pbEORTrappingDamage if method_defined?(:pbEORTrappingDamage)

  def pbEORTrappingDamage(battler)
    if FE == :HAUNTED && (battler.effects[PBEffects::TrappingMove] == :FIRESPIN rescue false)
      return if battler.fainted?
      dmg = [(battler.totalhp / 6.0).ceil, 1].max
      @scene.pbDamageAnimation(battler)
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is hurt by the spectral fire!", battler.pbThis))
      battler.pbFaint if battler.fainted?
    else
      respond_to?(:fe_haunted_trapping_original) ? fe_haunted_trapping_original(battler) : super
    end
  end
end
