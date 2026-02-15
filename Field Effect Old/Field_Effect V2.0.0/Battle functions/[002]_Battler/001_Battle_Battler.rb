
  def takesHailDamage?
    return false if !takesIndirectDamage?
    return false if pbHasType?(:ICE)
    return false if inTwoTurnAttack?("TwoTurnAttackInvulnerableUnderground",
                                     "TwoTurnAttackInvulnerableUnderwater")
    return false if hasActiveAbility?([:OVERCOAT, :ICEBODY, :SNOWCLOAK, :SNOWWARNING])
    return false if hasActiveItem?(:SAFETYGOGGLES)
    return false if pbHasType?(:STEEL) && %i[fairytale].any?{|f| is_field?(f)}
    return true
  end
