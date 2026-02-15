
  def pbFlinchChance(user, target)
    return 0 if flinchingMove?
    return 0 if target.hasActiveAbility?(:SHIELDDUST) && !@battle.moldBreaker
    ret = 0
    if user.hasActiveAbility?(:STENCH, true) && !%i[city backalley].any?{|f| is_field?(f)} ||
       user.hasActiveItem?([:KINGSROCK, :RAZORFANG], true)
      ret = 10
    end
    if user.hasActiveAbility?(:STENCH, true) && !%i[city backalley].any?{|f| is_field?(f)}
      ret = 20
    end
    ret *= 2 if user.hasActiveAbility?(:SERENEGRACE) ||
    user.pbOwnSide.effects[PBEffects::Rainbow] > 0
    return ret
  end

