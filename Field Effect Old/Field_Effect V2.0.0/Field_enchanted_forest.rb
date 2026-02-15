class Battle::Field_enchanted_forest < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :Field_enchanted_forest
    @name                = _INTL("Enchanted_forest")
    @nature_power_change = :DAZZLINGGLEAM
    @mimicry_type        = :POISON
    @camouflage_type     = :FAIRY
    @terrain_pulse_type  = :FAIRY
    @ability_activation  = %i[FLOWERGIFT]
#    @secret_power_effect = X # Sleep, Poison, or Paralysis.
    @shelter_type        = :POISON # halves damage taken from ground type moves after using shelter
    @field_announcement  = { :start    => _INTL("Once upon a time!"),
                             :end      => _INTL("The enchantments are lost to time!") }

    @multipliers = {
      [:power_multiplier, 1.5, _INTL("The enchanted aura boosted the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[FAIRY].include?(type)
        },
        [:power_multiplier, 1.5, _INTL("Flourish!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[GRASS].include?(type)
        },
        [:power_multiplier, 1.5, _INTL("Poison seeps from the darkness!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[POISON].include?(type)
        },
        [:power_multiplier, 1.3, _INTL("Not all fairy tales...")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[DARK].include?(type)
        },
        [:power_multiplier, 1.2, _INTL("The enchanted aura boosted the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[STEEL].include?(type)
        },
        [:power_multiplier, 1.5, _INTL("Magic aura amplified the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[HEX MYSTICALFIRE SPIRITBREAK MAGICALTORQUE FLEURCANNON RELICSONG].include?(move.id)
        },
        [:power_multiplier, 1.5, _INTL("The Knight is Justified!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[AIRSLASH AQUACUTTER BEHEMOTHBLADE CEASELESSEDGE LEAFBLADE NIGHTSLASH PSYCHOCUT RAZORSHELL SMARTSTRIKE SOLARBLADE STONEAXE TACHYONCUTTER BITTERBLADE PSYBLADE].include?(move.id)
        },
        [:power_multiplier, 1.4, _INTL("Magic aura amplified the beams!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[AURORABEAM BUBBLEBEAM CHARGEBEAM HYPERBEAM ICEBEAM MIRRORBEAM PSYBEAM SIGNALBEAM TWINBEAM].include?(move.id)
        },
        [:power_multiplier, 1.2, _INTL("It was a curse!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[DARKPULSE MOONBLAST NIGHTDAZE BLOODMOON].include?(move.id)
        },
    }

    @effects[:change_effectiveness] = proc { |effectiveness, move, moveType, defType, user, target|
     next Effectiveness::SUPER_EFFECTIVE_MULTIPLIER if user.pbHasType?(:FAIRY) && target.pbHasType?(:STEEL) # Fairy types super-effective against steel
   }

   @effects[:change_effectiveness] = proc { |effectiveness, move, moveType, defType, user, target|
   next Effectiveness::SUPER_EFFECTIVE_MULTIPLIER if user.pbHasType?(:STEEL) && target.pbHasType?(:DRAGON) # Steel types super-effective against Dragon
 }

   @effects[:change_effectiveness] = proc { |effectiveness, move, moveType, defType, user, target|
   next Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER if user.pbHasType?(:FAIRY) && target.pbHasType?(:DARK) # Fairy deal neutral damage to dark types
 }

 @effects[:change_effectiveness] = proc { |effectiveness, move, moveType, defType, user, target|
 next Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER if user.pbHasType?(:DARK) && target.pbHasType?(:FAIRY) # Dark deal neutral damage to Fairy types
}

    @effects[:EOR_field_battler] = proc { |battler|
    if %i[GRASS POISON].include?(type) && battler.grounded? && battler.canHeal? # end of round healing
      battler.pbRecoverHP(battler.totalhp / 16)
      @battle.pbDisplay(_INTL("The enchanted forest healed the Pokemon on the field!", battler.pbThis, @name))
    end
  }

  @effects[:EOR_field_battler] = proc { |battler|
  if battler.status == :SLEEP && battler.grounded?# If the pokemon is asleep then they lose 1/16th of their health
    battler.pbReduceHP(battler.totalhp / 16)
    @battle.pbDisplay(_INTL("The dream is corrupted by the evil in the woods!", battler.pbThis, @name))
  end
}
  end
end

Battle::Field.register(:enchanted_forest, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# Cotton Down now lowers Speed by 2 stages when activated.
# Effect Spore's activation rate is doubled to 60%.
# Flower Veil now affects all Pokémon regardless of their typing.
# Natural Cure additionally heals status at the end of the turn.
# Pastel Veil additionally negates the bearer's Fairy-type weaknesses.
# Power Spot boosts the partner's damage by 1.5x.
# Prankster can now affect Dark-types.
#     Forest's Curse additionally Curses the target.
# Grass Whistle, Poison Powder, Sleep Powder, and Stun Spore's accuracy is increased to 85%.
# Magic Powder additionally inflicts Sleep on the target.
# Moonlight heals 75% of the user's max HP.
# Strength Sap additionally lowers the target's Special Attack by 1 stage.