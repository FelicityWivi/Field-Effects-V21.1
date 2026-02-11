
  def pbRecoverHPFromDrain(amt, target, msg = nil)
    if target.hasActiveAbility?(:LIQUIDOOZE, true)
      @battle.pbShowAbilitySplash(target)
      amt = (amt * 2).floor if %i[murkwater corruptcave wasteland].any? {|f| is_field?(f)}
      pbReduceHP(amt)
      @battle.pbDisplay(_INTL("{1} sucked up the liquid ooze!", pbThis))
      @battle.pbHideAbilitySplash(target)
      pbItemHPHealCheck
    else
      msg = _INTL("{1} had its energy drained!", target.pbThis) if nil_or_empty?(msg)
      @battle.pbDisplay(msg)
      if canHeal?
        amt = (amt * 1.3).floor if hasActiveItem?(:BIGROOT) && @battle.field.defaultTerrain != :Grassy
        amt = (amt * 1.6).floor if hasActiveItem?(:BIGROOT) && @battle.field.defaultTerrain == :Grassy
        pbRecoverHP(amt)
      end
    end
  end

  def pbCheckFormOnWeatherChange(ability_changed = false)
    return if fainted? || @effects[PBEffects::Transform]
    # Castform - Forecast
    if isSpecies?(:CASTFORM)
      if hasActiveAbility?(:FORECAST)
        newForm = 0
        case effectiveWeather
        when :Sun, :HarshSun   then newForm = 1
        when :Rain, :HeavyRain then newForm = 2
        when :Hail             then newForm = 3
        end
        if @form != newForm
          @battle.pbShowAbilitySplash(self, true)
          @battle.pbHideAbilitySplash(self)
          pbChangeForm(newForm, _INTL("{1} transformed!", pbThis))
        end
      else
        pbChangeForm(0, _INTL("{1} transformed!", pbThis))
      end
    end
    # Cherrim - Flower Gift
    if isSpecies?(:CHERRIM)
      if hasActiveAbility?(:FLOWERGIFT)
        newForm = 0
        newForm = 1 if [:Sun, :HarshSun].include?(effectiveWeather)
        if @form != newForm
          @battle.pbShowAbilitySplash(self, true)
          @battle.pbHideAbilitySplash(self)
          pbChangeForm(newForm, _INTL("{1} transformed!", pbThis))
        end
      else
        pbChangeForm(0, _INTL("{1} transformed!", pbThis))
      end
    end
    # Eiscue - Ice Face
    if !ability_changed && isSpecies?(:EISCUE) && self.ability == :ICEFACE &&
       @form == 1 && effectiveWeather == :Hail
      @canRestoreIceFace = true   # Changed form at end of round
    end
        # Eiscue - Ice Face on Volcanic/Infernal Field/Volcanic Top Field
    if isSpecies?(:EISCUE) && %i[volcanic infernal volcanotop].any?{|f| is_field?(f)} && !self.ability_triggered?
      if hasActiveAbility?(:ICEFACE)
        newForm = 1
        if @form != newForm
          @battle.pbShowAbilitySplash(self, true)
          @battle.pbHideAbilitySplash(self)
          pbChangeForm(newForm, _INTL("{1} transformed!", pbThis))
        end
      else
        pbChangeForm(0, _INTL("{1} transformed!", pbThis))
      end
    end
  end


  # Checks the Pokémon's form and updates it if necessary. Used for when a
  # Pokémon enters battle (endOfRound=false) and at the end of each round
  # (endOfRound=true).
  def pbCheckForm(endOfRound = false)
    return if fainted? || @effects[PBEffects::Transform]
    # Form changes upon entering battle and when the weather changes
    pbCheckFormOnWeatherChange if !endOfRound
    # Darmanitan - Zen Mode
    if isSpecies?(:DARMANITAN) && self.ability == :ZENMODE
      if (@hp <= @totalhp / 2 || %i[psychic beach].any?{|f| is_field?(f)})
        if @form.even?
          @battle.pbShowAbilitySplash(self, true)
          @battle.pbHideAbilitySplash(self)
          pbChangeForm(@form + 1, _INTL("{1} triggered!", abilityName))
        end
      elsif @form.odd?
        @battle.pbShowAbilitySplash(self, true)
        @battle.pbHideAbilitySplash(self)
        pbChangeForm(@form - 1, _INTL("{1} triggered!", abilityName))
      end
    end
        # Livnan Camerupt - Dormant Mode
        if isSpecies?(:CAMERUPT) && self.ability == :DORMANTMODE
          if @hp <= @totalhp / 2 || %i[volcanic infernal volcanictop].any?{|f| is_field?(f)}
            if @form.odd?
              @battle.pbShowAbilitySplash(self, true)
              @battle.pbHideAbilitySplash(self)
              pbChangeForm(@form + 1, _INTL("{1} triggered!", abilityName))
            end
          elsif @form.even?
            @battle.pbShowAbilitySplash(self, true)
            @battle.pbHideAbilitySplash(self)
            pbChangeForm(@form - 1, _INTL("{1} triggered!", abilityName))
          end
        end
    # Minior - Shields Down
    if isSpecies?(:MINIOR) && self.ability == :SHIELDSDOWN
      if @hp > @totalhp / 2   # Turn into Meteor form
        newForm = (@form >= 7) ? @form - 7 : @form
        if @form != newForm
          @battle.pbShowAbilitySplash(self, true)
          @battle.pbHideAbilitySplash(self)
          pbChangeForm(newForm, _INTL("{1} deactivated!", abilityName))
        end
      elsif @form < 7   # Turn into Core form
        @battle.pbShowAbilitySplash(self, true)
        @battle.pbHideAbilitySplash(self)
        pbChangeForm(@form + 7, _INTL("{1} activated!", abilityName))
      end
    end
    # Wishiwashi - Schooling
    if isSpecies?(:WISHIWASHI) && self.ability == :SCHOOLING
      if @level >= 20 && @hp > @totalhp / 4 || @battle.apply_field_effect(:ability_activation, self, @ability_id, endOfRound).include?(@ability_id)
        if @form != 1
          @battle.pbShowAbilitySplash(self, true)
          @battle.pbHideAbilitySplash(self)
          pbChangeForm(1, _INTL("{1} formed a school!", pbThis))
        end
      elsif @form != 0
        @battle.pbShowAbilitySplash(self, true)
        @battle.pbHideAbilitySplash(self)
        pbChangeForm(0, _INTL("{1} stopped schooling!", pbThis))
      end
    end
    # Zygarde - Power Construct
    if isSpecies?(:ZYGARDE) && self.ability == :POWERCONSTRUCT && endOfRound &&
       @hp <= @totalhp / 2 && @form < 2   # Turn into Complete Forme
      newForm = @form + 2
      @battle.pbDisplay(_INTL("You sense the presence of many!"))
      @battle.pbShowAbilitySplash(self, true)
      @battle.pbHideAbilitySplash(self)
      pbChangeForm(newForm, _INTL("{1} transformed into its Complete Forme!", pbThis))
    end
    # Morpeko - Hunger Switch
    if isSpecies?(:MORPEKO) && hasActiveAbility?(:HUNGERSWITCH) && endOfRound &&
      %i[frozendimensional].any?{|f| is_field?(f)}
      # Intentionally doesn't show the ability splash or a message
      newForm = (@form + 1) % 2
      pbChangeForm(newForm, nil)
    end
    # Morpeko - Always in Hangry Mode on Frozen Dimensional Field
    if isSpecies?(:MORPEKO) && self.ability == :HUNGERSWITCH &&
      %i[frozendimensional].any?{|f| is_field?(f)}
      if @form.even?
          @battle.pbShowAbilitySplash(self, true)
          pbChangeForm(@form + 1, _INTL("{1} triggered!", abilityName))
          @battle.pbHideAbilitySplash(self)
      end
    end
    # Silvally - Always Dark-type form on Blessed Field
    if isSpecies?(:SILVALLY) && self.ability == :RKSSYSTEM &&
      %i[blessed].any?{|f| is_field?(f)}
      if @form != 17
          @battle.pbShowAbilitySplash(self, true)
          pbChangeForm(17, _INTL("A false god holds no power here...",))
          @battle.pbHideAbilitySplash(self)
      end
    end
        # Palafin - Always in Hero Mode on listed fields below
    if isSpecies?(:PALAFIN) && self.ability == :ZEROTOHERO &&
    %i[water beach underwater murkwater].any?{|f| is_field?(f)}
    if @form != 1
         pbChangeForm(1, nil)
    end
    end
 end

