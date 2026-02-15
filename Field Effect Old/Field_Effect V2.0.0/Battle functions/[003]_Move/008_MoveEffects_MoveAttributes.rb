
#===============================================================================
# User takes recoil damage equal to 1/3 of the damage this move dealt.
#===============================================================================
class Battle::Move::RecoilThirdOfDamageDealt < Battle::Move::RecoilMove
  def pbRecoilDamage(user, target)
    if %i[beach water].any?{|f| @battle.is_field?(f)} && id == :WAVECRASH
      return (target.damageState.totalHPLost / 4.0).round
    else
      return (target.damageState.totalHPLost / 3.0).round
    end
  end
end
