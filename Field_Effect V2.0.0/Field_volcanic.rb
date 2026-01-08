class Battle::Field_volcanic < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :volcanic
    @name                = _INTL("Volcanic")
    @nature_power_change = :FLAMETHROWER
    @mimicry_type        = :FIRE
    @camouflage_type     = :FIRE
    @ability_activation  = %i[BLAZE FLAREBOOST]
    @terrain_pulse_type  = :FIRE
    @secret_power_effect = 10 # burn
    @shelter_type        = :FIRE # halves damage taken from fire type moves after using shelter
    @field_announcement  = { :start => _INTL("The field is molten."),
                             :end   => _INTL("The flames were snuffed out!") }

    @multipliers = {
      [:power_multiplier, 2, _INTL("The flames spread from the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[CLEARSMOG SMOG INFERNALPARADE].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("The target was knocked into the flames!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ROCKSLIDE SMACKDOWN THOUSANDARROWS TEMPERFLARE].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("The blaze amplified the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[FIRE].include?(type)
      },
      [:power_multiplier, 1.3, _INTL("The Sand snuffed out the flames!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[SANDTOMB].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The wind snuffed out the flame!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[DEFOG GUST HURRICANE RAZORWIND TAILWIND TWISTER SUPERSONIC WHIRLWIND].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The water snuffed out the flame!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[MUDDYWATER SPARKLINGARIA SURF WATERPLEDGE WATERSPORT WATERSPOUT].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The sludge snuffed out the flame!")] => proc { |user, target, numTargets, move, type, power, mults|
      next true if %i[SLUDGEWAVE].include?(move.id)
      },
      [:power_multiplier, 0.5, _INTL("The blaze softened the attack...")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[GRASS ICE].include?(type)
      },
    }

    @effects[:accuracy_modify] = proc { |user, target, move, modifiers, type|
      modifiers[:base_accuracy] = 0 if %i[WILLOWISP].include?(move.id)
    }

    @effects[:switch_in] = proc { |battler| # effects when a pkmn switches in
      if battler.hasActiveAbility?(:MAGMAARMOR) && battler.pbCanRaiseStatStage?(:DEFENSE)
        @battle.pbDisplay(_INTL("{1} gained power from the {2}!", battler.pbThis, @name))
        battler.pbRaiseStatStage(:DEFENSE, 1, nil)
      end
      if battler.isSpecies?(:EISCUE) && battler.form == 0 && battler.ability == :ICEFACE
        battler.pbChangeForm(1, _INTL("{1}'s Ice Face melted in the heat!", battler.pbThis)) # this is a little bit odd, i cant find the original code
      end
    }

    @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
      next :FIRE if %i[CLEARSMOG SMOG ROCKSLIDE SMACKDOWN THOUSANDARROWS].include?(move.id)
    }

    @effects[:EOR_field_battler] = proc { |battler|
      if battler.grounded? && !battler.pbHasType?(:FIRE) &&
         !battler.hasActiveAbility?(%i[FLASHFIRE FLAREBODY FLAREBOOST HEATPROOF MAGMAARMOR WATERBUBBLE WATERVEIL THERMALEXCHANGE WELLBAKEDBODY])
        battler.pbReduceHP(battler.totalhp / 8)
        @battle.pbDisplay(_INTL("{1} was burned by the volcanic field!", battler.pbThis))
      end
      if battler.grounded? && battler.hasActiveAbility?(:FLASHFIRE)
        battler.effects[PBEffects::FlashFire] = true
        @battle.pbDisplay(_INTL("{1} is being boosted by the flames!", battler.pbThis))
      end
      if battler.grounded? && battler.hasActiveAbility?(:THERMALEXCHANGE) && battler.pbCanRaiseStatStage?(:ATTACK)
        battler.pbRaiseStatStage(:ATTACK, 1, nil)
        @battle.pbDisplay(_INTL("{1} is exchanging the flames for power!", battler.pbThis))
      end
      if battler.hasActiveAbility?(:STEAMENGINE) && battler.pbCanRaiseStatStage?(:SPEED)
        battler.pbRaiseStatStage(:SPEED, 1, nil)
        @battle.pbDisplay(_INTL("{1} gained power from the volcanic field!", battler.pbThis))
      end
    }

    @effects[:status_immunity] = proc { |battler, newStatus, yawn, user, show_message, self_inflicted, move, ignoreStatus|
      if %i[FROZEN].include?(newStatus)
        @battle.pbDisplay(_INTL("{1} cannot be frozen in the volcanic field!", battler.pbThis)) if show_message
        next true
      end
    }

    @effects[:block_weather] = proc { |new_weather, user, fixedDuration|
      if %i[Hail].include?(new_weather)
        @battle.pbDisplay(_INTL("The intense heat of the volcanic field prevents hail from forming!"))
        next true
      end
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| 
    if %i[DEFOG GUST HURRICANE MUDDYWATER RAZORWIND TAILWIND TWISTER SANDTOMB SLUDGEWAVE SPARKLINGARIA SUPERSONIC SURF WATERPLEDGE WATERSPORT WATERSPOUT WHIRLWIND].include?(move.id)
    @battle.create_new_field(:cave, Battle::Field::INFINITE_FIELD_DURATION) 
    end
    }

  end
end

Battle::Field.register(:volcanic, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# Pokémon take x2 (25%) field damage if they are under the effect of Tar Shot, or have one of the abilities Fluffy, Grass Pelt, Ice Body or Leaf Guard.
# Burn Up's effect resets at the end of the turn. #
# Smokescreen lowers the target's Accuracy by 2 stages.#

# Changing fields #
# This field will also transform into Cave if Rain or Sandstorm weather are active at the end of the turn. #
# The rain snuffed out the flame! #