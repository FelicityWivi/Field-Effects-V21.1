class Battle::Field_haunted < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION)
    super
    @id                  = :haunted
    @name                = _INTL("Haunted")
    @nature_power_change = :PHANTOMFORCE
    @mimicry_type        = :GHOST
    @camouflage_type     = :GHOST
    @ability_activation  = %i[]
    @terrain_pulse_type  = :GHOST
    @shelter_type        = :GHOST # halves damage taken from ice type moves after using shelter
    @field_announcement  = { :start => _INTL("The field is haunted!"),
                             :end   => _INTL("The evil has dissipated from the field!") }

    @multipliers = {
      [:power_multiplier, 1.5, _INTL("The evil aura powered up the attack!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[GHOST].include?(type)
      },
      [:power_multiplier, 1.5, _INTL("Boo!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[ASTONISH].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("Spooky scary skeletons!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[BONECLUB BONERUSH BONEMERANG].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("Spooky scary skeletons!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[SHADOWBONE].include?(move.id)
      },
      [:power_multiplier, 1.5, _INTL("Will-o'-wisps joined the attack...")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[FIRESPIN FLAMEBURST FLAMECHARGE INFERNO BURNINGJEALOUSY BITTERBLADE].include?(move.id)
      },
      [:power_multiplier, 1.3, _INTL("The field is changing!")] => proc { |user, target, numTargets, move, type, power, mults|
        next true if %i[JUDGMENT ORIGINPULSE PURIFY SACREDFIRE DAZZLINGGLEAM FLASH].include?(move.id)
      },
    }

    @effects[:move_second_type] = proc { |effectiveness, move, moveType, defType, user, target|
      next :GHOST if %i[FIRESPIN FLAMEBURST FLAMECHARGE INFERNO BURNINGJEALOUSY BITTERBLADE].include?(move.id)
    }

    @effects[:switch_in] = proc { |battler| # effects when a pkmn switches in
      if battler.hasActiveAbility?(:RATTLED) && battler.pbCanRaiseStatStage?(:SPEED)
        @battle.pbDisplay(_INTL("{1} is scared! It's speed was boosted.", battler.pbThis, @name))
        battler.pbRaiseStatStage(:SPEED, 1, nil)
      end
      if battler.hasActiveAbility?(:SHADOWTAG)
        battler.eachOpposing do |opp|
          next if opp.fainted?
          itemName = opp.item ? opp.item.name : _INTL("no item")
          @battle.pbDisplay(_INTL("{1}'s Shadow Tag detected that {2} has {3}!", battler.pbThis, opp.pbThis(true), itemName))
        end
      end
    }

    @effects[:EOR_field_battler] = proc { |battler|
      if battler.hasActiveAbility?(:WANDERINGSPIRIT) && battler.pbCanLowerStatStage?(:SPEED)
        @battle.pbDisplay(_INTL("A wandering spirit shall wander forever.", battler.pbThis, @name))
        battler.pbLowerStatStage(:SPEED, 1, nil)
      end
      if battler.asleep? && !battler.pbHasType?(:GHOST)
        battler.pbReduceHP(battler.totalhp / 16, false)
        @battle.pbDisplay(_INTL("{1} is tormented by nightmares!", battler.pbThis))
      end
    }

    @effects[:no_charging] = proc { |user, move|
      next true if %i[PHANTOMFORCE SHADOWFORCE].include?(move.id) && user.grounded?
    }

    @effects[:accuracy_modify] = proc { |user, target, move, modifiers, type|
      modifiers[:base_accuracy] *= 1.5 if %i[HYPNOSIS].include?(move.id)
      modifiers[:base_accuracy] *= 1.06 if %i[WILLOWISP].include?(move.id)
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
      if %i[MAGICPOWDER].include?(move.id)
        targets.each do |target|
          next unless target.pbCanSleep?(user, false, move)
          target.pbSleep(_INTL("{1} was put to sleep by the magic powder!", target.pbThis))
        end
      end
      if %i[LICK].include?(move.id)
        targets.each do |target|
          next unless target.pbCanParalyze?(user, false, move)
          target.pbParalyze
        end
      end
 if %i[BITTERMALICE].include?(move.id)
        targets.each do |target|
          next if target.fainted?
          if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, user)
            target.pbLowerStatStage(:SPECIAL_ATTACK, 1, user)
          end
        end
      end
      # Secret Power may inflict Curse
      if %i[SECRETPOWER].include?(move.id)
        targets.each do |target|
          next if target.fainted?
          if @battle.pbRandom(100) < 30 # 30% chance
            target.effects[PBEffects::Curse] = true
            @battle.pbDisplay(_INTL("{1} was cursed!", target.pbThis))
          end
        end
      end
      # Ominous Wind now has a 20% chance to boost all stats
      if %i[OMINOUSWIND].include?(move.id)
        if @battle.pbRandom(100) < 20
          user.pbRaiseStatStage(:ATTACK, 1, user) if user.pbCanRaiseStatStage?(:ATTACK, user)
          user.pbRaiseStatStage(:DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:DEFENSE, user)
          user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user)
          user.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user)
          user.pbRaiseStatStage(:SPEED, 1, user) if user.pbCanRaiseStatStage?(:SPEED, user)
        end
      end
      # Scary Face lowers the target's Speed by 4 stages
      if %i[SCARYFACE].include?(move.id)
        targets.each do |target|
          next if target.fainted?
          if target.pbCanLowerStatStage?(:SPEED, user)
            # Already lowers 2, so we add 2 more
            target.pbLowerStatStage(:SPEED, 2, user)
          end
        end
      end
    }

    @effects[:change_effectiveness] = proc { |effectiveness, move, moveType, defType, user, target|
      if target.pbHasType?(:NORMAL) && moveType == :GHOST
        next Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
      if target.pbHasType?(:GHOST) && move.id == :SPIRITBREAK
        next Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
    }

      @effects[:on_battler_faint] = proc { |battler, fainted_by|
      if battler.hasActiveAbility?(:CURSEDBODY) && fainted_by && fainted_by.opposes?(battler)
        last_move = fainted_by.lastMoveUsed
        if last_move && fainted_by.pbHasMove?(last_move)
          move_index = fainted_by.moves.find_index { |m| m.id == last_move }
          if move_index && fainted_by.moves[move_index].pp > 0
            fainted_by.moves[move_index].pp = 0
            @battle.pbDisplay(_INTL("{1}'s {2} was disabled by Cursed Body!", fainted_by.pbThis, fainted_by.moves[move_index].name))
          end
        end
      end
    }

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[JUDGMENT ORIGINPULSE PURIFY SACREDFIRE].include?(move.id)
    @battle.create_new_field(:blessed, Battle::Field::INFINITE_FIELD_DURATION) # Needs to be changed to Crystal Cavern when I add that field
  end
}

    @effects[:end_of_move] = proc { |user, targets, move, numHits| # threr is no difference between this and :end_of_move_universal, just separate it for different uses
    if %i[DAZZLINGGLEAM FLASH].include?(move.id)
    @battle.create_new_field(:forest, Battle::Field::INFINITE_FIELD_DURATION) # Needs to be changed to Crystal Cavern when I add that field
  end
}

    # Power Spot increases power of partner's moves by 1.5x
    @effects[:ability_power_boost] = proc { |user, target, move, mults|
      if user.hasActiveAbility?(:POWERSPOT)
        user.eachAlly do |ally|
          if ally.index != user.index
            mults[:power_multiplier] *= 1.5
            next true
          end
        end
      end
    }

    # Destiny Bond no longer fails when used consecutively
    @effects[:move_always_succeeds] = proc { |user, move|
      next true if move.id == :DESTINYBOND
    }

    # Modify move damage calculations
    @effects[:damage_calc_modify] = proc { |user, target, move, type, baseDmg, multipliers|
      # Night Shade deals 1.5x the user's level
      if move.id == :NIGHTSHADE
        next (user.level * 1.5).floor
      end
      # Infernal Parade doubles in power regardless of status
      if move.id == :INFERNALPARADE
        multipliers[:power_multiplier] *= 2
      end
    }

    # Fire Spin deals 1/6 max HP damage each turn (instead of 1/8)
    @effects[:trapping_damage_modify] = proc { |user, target, move|
      if move.id == :FIRESPIN
        next target.totalhp / 6
      end
    }

    # Fire Spin and Mean Look target both opponents in doubles
    @effects[:move_target_modify] = proc { |user, move|
      if %i[FIRESPIN MEANLOOK].include?(move.id) && @battle.pbSideSize(0) > 1
        next :AllNearFoes
      end
    }

    # Curse when used by Ghost type uses only 25% HP
    @effects[:curse_hp_cost] = proc { |user|
      if user.pbHasType?(:GHOST)
        next (user.totalhp / 4).floor
      end
    }

    # Nightmare deals 33% max HP damage each turn
    @effects[:nightmare_damage] = proc { |battler|
      next (battler.totalhp / 3).floor
    }

    # Spite now depletes 6 PP
    @effects[:spite_pp_loss] = proc { |user, target|
      next 6
    }

  end
