class Battle::Field_sahara < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :sahara
    @name                = _INTL("Sahara")
    @nature_power_change = :NEEDLEARM
    @mimicry_type        = :GROUND
    @camouflage_type     = :GROUND
    @terrain_pulse_type  = :GROUND
    @ability_activation  = %i[CHLOROPHYLL FLOWERGIFT LEAFGUARD SANDFORCE SANDRUSH SANDVEIL]
    @secret_power_effect = 10 # burn
    @shelter_type        = :FIRE # halves damage taken from fire type moves after using shelter
    @field_announcement  = { :start => _INTL("The air is dry and humid."),
                             :end   => _INTL("The dry air clears!") }

    @multipliers = {
      [:power_multiplier, 1.3, _INTL("The humid air boosted the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[BUG FIRE GROUND ROCK].include?(type)
      },
      [:power_multiplier, 0.8, _INTL("The physical move is weakened by the field!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if move.physicalMove?
      },
      [:power_multiplier, 0.8, _INTL("The water evaporated!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[WATER].include?(type)
      },
      [:power_multiplier, 1.5, _INTL("The dry earth boosted the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[NEEDLEARM OVERHEAT PINNEEDLE ROCKWRECKER SANDTOMB SCORCHINGSANDS].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("They're coming out of the woodwork!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ATTACKORDER BUGBUZZ].include?(move.id)
      },
    }

    @effects[:switch_in] = proc { |battler| # effects when a pkmn switches in
    if battler.hasActiveAbility?(:BLAZE) && battler.pbCanLowerStatStage?(:DEFENSE)
      @battle.pbDisplay(_INTL("{1} lost power from the {2}!", battler.pbThis, @name))
      battler.pbLowerStatStage(:DEFENSE, 1, nil)
    end
    }
    @effects[:switch_in] = proc { |battler| # effects when a pkmn switches in
    if battler.hasActiveAbility?(:OVERGROW) && battler.pbCanLowerStatStage?(:DEFENSE)
      @battle.pbDisplay(_INTL("{1} lost power from the {2}!", battler.pbThis, @name))
      battler.pbLowerStatStage(:DEFENSE, 1, nil)
    end
    }
    @effects[:switch_in] = proc { |battler| # effects when a pkmn switches in
    if battler.hasActiveAbility?(:TORRENT) && battler.pbCanLowerStatStage?(:DEFENSE)
      @battle.pbDisplay(_INTL("{1} lost power from the {2}!", battler.pbThis, @name))
      battler.pbLowerStatStage(:DEFENSE, 1, nil)
    end
    }


    @effects[:base_type_change] = proc { |user, move, type|
      next :WATER if %i[ICE].include?(type) # Ice type moves become Water type
    }

    @effects[:no_charging] = proc { |user, move|
      next true if %i[SOLARBEAM SOLARBLADE].include?(move.id) && user.grounded?
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| 
    if %i[WATER].include?(type) && battler.canHeal? # Heal after being hit with a water type move
      battler.pbRecoverHP(battler.totalhp / 8)
      @battle.pbDisplay(_INTL("{1}'s HP was restored by the {2}!", battler.pbThis, @name))
    end
  }

  end
end

Battle::Field.register(:sahara, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# The stat changing affects of these moves is increased: Sand Attack Thermal Exchange Defend Order Silver Wind #
# Swarm is increased to 1.6x #
# Drizzle & electric surge has no effect #
# Drought causes extremely harsh sunlight #
# Dry skin, Fur Coat & Fluffy reduces HP on switch in & every turn #
# Flare boost & Flash fire are increased to 1.6x #
# Forecast changes to sunny form #
# Ice face, Ice Scales, Refrigerate & Snow Warning have no effect #