
  def pbMoveFailed?(user, targets)
    if %i[water].any?{|f| @battle.is_field?(f)}
      @battle.pbDisplay(_INTL("...The spikes sank into the water and vanished!"))
      return true
    end
    if user.pbOpposingSide.effects[PBEffects::Spikes] >= 3
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbMoveFailed?(user, targets)
    if %i[water].any?{|f| @battle.is_field?(f)}
      @battle.pbDisplay(_INTL("...The spikes sank into the water and vanished!"))
      return true
    end
    if user.pbOpposingSide.effects[PBEffects::ToxicSpikes] >= 2
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