end

Battle::Field.register(:haunted, {
  :trainer_name => [],
  :environment  => [],
  :map_id       => [],
  :edge_type    => [],
})

# **Ghost-type attacks deal neutral damage to Normal-types. #
# **Sleeping non Ghost-type Pokémon take 1/16 max HP damage at the end of each turn. #
# Cursed Body always activates upon fainting. #
# Power Spot the power of partner's moves by 1.5x. #
# Shadow Tag additionally Frisks the opponent#
# Bitter Malice additionally reduces the target's Special Attack by 1 stage. #
# Curse, when used by a Ghost type, uses only 25% of the user's HP. #
# Destiny Bond no longer fails when used consecutively.
# Fire Spin deals 1/6 max HP damage each turn.
# Fire Spin and Mean Look target both opponents in doubles.
# Infernal Parade doubles in power regardless of status.
# *Night Shade now deals damage equal to 1.5x the user's level.
# Nightmare deals 33% max HP damage each turn.
# *Ominous Wind now has a 20% chance to boost all stats.
# Scary Face lowers the target's Speed by 4 stages.
# Spirit Break now deals super effective damage to Ghost-types.
# Spite now depletes 6 PP.
# Secret Power may inflict Curse. #

# Transitions to Other Fields
# Any move in this section inherently gains a 1.3x damage boost if it changes the field, unless noted otherwise.
#This field will transform into Blessed Field if any of the moves Judgement, Origin Pulse, Purify, or Sacred Fire are used.
#The evil spirits have been exorcised!
#This field will be terminated if either of the moves Dazzling Gleam or Flash are used.
#The evil spirits have been forced back!
