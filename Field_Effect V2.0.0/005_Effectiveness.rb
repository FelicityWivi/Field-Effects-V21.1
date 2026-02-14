#===============================================================================
# Effectiveness Icons on Move Buttons (Top-Right Corner)
#===============================================================================

module Battle::EffectivenessIcons
  def effectiveness_indicator(move, target)
    return nil if !move || !target
    return nil unless move.damagingMove?
    target_types = target.pbTypes(true)
    effectiveness = Effectiveness.calculate(move.type, *target_types)
    return :super   if Effectiveness.super_effective?(effectiveness)
    return :resist  if Effectiveness.not_very_effective?(effectiveness)
    return :immune  if Effectiveness.ineffective?(effectiveness)
    return nil
  end
end

#===============================================================================
# Prepend into Fight Menu
#===============================================================================
module Battle::Scene::FightMenu_EffectivenessIcons
  include Battle::EffectivenessIcons

  def refreshButtonNames
    super
    return if !@overlay || !@overlay.bitmap

    begin
      imgPos = []
      icon_width  = 26
      padding     = 8
      left_shift  = 10   # how far left to move the icon

      moves  = @battler.moves
      target = @battler.battle.battlers.find { |b| b && b.opposes?(@battler) && !b.fainted? }

      @buttons.each_with_index do |button, i|
        next if !@visibility["button_#{i}"]
        move = moves[i]
        next if !move

        # Top-right corner, shifted left
        x = button.x - self.x + button.src_rect.width - icon_width - padding - left_shift
        y = button.y - self.y + padding

        eff = effectiveness_indicator(move, target)
        next if !eff

        eff_file = case eff
        when :super
          "Graphics/UI/Battle/type_super"
        when :resist
          "Graphics/UI/Battle/type_resist"
        when :immune
          "Graphics/UI/Battle/type_immune"
        else
          nil
        end

        if eff_file && pbResolveBitmap(eff_file)
          imgPos.push([eff_file, x, y])
        end
      end

      pbDrawImagePositions(@overlay.bitmap, imgPos) if imgPos.any?
    rescue => e
      puts "Effectiveness indicator error: #{e.message}" if $DEBUG
    end
  end
end

#===============================================================================
# Apply prepend
#===============================================================================
Battle::Scene::FightMenu.prepend(
  Battle::Scene::FightMenu_EffectivenessIcons
)