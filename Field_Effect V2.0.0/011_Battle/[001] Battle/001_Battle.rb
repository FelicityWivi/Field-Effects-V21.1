class Battle

  #=============================================================================
  # Weather
  #=============================================================================
  def defaultWeather=(value)
    @field.defaultWeather  = value
    @field.weather         = value
    @field.weatherDuration = -1
  end

  # Returns the effective weather (note that weather effects can be negated)
  def pbWeather
    return :None if allBattlers.any? { |b| b.hasActiveAbility?([:CLOUDNINE, :AIRLOCK]) }
    return @field.weather
  end

  # Used for causing weather by a move or by an ability.
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
    return if @field.weather == newWeather
    @field.weather = newWeather
    duration = (fixedDuration) ? 5 : -1
    if duration > 0 && user && (user.itemActive? || %i[sky].any?{|f| is_field?(f)})
      duration = Battle::ItemEffects.triggerWeatherExtender(user.item, @field.weather,
                                                            duration, user, self)
    end
    if duration > 0 && %i[icy snowymountain frozendimensional].any?{|f| is_field?(f)} && @field.weather == :Hail
      duration = 8
    end
    if duration > 0 && %i[desert beach].any?{|f| is_field?(f)} && [:Sandstorm].include?(@field.weather)
      duration = 8
    end
      if duration > 0 && %i[desert mountain snowymountain].any?{|f| is_field?(f)} && [:Sun].include?(@field.weather)
      duration = 8
    end
    
    ret = apply_field_effect(:block_weather, newWeather, user, fixedDuration)
    return if ret

    @field.weatherDuration = duration
    weather_data = GameData::BattleWeather.try_get(@field.weather)
    pbCommonAnimation(weather_data.animation) if showAnim && weather_data
    pbHideAbilitySplash(user) if user
    case @field.weather
    when :Sun         then pbDisplay(_INTL("The sunlight turned harsh!"))
    when :Rain        then pbDisplay(_INTL("It started to rain!"))
    when :Sandstorm   then pbDisplay(_INTL("A sandstorm brewed!"))
    when :Hail        then pbDisplay(_INTL("It started to hail!"))
    when :HarshSun    then pbDisplay(_INTL("The sunlight turned extremely harsh!"))
    when :HeavyRain   then pbDisplay(_INTL("A heavy rain began to fall!"))
    when :StrongWinds then pbDisplay(_INTL("Mysterious strong winds are protecting Flying-type Pokémon!"))
    when :ShadowSky   then pbDisplay(_INTL("A shadow sky appeared!"))
    end
    # Check for end of primordial weather, and weather-triggered form changes
    allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
    pbEndPrimordialWeather
  end

  def pbEndPrimordialWeather
    oldWeather = @field.weather
    # End Primordial Sea, Desolate Land, Delta Stream
    case @field.weather
    when :HarshSun
      if !pbCheckGlobalAbility(:DESOLATELAND)
        @field.weather = :None
        pbDisplay("The harsh sunlight faded!")
      end
    when :HeavyRain
      if !pbCheckGlobalAbility(:PRIMORDIALSEA)
        @field.weather = :None
        pbDisplay("The heavy rain has lifted!")
      end
    when :StrongWinds
      if !pbCheckGlobalAbility(:DELTASTREAM)
        @field.weather = :None
        pbDisplay("The mysterious air current has dissipated!")
      end
    end
    if @field.weather != oldWeather
      # Check for form changes caused by the weather changing
      allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
      # Start up the default weather
      pbStartWeather(nil, @field.defaultWeather) if @field.defaultWeather != :None
    end
  end

  def pbStartWeatherAbility(new_weather, battler, ignore_primal = false)
    return if !ignore_primal && [:HarshSun, :HeavyRain, :StrongWinds].include?(@field.weather)
    return if @field.weather == new_weather
    pbShowAbilitySplash(battler)
    if !Scene::USE_ABILITY_SPLASH
      pbDisplay(_INTL("{1}'s {2} activated!", battler.pbThis, battler.abilityName))
    end
    fixed_duration = false
    fixed_duration = true if Settings::FIXED_DURATION_WEATHER_FROM_ABILITY &&
                             ![:HarshSun, :HeavyRain, :StrongWinds].include?(new_weather)
    pbStartWeather(battler, new_weather, fixed_duration)
    # NOTE: The ability splash is hidden again in def pbStartWeather.
  end
end