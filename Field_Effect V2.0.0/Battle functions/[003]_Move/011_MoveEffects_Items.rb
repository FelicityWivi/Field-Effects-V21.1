#===============================================================================
# User steals the target's item, if the user has none itself. (Covet, Thief)
# Items stolen from wild Pokémon are kept after the battle.
#===============================================================================
class Battle::Move::UserTakesTargetItem < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    if Settings::MECHANICS_GENERATION >= 6 && %i[backalley].any?{|f| @battle.is_field?(f)}
       target.item && !target.unlosableItem?(target.item)
      # NOTE: Damage is still boosted even if target has Sticky Hold or a
      #       substitute.
      baseDmg = (baseDmg * 2.0).round
    end
    return baseDmg
  end
  
  def pbEffectAfterAllHits(user, target)
    return if user.wild?   # Wild Pokémon can't thieve
    return if user.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if !target.item || user.item
    return if target.unlosableItem?(target.item)
    return if user.unlosableItem?(target.item)
    return if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
    itemName = target.itemName
    user.item = target.item
    # Permanently steal the item from wild Pokémon
    if target.wild? && !user.initialItem && target.item == target.initialItem
      user.setInitialItem(target.item)
      target.pbRemoveItem
    else
      target.pbRemoveItem(false)
    end
    @battle.pbDisplay(_INTL("{1} stole {2}'s {3}!", user.pbThis, target.pbThis(true), itemName))
    user.pbHeldItemTriggerCheck
  end
end

#===============================================================================
# User gives its item to the target. The item remains given after wild battles.
# (Bestow)
#===============================================================================
class Battle::Move::TargetTakesUserItem < Battle::Move
  def ignoresSubstitute?(user)
    return true if Settings::MECHANICS_GENERATION >= 6
    return super
  end

  def pbMoveFailed?(user, targets)
    if !user.item || user.unlosableItem?(user.item)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    if target.item || target.unlosableItem?(user.item)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    itemName = user.itemName
    target.item = user.item
    # Permanently steal the item from wild Pokémon
    if user.wild? && !target.initialItem && user.item == user.initialItem
      target.setInitialItem(user.item)
      user.pbRemoveItem
    else
      user.pbRemoveItem(false)
    end
    @battle.pbDisplay(_INTL("{1} received {2} from {3}!", target.pbThis, itemName, user.pbThis(true)))
    target.pbHeldItemTriggerCheck
  end
end

#===============================================================================
# User and target swap items. They remain swapped after wild battles.
# (Switcheroo, Trick)
#===============================================================================
class Battle::Move::UserTargetSwapItems < Battle::Move
  def pbMoveFailed?(user, targets)
    if user.wild?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    if !user.item && !target.item
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.unlosableItem?(target.item) ||
       target.unlosableItem?(user.item) ||
       user.unlosableItem?(user.item) ||
       user.unlosableItem?(target.item)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("But it failed to affect {1}!", target.pbThis(true)))
        else
          @battle.pbDisplay(_INTL("But it failed to affect {1} because of its {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    oldUserItem = user.item
    oldUserItemName = user.itemName
    oldTargetItem = target.item
    oldTargetItemName = target.itemName
    user.item                             = oldTargetItem
    user.effects[PBEffects::ChoiceBand]   = nil if !user.hasActiveAbility?(:GORILLATACTICS)
    user.effects[PBEffects::Unburden]     = (!user.item && oldUserItem) if user.hasActiveAbility?(:UNBURDEN)
    target.item                           = oldUserItem
    target.effects[PBEffects::ChoiceBand] = nil if !target.hasActiveAbility?(:GORILLATACTICS)
    target.effects[PBEffects::Unburden]   = (!target.item && oldTargetItem) if target.hasActiveAbility?(:UNBURDEN)
    # Permanently steal the item from wild Pokémon
    if target.wild? && !user.initialItem && oldTargetItem == target.initialItem
      user.setInitialItem(oldTargetItem)
    end
    @battle.pbDisplay(_INTL("{1} switched items with its opponent!", user.pbThis))
    @battle.pbDisplay(_INTL("{1} obtained {2}.", user.pbThis, oldTargetItemName)) if oldTargetItem
    @battle.pbDisplay(_INTL("{1} obtained {2}.", target.pbThis, oldUserItemName)) if oldUserItem
    user.pbHeldItemTriggerCheck
    target.pbHeldItemTriggerCheck
    if %i[backalley].any?{|f| @battle.is_field?(f)}
      case id
      when :SWITCHEROO
        if user.pbCanRaiseStatStage?(:ATTACK, user)
           user.pbRaiseStatStage(:ATTACK, 1, user)
        end
        if target.pbCanLowerStatStage?(:ATTACK, target)
           target.pbLowerStatStage(:ATTACK, 1, target)
        end
      when :TRICK
        if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user)
           user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user)
        end
        if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, target)
           target.pbLowerStatStage(:SPECIAL_ATTACK, 1, target)
        end
      end
    end
  end
end

#===============================================================================
# Negates the effect and usability of the target's held item for the rest of the
# battle (even if it is switched out). Fails if the target doesn't have a held
# item, the item is unlosable, the target has Sticky Hold, or the target is
# behind a substitute. (Corrosive Gas)
#===============================================================================
class Battle::Move::CorrodeTargetItem < Battle::Move
  def canMagicCoat?; return true; end

  def pbFailsAgainstTarget?(user, target, show_message)
    if !target.item || target.unlosableItem?(target.item) ||
       target.effects[PBEffects::Substitute] > 0
      @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if show_message
      return true
    end
    if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} is unaffected because of its {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    if @battle.corrosiveGas[target.index % 2][target.pokemonIndex]
      @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if show_message
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    @battle.corrosiveGas[target.index % 2][target.pokemonIndex] = true
    @battle.pbDisplay(_INTL("{1} corroded {2}'s {3}!",
                            user.pbThis, target.pbThis(true), target.itemName))
    if %i[city backalley].any?{|f| @battle.is_field?(f)}
      showAnim = true
      if target.pbCanLowerStatStage?(:ATTACK, target, self)
        showAnim = false if target.pbLowerStatStage(:ATTACK, 1, target, showAnim)
      end
      if target.pbCanLowerStatStage?(:DEFENSE, target, self)
        showAnim = false if target.pbLowerStatStage(:DEFENSE, 1, target, showAnim)
      end
      if target.pbCanLowerStatStage?(:SPECIAL_ATTACK, target, self)
        showAnim = false if target.pbLowerStatStage(:SPECIAL_ATTACK, 1, target, showAnim)
      end
      if target.pbCanLowerStatStage?(:SPECIAL_DEFENSE, target, self)
        showAnim = false if target.pbLowerStatStage(:SPECIAL_DEFENSE, 1, target, showAnim)
      end
      if target.pbCanLowerStatStage?(:SPEED, target, self)
        target.pbLowerStatStage(:SPEED, 1, target, showAnim)
      end
    end
    if %i[corrosive].any?{|f| @battle.is_field?(f)}
      showAnim = true
      if target.pbCanLowerStatStage?(:DEFENSE, target, self)
        showAnim = false if target.pbLowerStatStage(:DEFENSE, 1, target, showAnim)
      end
      if target.pbCanLowerStatStage?(:SPECIAL_DEFENSE, target, self)
        showAnim = false if target.pbLowerStatStage(:SPECIAL_DEFENSE, 1, target, showAnim)
      end
    end
  end
end
