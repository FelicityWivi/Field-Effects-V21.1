
#===============================================================================
# Heals user by 1/2 of its max HP, or 2/3 of its max HP in a sandstorm. (Shore Up)
#===============================================================================
class Battle::Move::HealUserDependingOnSandstorm < Battle::Move::HealingMove
  def pbHealAmount(user)
    if %i[water murkwater].any?{|f| @battle.is_field?(f)} && user.pbCanRaiseStatStage?(:DEFENSE, user, self)
      user.pbRaiseStatStage(:DEFENSE, 2, user)
    end
    return (user.totalhp) if %i[beach].any?{|f| @battle.is_field?(f)}
    return (user.totalhp * 2 / 3.0).round if (user.effectiveWeather == :Sandstorm ||
                                              %i[beach].any?{|f| @battle.is_field?(f)})
    return (user.totalhp / 2.0).round
  end
end

#===============================================================================
# The user and its allies gain 25% of their total HP. (Life Dew)
#===============================================================================
class Battle::Move::HealUserAndAlliesQuarterOfTotalHP < Battle::Move
  def healingMove?; return true; end

  def pbMoveFailed?(user, targets)
    if @battle.allSameSideBattlers(user).none? { |b| b.canHeal? }
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return !target.canHeal?
  end

  def pbEffectGeneral(user)
    if %i[water].any?{|f| @battle.is_field?(f)} && !user.effects[PBEffects::AquaRing]
      user.effects[PBEffects::AquaRing] = true
      choice = user.pbDirectOpposing
      @battle.pbAnimation(:AQUARING, user, choice)
      @battle.pbDisplay(_INTL("{1} surrounded itself with a veil of water!", user.pbThis))
    end
  end

  def pbEffectAgainstTarget(user, target)
    target.pbRecoverHP(target.totalhp / 4)
    @battle.pbDisplay(_INTL("{1}'s HP was restored.", target.pbThis))
  end
end
