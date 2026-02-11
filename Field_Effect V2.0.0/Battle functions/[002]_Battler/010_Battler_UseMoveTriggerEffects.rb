
  def pbEffectsAfterMove(user, targets, move, numHits)
    # Defrost
    if move.damagingMove?
      targets.each do |b|
        next if b.damageState.unaffected || b.damageState.substitute
        next if b.status != :FROZEN
        # NOTE: Non-Fire-type moves that thaw the user will also thaw the
        #       target (in Gen 6+).
        if move.calcType == :FIRE || (Settings::MECHANICS_GENERATION >= 6 && move.thawsUser?)
          b.pbCureStatus
        end
      end
    end
    # Destiny Bond
    # NOTE: Although Destiny Bond is similar to Grudge, they don't apply at
    #       the same time (however, Destiny Bond does check whether it's going
    #       to trigger at the same time as Grudge).
    if user.effects[PBEffects::DestinyBondTarget] >= 0 && !user.fainted?
      dbName = @battle.battlers[user.effects[PBEffects::DestinyBondTarget]].pbThis
      @battle.pbDisplay(_INTL("{1} took its attacker down with it!", dbName))
      user.pbReduceHP(user.hp, false)
      user.pbItemHPHealCheck
      user.pbFaint
      @battle.pbJudgeCheckpoint(user)
    end
    # User's ability
    if user.abilityActive?
      Battle::AbilityEffects.triggerOnEndOfUsingMove(user.ability, user, targets, move, @battle)
    end
    if !user.fainted? && !user.effects[PBEffects::Transform] &&
       !@battle.pbAllFainted?(user.idxOpposingSide)
      # Greninja - Battle Bond
      if user.isSpecies?(:GRENINJA) && user.ability == :BATTLEBOND &&
         !@battle.battleBond[user.index & 1][user.pokemonIndex]
        numFainted = 0
        targets.each { |b| numFainted += 1 if b.damageState.fainted }
        if numFainted > 0 && user.form == 1
          @battle.battleBond[user.index & 1][user.pokemonIndex] = true
          @battle.pbDisplay(_INTL("{1} became fully charged due to its bond with its Trainer!", user.pbThis))
          @battle.pbShowAbilitySplash(user, true)
          @battle.pbHideAbilitySplash(user)
          user.pbChangeForm(2, _INTL("{1} became Ash-Greninja!", user.pbThis))
        end
      end
      # Cramorant = Gulp Missile
      if user.isSpecies?(:CRAMORANT) && user.ability == :GULPMISSILE && user.form == 0 &&
         ((move.id == :SURF && numHits > 0) || (move.id == :DIVE && move.chargingTurn))
        # NOTE: Intentionally no ability splash or message here.
        if %i[factory].any?{|f| is_field?(f)}
          user.pbChangeForm((user.hp > user.totalhp / 2) ? 2 : 2, nil)
        elsif %i[water].any?{|f| is_field?(f)}
          user.pbChangeForm((user.hp > user.totalhp / 2) ? 1 : 1, nil)
        else
         user.pbChangeForm((user.hp > user.totalhp / 2) ? 1 : 2, nil)
        end
      end
    end
    # Room Service
    if move.function_code == "StartSlowerBattlersActFirst" && @battle.field.effects[PBEffects::TrickRoom] > 0
      @battle.allBattlers.each do |b|
        next if !b.hasActiveItem?(:ROOMSERVICE)
        next if !b.pbCanLowerStatStage?(:SPEED)
        @battle.pbCommonAnimation("UseItem", b)
        b.pbLowerStatStage(:SPEED, 1, nil)
        b.pbConsumeItem
      end
    end
    # Consume user's Gem
    if user.effects[PBEffects::GemConsumed]
      # NOTE: The consume animation and message for Gems are shown immediately
      #       after the move's animation, but the item is only consumed now.
      user.pbConsumeItem
    end
    switched_battlers = []   # Indices of battlers that were switched out somehow
    # Target switching caused by Roar, Whirlwind, Circle Throw, Dragon Tail
    move.pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    # Target's item, user's item, target's ability (all negated by Sheer Force)
    if !(user.hasActiveAbility?(:SHEERFORCE) && move.addlEffect > 0)
      pbEffectsAfterMove2(user, targets, move, numHits, switched_battlers)
    end
    # Some move effects that need to happen here, i.e. user switching caused by
    # U-turn/Volt Switch/Baton Pass/Parting Shot, Relic Song's form changing,
    # Fling/Natural Gift consuming item.
    if !switched_battlers.include?(user.index)
      move.pbEndOfMoveUsageEffect(user, targets, numHits, switched_battlers)
    end
    # User's ability/item that switches the user out (all negated by Sheer Force)
    if !(user.hasActiveAbility?(:SHEERFORCE) && move.addlEffect > 0)
      pbEffectsAfterMove3(user, targets, move, numHits, switched_battlers)
    end
    if numHits > 0
      @battle.allBattlers.each { |b| b.pbItemEndOfMoveCheck }
    end
  end
