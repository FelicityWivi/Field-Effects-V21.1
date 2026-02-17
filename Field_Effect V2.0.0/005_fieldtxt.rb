FIELDEFFECTS = {

:INDOOR => {
	:name => "",
	:fieldMessage => [
		""
	],
	:graphic => ["Indoor"],
	:secretPower => "TRIATTACK",
	:naturePower => :TRIATTACK,
	:mimicry => :NORMAL,	
	:damageMods => { #damage modifiers for specific moves, written as multipliers (e.g. 1.5 => [:TACKLE])
	},				# a damage mod of 0 denotes the move failing on this field
	:accuracyMods => { #accuracy chance for specific moves, written as percent chance to hit (e.g. 80 => [:TOXIC])
	},				# a accuracy mod of 0 denotes the move always hitting on this field
	:moveMessages => {	# the field message displayed when using a move (written as "message" => [move1,move2....] )
	},
	:typeMods => {	# secondary types applied to moves (written as "type" => [move1,move2,....])
	},
	:typeAddOns => { # secondary types applied to entire types (written as SecondaryTypeSymbol => [typesymbol1,typesymbol2,...])
	},
	:moveEffects => { # arbitrary commands that are evaled after a move executes but before fieldchanges are checked
	},	#evaled in "fieldEffectAfterMove" method in the battle class
	:typeBoosts => { # damage multipliers applied to all moves of a specific type (e.g. 1.3 => [:FIRE,:WATER])
	},
	:typeMessages => {	# field message shown when using a move of the denoted type ("message" => [type1,type2,....])
	},
	:typeCondition => {	# conditions for the type boost written as a string of conditions that are evaled later
	},	#evaled as a function on the move class
	:typeEffects => { # arbitrary commands attached to all moves of a type that are evaled after a move executes but before fieldchanges are checked
	},	#evaled in "fieldEffectAfterMove" method in the battle class
	:changeCondition => { # conditions for a field change written as a string of conditions that are evaled later
	},	#evaled as a function on the move class
	:fieldChange => {  # moves that change this field to a different field (Fieldsymbol => [move1,move2,....])
	},
	:dontChangeBackup => [],	#list of moves which store the current field as backup when changing the field
	:changeMessage => {	# message displayed when changing a field to a different one ("message" => [move1,move2,....])
	},
	:statusMods => [],	#list of non-damaging moves boosted by the field in different ways, for field highlighting
	:changeEffects => {#additional effects that happen when specific moves change a field (such as corrisive mist explosion)
	},	#evaled in "fieldEffectAfterMove" method in the battle class
	:seed => {		# the seed effects on this field
		:seedtype => nil,	# which seed is activated
		:effect => nil,		# which battler effect is being changed if any
		:duration => nil,	# duration of the extra effect
		:message => nil,	# message shown with the seeds boost
		:animation => nil,	# animation associated with the effect
		:stats => {			# statchanges caused by the seed
		},
	},
	:overlay => {		# effects of this field as an overlay instead of a full field #Rejuv
		:damageMods => { #damage modifiers for specific moves, written as multipliers (e.g. 1.5 => [:TACKLE])
		},				# a damage mod of 0 denotes the move failing on this field
		:typeMods => {	# secondary types applied to moves (written as "type" => [move1,move2,....])
		},
		:moveMessages => {	# the field message displayed when using a move (written as "message" => [move1,move2....] )
		},
		:typeBoosts => { # damage multipliers applied to all moves of a specific type (e.g. 1.3 => [:FIRE,:WATER])
		},
		:typeMessages => {	# field message shown when using a move of the denoted type ("message" => [type1,type2,....])
		},
		:typeCondition => {	# conditions for the type boost written as a string of conditions that are evaled later
		},	#evaled as a function on the move class
		:statusMods => [],	#list of non-damaging moves boosted by the field in different ways, for field highlighting
	},
},
:ELECTERRAIN => {
	:name => "Electric Terrain",
	:fieldMessage => [
		"The field is hyper-charged!"
	],
	:graphic => ["Electric"],
	:secretPower => "SHOCKWAVE",
	:naturePower => :THUNDERBOLT,
	:mimicry => :ELECTRIC,
	:damageMods => {
		1.5 => [:EXPLOSION, :SELFDESTRUCT, :HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS, :WINDBOLTSTORM],
		2.0 => [:MAGNETBOMB],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The explosion became hyper-charged!" => [:EXPLOSION, :SELFDESTRUCT],
		"The attack became hyper-charged!" => [:HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS, :WINDBOLTSTORM],
		"The attack powered up!" => [:MAGNETBOMB],
	},
	:typeMods => {
		:ELECTRIC => [:EXPLOSION, :SELFDESTRUCT, :SMACKDOWN, :SURF, :MUDDYWATER, :HURRICANE, :THOUSANDARROWS, :HYDROVORTEX],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ELECTRIC],
	},
	:typeMessages => {
		"The Electric Terrain strengthened the attack!" => [:ELECTRIC],
	},
	:typeCondition => {
		:ELECTRIC => "!attacker.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:MUDSPORT, :TECTONICRAGE],
	},
	:dontChangeBackup => [:MUDSPORT],
	:changeMessage => {
		 "The hyper-charged terrain shorted out!" => [:MUDSPORT, :TECTONICRAGE],
	},
	:statusMods => [:CHARGE, :EERIEIMPULSE, :MAGNETRISE, :SPIKES, :ELECTRIFY],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :Charge,
		:duration => 2,
		:message => "{1} began charging power!",
		:animation => :CHARGE,
		:stats => {
			:SPEED => 1,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:EXPLOSION, :SELFDESTRUCT, :HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS],
			2.0 => [:MAGNETBOMB],
		},
		:typeMods => {
			:ELECTRIC => [:EXPLOSION, :SELFDESTRUCT, :SMACKDOWN, :SURF, :MUDDYWATER, :HURRICANE, :THOUSANDARROWS],
		},
		:moveMessages => {
			"The explosion became hyper-charged!" => [:EXPLOSION, :SELFDESTRUCT],
			"The attack became hyper-charged!" => [:HURRICANE, :SURF, :SMACKDOWN, :MUDDYWATER, :THOUSANDARROWS],
			"The attack powered up!" => [:MAGNETBOMB],
		},
		:typeBoosts => {
			1.5 => [:ELECTRIC],
		},
		:typeMessages => {
			"The Electric Terrain strengthened the attack!" => [:ELECTRIC],
		},
		:typeCondition => {
			:ELECTRIC => "!attacker.isAirborne?",
		},
		:statusMods => [:MAGNETRISE],
	},
},
:GRASSY => {
	:name => "Grassy Terrain",
	:fieldMessage => [
		"The field is in full bloom."
	],
	:graphic => ["Grassy"],
	:secretPower => "SEEDBOMB",
	:naturePower => :ENERGYBALL,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER, :GRASSKNOT],
		0.5 => [:MUDDYWATER, :SURF, :EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
	},
	:accuracyMods => {
		80 => [:GRASSWHISTLE],
	},
	:moveMessages => {
		"The wind picked up strength from the field!" => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER],
		"The grass strengthened the attack!" => [:GRASSKNOT],
		"The grass softened the attack..." => [:MUDDYWATER, :SURF, :EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SURF],
		"@battle.field_counters.counter += 2" => [:MUDDYWATER],
	},
	:typeBoosts => {
		1.5 => [:GRASS, :FIRE],
	},
	:typeMessages => {
		"The Grassy Terrain strengthened the attack!" => [:GRASS],
		"The grass below caught flame!" => [:FIRE],
	},
	:typeCondition => {
		:GRASS => "!attacker.isAirborne?",
		:FIRE => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {
		:SWAMP => "@battle.field_counters.counter > 2",
	},
	:fieldChange => {
		:CORROSIVE => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		:SWAMP => [:SURF, :MUDDYWATER],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The grassy terrain was corroded!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		 "The grassy terrain became marshy!" => [:SURF, :MUDDYWATER],
	},
	:statusMods => [:COIL, :GROWTH, :FLORALHEALING, :SYNTHESIS, :WORRYSEED, :INGRAIN, :GRASSWHISTLE, :LEECHSEED, :COTTONSPORE],
	:changeEffects => {},
	:eorHeal => {
		:fraction => 16,
		:condition => "!battler.airborne?",
		:message => "{1} was healed by the Grassy Terrain!"
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:DEFENSE => 1,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER],
		},
		:typeMods => {
		},
		:moveMessages => {
			"The wind picked up strength from the field!" => [:FAIRYWIND, :SILVERWIND, :OMINOUSWIND, :ICYWIND, :RAZORWIND, :GUST, :TWISTER],
		},
		:typeBoosts => {
			1.5 => [:GRASS],
		},
		:typeMessages => {
			"The Grassy Terrain strengthened the attack!" => [:GRASS],
		},
		:typeCondition => {
			:GRASS => "!attacker.isAirborne?",
		},
		:statusMods => [],
	},
},
:MISTY => {
	:name => "Misty Terrain",
	:fieldMessage => [
		"Mist settles on the field."
	],
	:graphic => ["Misty"],
	:secretPower => "MISTBALL",
	:naturePower => :MISTBALL,
	:mimicry => :FAIRY,
	:damageMods => {
		1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM, :SPRINGTIDESTORM],
		0.5 => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE],
		0 => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN],
	},
	:accuracyMods => {
		100 => [:SWEETKISS],
	},
	:moveMessages => {
		"The mist's energy strengthened the attack!" => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM, :SPRINGTIDESTORM],
		"The mist softened the attack..." => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE],
		"The damp mist prevented the explosion..." => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:CLEARSMOG, :SMOG, :POISONGAS],
		"@battle.field_counters.counter = 2" => [:ACIDDOWNPOUR],
	},
	:typeBoosts => {
		1.5 => [:FAIRY],
		0.5 => [:DRAGON],
	},
	:typeMessages => {
		"The Misty Terrain strengthened the attack!" => [:FAIRY],
		"The Misty Terrain weakened the attack!" => [:DRAGON],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CORROSIVEMIST => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:INDOOR => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		:CORROSIVEMIST => [:CLEARSMOG, :SMOG, :POISONGAS, :ACIDDOWNPOUR]
	},
	:dontChangeBackup => [:CLEARSMOG, :SMOG, :POISONGAS, :ACIDDOWNPOUR],
	:changeMessage => {
		 "The mist was blown away!" => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		 "The mist was corroded!" => [:CLEARSMOG, :SMOG, :POISONGAS, :ACIDDOWNPOUR],
	},
	:statusMods => [:COSMICPOWER, :AROMATICMIST, :SWEETSCENT, :WISH, :AQUARING],
	:changeEffects => {},
	:eorHeal => {
		:fraction => 16,
		:condition => "!battler.airborne?",
		:message => "{1} was soothed by the Misty Terrain!"
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :Wish,
		:duration => 2,
		:message => "A wish was made for {1}!",
		:animation => :WISH,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM],
		},
		:typeMods => {
		},
		:moveMessages => {
			"The mist's energy strengthened the attack!" => [:MYSTICALFIRE, :MAGICALLEAF, :DOOMDUMMY, :ICYWIND, :MISTBALL, :AURASPHERE, :STEAMERUPTION, :SILVERWIND, :MOONGEISTBEAM, :SMOG, :CLEARSMOG, :STRANGESTEAM],
		},
		:typeBoosts => {
			1.5 => [:FAIRY],
		},
		:typeMessages => {
			"The Misty Terrain strengthened the attack!" => [:FAIRY],
		},
		:typeCondition => {
		},
		:statusMods => [],
	},
},
:VOLCANIC => {
	:name => "Volcanic Field",
	:fieldMessage => [
		"The field is molten!"
	],
	:graphic => ["Volcanic"],
	:secretPower => "FLAMETHROWER",
	:naturePower => :FLAMETHROWER,
	:mimicry => :FIRE,
	:blockedStatuses => [:FROZEN],  # Can't freeze on volcanic field
	:blockedWeather => [:Hail, :Snow],
    :abilityStatBoosts => {
      :MAGMAARMOR => { 
        stat: :DEFENSE, 
        stages: 1, 
        message: "{1}'s Magma Armor hardened its body!" 
      },
      :STEAMENGINE => { 
        stat: :SPEED, 
        stages: 1, 
        message: "{1}'s Steam Engine boosted its speed!" 
      },
    },
    :abilityFormChanges => {
      :EISCUE => {
        :ICEFACE => { form: 1, show_ability: true, message: "{1}'s Ice Face melted!" }
      }
    },
    :moveStatStageMods => {
      :SMOKESCREEN => { stages: 2, message: "The {2} boosted the Smokescreen! {1}'s accuracy greatly fell!" },
    },
    :abilityActivate => {
      :BLAZE      => {},             # passive: fire moves get 1.5x (handled by existing Blaze check)
      :FLAREBOOST => {},             # passive: fire moves get 1.5x when burned
      :FLASHFIRE  => { eor: true, grounded: true },  # EOR: activates Flash Fire boost if grounded
    },
	:healthChanges => [
    {
      grounded: true,
      exclude_types: [:FIRE],
      healing: false,
      damage_type: :FIRE,
      amount: 1/8.0,
      message: "{1} was hurt by the {2}!",
      immune_abilities: [:FLAMEBODY, :FLAREBOOST, :FLASHFIRE, :HEATPROOF, 
                        :MAGMAARMOR, :WATERBUBBLE, :WATERVEIL],
      immune_effects: [PBEffects::AquaRing],
      multiplier_abilities: {
        :FLUFFY => 2.0,
        :GRASSPELT => 2.0,
        :ICEBODY => 2.0,
        :LEAFGUARD => 2.0
      },
      multiplier_effects: {
        PBEffects::TarShot => 2.0
      }
    }
  ],
	:damageMods => {
		2.0 => [:SMOG, :CLEARSMOG],
		1.5 => [:SMACKDOWN, :THOUSANDARROWS, :ROCKSLIDE, :INFERNALPARADE],
		0 => [:HAIL],
	},
	:accuracyMods => {
		100 => [:WILLOWISP],
	},
	:moveMessages => {
		"The flames spread from the attack!" => [:SMOG, :CLEARSMOG, :INFERNALPARADE],
		"{1} was knocked into the flames!" => [:SMACKDOWN, :THOUSANDARROWS, :ROCKSLIDE],
		"The hail melted away." => [:HAIL],
	},
	:typeMods => {
		:FIRE => [:SMACKDOWN, :SMOG, :CLEARSMOG, :THOUSANDARROWS, :ROCKSLIDE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE],
		0.5 => [:GRASS, :ICE],
	},
	:typeMessages => {
		"The blaze amplified the attack!" => [:FIRE],
		"The blaze softened the attack..." => [:GRASS, :ICE],
	},
	:typeCondition => {
		:FIRE => "!attacker.isAirborne?",
		:GRASS => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:CAVE => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE, :WATERSPORT, :SURF, :MUDDYWATER, :WATERSPOUT, :WATERPLEDGE, :SPARKLINGARIA, :SLUDGEWAVE, :SANDTOMB, :CONTINENTALCRUSH, :HYDROVORTEX, :OCEANICOPERETTA],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The grime snuffed out the flame!" => [:SLUDGEWAVE],
		 "The wind snuffed out the flame!" => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		 "The water snuffed out the flame!" => [:WATERSPORT, :SURF, :MUDDYWATER, :WATERSPOUT, :WATERPLEDGE, :SPARKLINGARIA, :HYDROVORTEX, :OCEANICOPERETTA],
		 "The sand snuffed out the flame!" => [:SANDTOMB, :CONTINENTALCRUSH],
	},
	:statusMods => [:WILLOWISP, :SMOKESCREEN],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :MultiTurnAttack,
		:duration => :FIRESPIN,
		:message => "{1} was trapped in the vortex!",
		:animation => :FIRESPIN,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
			:SPEED => 1,
		},
	},
},
:SWAMP => {
	:name => "Swamp Field",
	:fieldMessage => [
		"The field is swamped."
	],
	:graphic => ["Swamp"],
	:secretPower => "MUDDYWATER",
	:naturePower => :MUDDYWATER,
	:mimicry => :WATER,
	:damageMods => {
		1.5 => [:MUDBOMB, :MUDSHOT, :MUDSLAP, :MUDDYWATER, :SLUDGEWAVE, :GUNKSHOT, :BRINE, :SMACKDOWN, :THOUSANDARROWS, :HYDROVORTEX, :SAVAGESPINOUT],
		0.25 => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		0 => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN]
	},
	:accuracyMods => {
		100 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"The murk strengthened the attack!" => [:MUDBOMB, :MUDSHOT, :MUDSLAP, :MUDDYWATER, :SLUDGEWAVE, :GUNKSHOT, :BRINE, :SMACKDOWN, :THOUSANDARROWS, :HYDROVORTEX],
		"The attack dissipated in the soggy ground..." => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		"The dampness prevents the explosion!" => [:SELFDESTRUCT, :EXPLOSION, :MINDBLOWN],
		"There are bugs EVERYWHERE!" => [:SAVAGESPINOUT],
	},
	:typeMods => {
		:WATER => [:SMACKDOWN, :THOUSANDARROWS],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.3 => [:BUG,:WATER,:GRASS],
		0.8 => [:FIRE],
	},
	:typeMessages => {
		"Bugs are swarming everywhere!" => [:BUG],
		"The dampness strengthened the attack!" => [:WATER],
		"Thick mangroves line the area!" => [:GRASS],
		"The dampness weakened the flame..." => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER, :AQUARING, :STRENGTHSAP, :LEECHSEED, :STRINGSHOT, :SPIDERWEB],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1}'s body became clear!",
		:animation => :ROCKPOLISH,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:RAINBOW => {
	:name => "Rainbow Field",
	:fieldMessage => [
		"What does it mean?"
	],
	:graphic => ["Rainbow"],
	:secretPower => "AURORABEAM",
	:naturePower => :AURORABEAM,
	:mimicry => :DRAGON,
	:damageMods => {
		1.5 => [:SILVERWIND, :MYSTICALFIRE, :DRAGONPULSE, :TRIATTACK, :SACREDFIRE, :FIREPLEDGE, :WATERPLEDGE, :GRASSPLEDGE, :AURORABEAM, :JUDGMENT, :RELICSONG, :HIDDENPOWER, :SECRETPOWER, :WEATHERBALL, :MISTBALL, :HEARTSTAMP, :MOONBLAST, :ZENHEADBUTT, :SPARKLINGARIA, :FLEURCANNON, :PRISMATICLASER, :TWINKLETACKLE, :OCEANICOPERETTA, :SOLARBEAM, :SOLARBLADE, :DAZZLINGGLEAM, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		0.5 => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE, :NEVERENDINGNIGHTMARE],
		0 => [:NIGHTMARE]
	},
	:accuracyMods => {},
	:moveMessages => {
		"The attack was rainbow-charged!" => [:SILVERWIND, :MYSTICALFIRE, :DRAGONPULSE, :TRIATTACK, :SACREDFIRE, :FIREPLEDGE, :WATERPLEDGE, :GRASSPLEDGE, :AURORABEAM, :JUDGMENT, :RELICSONG, :HIDDENPOWER, :SECRETPOWER, :WEATHERBALL, :MISTBALL, :HEARTSTAMP, :MOONBLAST, :ZENHEADBUTT, :SPARKLINGARIA, :FLEURCANNON, :PRISMATICLASER, :TWINKLETACKLE, :OCEANICOPERETTA, :SOLARBEAM, :SOLARBLADE, :DAZZLINGGLEAM, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		"The rainbow softened the attack..." => [:DARKPULSE, :SHADOWBALL, :NIGHTDAZE, :NEVERENDINGNIGHTMARE],
		"The rainbow ensures good dreams." => [:NIGHTMARE]
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:NORMAL],
	},
	:typeMessages => {
		"The rainbow energized the attack!" => [:NORMAL],
	},
	:typeCondition => {
		:NORMAL => "self.pbIsSpecial?(type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:LIGHTTHATBURNSTHESKY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The rainbow was consumed!" => [:LIGHTTHATBURNSTHESKY],
	},
	:statusMods => [:COSMICPOWER, :MEDITATE, :WISH, :LIFEDEW, :AURORAVEIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Wish,
		:duration => 2,
		:message => "A wish was made for {1}!",
		:animation => :WISH,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
	:overlay => {
		:damageMods => {
		},
		:typeMods => {
		},
		:moveMessages => {
		},
		:typeBoosts => {
		},
		:typeMessages => {
		},
		:typeCondition => {
		},
		:statusMods => [],
	},
},
:CORROSIVE => {
	:name => "Corrosive Field",
	:fieldMessage => [
		"The field is corrupted!"
	],
	:graphic => ["Poison"],
	:secretPower => "ACID",
	:naturePower => :ACIDSPRAY,
	:mimicry => :POISON,
	:damageMods => {
		1.5 => [:SMACKDOWN, :MUDSLAP, :MUDSHOT, :MUDBOMB, :MUDDYWATER, :WHIRLPOOL, :THOUSANDARROWS, :APPLEACID],
		2.0 => [:ACID, :ACIDSPRAY, :GRASSKNOT, :SNAPTRAP],
	},
	:accuracyMods => {
		100 => [:POISONPOWDER, :SLEEPPOWDER, :STUNSPORE, :TOXIC],
	},
	:moveMessages => {
		"The corrosion strengthened the attack!" => [:SMACKDOWN, :MUDSLAP, :MUDSHOT, :MUDBOMB, :MUDDYWATER, :WHIRLPOOL, :THOUSANDARROWS, :APPLEACID, :ACID, :ACIDSPRAY, :GRASSKNOT, :SNAPTRAP],
	},
	:typeMods => {
		:POISON => [:SMACKDOWN, :MUDSLAP, :MUDSHOT, :MUDDYWATER, :WHIRLPOOL, :MUDBOMB, :THOUSANDARROWS, :APPLEACID],
	},
	:typeAddOns => {
		:POISON => [:GRASS],
	},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:GRASSY => [:SEEDFLARE, :PURIFY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The polluted field was purified!" => [:SEEDFLARE, :PURIFY],
	},
	:statusMods => [:ACIDARMOR, :POISONPOWDER, :SLEEPPOWDER, :STUNSPORE, :TOXIC, :VENOMDRENCH],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :Protect,
		:duration => :BanefulBunker,
		:message => "The Telluric Seed shielded {1} against damage!",
		:animation => :BANEFULBUNKER,
		:stats => {
		},
	},
},
:CORROSIVEMIST => {
	:name => "Corrosive Mist Field",
	:fieldMessage => [
		"Corrosive mist settles on the field!"
	],
	:graphic => ["CorrosiveMist"],
	:secretPower => "ACIDSPRAY",
	:naturePower => :VENOSHOCK,
	:mimicry => :POISON,
	:damageMods => {
		1.5 => [:BUBBLEBEAM, :ACIDSPRAY, :BUBBLE, :SMOG, :CLEARSMOG, :SPARKLINGARIA],
	},
	:accuracyMods => {
		100 => [:TOXIC],
	},
	:moveMessages => {
		"The poison strengthened the attack!" => [:BUBBLEBEAM, :ACIDSPRAY, :BUBBLE, :SMOG, :CLEARSMOG, :SPARKLINGARIA, :APPLEACID],
	},
	:typeMods => {
		:POISON => [:BUBBLE, :BUBBLEBEAM, :ENERGYBALL, :SPARKLINGARIA, :APPLEACID],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE],
	},
	:typeMessages => {
		"The toxic mist caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE, :HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :SELFDESTRUCT, :EXPLOSION],
		:MISTY => [:SEEDFLARE],
		:CORROSIVE => [:GRAVITY],
	},
	:dontChangeBackup => [:GRAVITY],
	:changeMessage => {
		 "The mist was blown away!" => [:WHIRLWIND, :GUST, :RAZORWIND, :DEFOG, :HURRICANE, :TWISTER, :TAILWIND, :SUPERSONICSKYSTRIKE],
		 "The polluted mist was purified!" => [:SEEDFLARE],
		 "The toxic mist collected on the ground!" => [:GRAVITY],
	},
	:statusMods => [:ACIDARMOR, :SMOKESCREEN, :VENOMDRENCH, :TOXIC],
	:changeEffects => {
		"@battle.mistExplosion" => [:HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :SELFDESTRUCT, :EXPLOSION],
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} was badly poisoned!",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
		},
	},
},
:DESERT => {
	:name => "Desert Field",
	:fieldMessage => [
		"The field is rife with sand."
	],
	:graphic => ["Desert","Desert2","Desert3","DesertNight","DesertEve"],
	:secretPower => "SANDTOMB",
	:naturePower => :SANDTOMB,
	:mimicry => :GROUND,
	:damageMods => {
		1.5 => [:NEEDLEARM, :PINMISSILE, :DIG, :SANDTOMB, :HEATWAVE, :THOUSANDWAVES, :BURNUP, :SEARINGSUNRAZESMASH, :SOLARBLADE, :SOLARBEAM, :SCALD, :STEAMERUPTION, :SANDSEARSTORM,:BONECLUB, :BONERUSH, :BONEMERANG, :SHADOWBONE,:SCORCHINGSANDS],
		0 => [:SOAK, :AQUARING, :LIFEDEW],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The desert strengthened the attack!" => [:NEEDLEARM, :PINMISSILE, :DIG, :SANDTOMB, :HEATWAVE, :THOUSANDWAVES, :BURNUP, :SEARINGSUNRAZESMASH, :SOLARBLADE, :SOLARBEAM, :SCALD, :STEAMERUPTION, :SANDSEARSTORM, :SCORCHINGSANDS],
		"The lifeless desert strengthened the attack!" => [:BONECLUB, :BONERUSH, :BONEMERANG, :SHADOWBONE],
		"The desert is too dry..." => [:SOAK, :AQUARING, :LIFEDEW],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		0.5 => [:WATER, :ELECTRIC],
	},
	:typeMessages => {
		"The desert softened the attack..." => [:WATER, :ELECTRIC],
	},
	:typeCondition => {
		:WATER => "!attacker.isAirborne? && self.move!=:SCALD && self.move!=:STEAMERUPTION",
		:ELECTRIC => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:SANDSTORM, :SUNNYDAY, :SANDATTACK, :SHOREUP],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :MultiTurnAttack,
		:duration => :SANDTOMB,
		:message => "{1} was trapped by Sand Tomb!",
		:animation => :SANDTOMB,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
			:SPEED => 1,
		},
	},
},
:ICY => {
	:name => "Icy Field",
	:fieldMessage => [
		"The field is covered in ice."
	],
	:graphic => ["Icy"],
	:secretPower => "ICESHARD",
	:naturePower => :ICEBEAM,
	:mimicry => :ICE,
	:damageMods => {
		1.5 => [:BITTERMALICE],
		0.5 => [:SCALD, :STEAMERUPTION],
	},
	:abilityMods => {
    :REFRIGERATE => { multiplier: 1.5 },
	},
	:accuracyMods => {},
	:moveMessages => {
		"The cold strengthened the attack!" => [:BITTERMALICE],
		"The cold softened the attack..." => [:SCALD, :STEAMERUPTION],
	},
	:typeMods => {},
	:typeAddOns => {
		:ICE => [:ROCK],
	},
	:moveEffects => {
		"@battle.iceSpikes" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		"@battle.field_counters.counter += 1" => [:SCALD],
		"@battle.field_counters.counter = 2" => [:STEAMERUPTION],
	},
	:typeBoosts => {
		1.5 => [:ICE],
		0.5 => [:FIRE],
	},
	:typeMessages => {
		"The cold strengthened the attack!" => [:ICE],
		"The cold softened the attack..." => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:INDOOR => "[:WATERSURFACE,:MURKWATERSURFACE].include?(@battle.field.backup) && (self.move!=:DIVE || @battle.field_counters.counter == 3)",
		:WATERSURFACE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:INDOOR => [:DIVE, :EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		:CAVE => [:HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		:WATERSURFACE => [:SCALD, :STEAMERUPTION],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The ice was broken from underneath!" => [:DIVE],
		"The quake broke up the ice and revealed the water beneath!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		"The ice melted away!" => [:HEATWAVE, :ERUPTION, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		"The hot water melted the ice!" => [:SCALD, :STEAMERUPTION],
	},
	:statusMods => [:HAIL, :AURORAVEIL],
    :statusDamageMods => {
    :BURN => 0.5,     # Halves burn damage (1/16 -> 1/32)
    },
    :moveStatBoosts => [
    {
      grounded: true,
      conditions: [:physical, :contact, :priority],
      stat: :SPEED,
      stages: 1,
      message: "{1} gained momentum on the ice!"
    },
    {
      grounded: true,
      moves: [:DEFENSECURL, :LUNGE, :ROLLOUT, :STEAMROLLER],
      stat: :SPEED,
      stages: 1,
      message: "{1} gained momentum on the ice!"
    }
  ],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} was hurt by icy Spikes!",
		:animation => nil,
		:stats => {
			:SPEED => 2,
		},
	},
},
:ROCKY => {
	:name => "Rocky Field",
	:fieldMessage => [
		"The field is littered with rocks."
	],
	:graphic => ["Rocky"],
	:secretPower => "ROCKTHROW",
	:naturePower => :ROCKSMASH,
	:mimicry => :ROCK,
	:damageMods => {
		1.5 => [:ROCKCLIMB, :STRENGTH, :MAGNITUDE, :EARTHQUAKE, :BULLDOZE, :ACCELEROCK],
		2.0 => [:ROCKSMASH],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The rocks strengthened the attack!" => [:ROCKCLIMB, :STRENGTH, :MAGNITUDE, :EARTHQUAKE, :BULLDOZE, :ACCELEROCK],
		"SMASH'D!" => [:ROCKSMASH],
	},
	:typeMods => {
		:ROCK => [:ROCKCLIMB, :EARTHQUAKE, :MAGNITUDE, :STRENGTH, :BULLDOZE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ROCK],
	},
	:typeMessages => {
		"The field strengthened the attack!" => [:ROCK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:ROCKPOLISH, :SANDSTORM, :STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} was hurt by Stealth Rocks!",
		:animation => nil,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FOREST => {
	:name => "Forest Field",
	:fieldMessage => [
		"The field is abound with trees."
	],
	:graphic => ["Forest"],
	:secretPower => "WOODHAMMER",
	:naturePower => :WOODHAMMER,
	:mimicry => :BUG,
	:damageMods => {
		0.5 => [:SURF, :MUDDYWATER],
		1.5 => [:GRAVAPPLE, :ATTACKORDER, :ELECTROWEB, :SLASH, :AIRSLASH, :FURYCUTTER, :AIRCUTTER, :PSYCHOCUT, :BREAKINGSWIPE],
		2.0 => [:CUT],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The forest softened the attack..." => [:SURF, :MUDDYWATER],
		"They're coming out of the woodwork!" => [:ATTACKORDER],
		"Gossamer and arbor strengthened the attack!" => [:ELECTROWEB],
		"The apple did not fall far from the tree" => [:GRAVAPPLE],
		"A tree slammed down!" => [:CUT, :SLASH, :AIRSLASH, :FURYCUTTER, :AIRCUTTER, :PSYCHOCUT, :BREAKINGSWIPE],
	},
	:typeMods => {
		:GRASS => [:CUT, :SLASH, :AIRSLASH, :FURYCUTTER, :AIRCUTTER, :PSYCHOCUT, :BREAKINGSWIPE],
	},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SURF],
		"@battle.field_counters.counter += 2" => [:MUDDYWATER],
	},
	:typeBoosts => {
		1.5 => [:BUG, :GRASS],
	},
	:typeMessages => {
		"The attack spread throughout the forest!" => [:BUG],
		"The forestry strengthened the attack!" => [:GRASS],
	},
	:typeCondition => {
		:BUG => "self.pbIsSpecial?(type)",
	},
	:typeEffects => {},
	:changeCondition => {
		:SWAMP => "@battle.field_counters.counter > 2",
	},
	:fieldChange => {
		:SWAMP => [:SURF, :MUDDYWATER],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The forest became marshy!" => [:SURF, :MUDDYWATER],
	},
	:statusMods => [:STICKYWEB, :DEFENDORDER, :GROWTH, :STRENGTHSAP, :HEALORDER, :NATURESMADNESS, :FORESTSCURSE],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :Protect,
		:duration => :SpikyShield,
		:message => "The Telluric Seed shielded {1} against damage!",
		:animation => :SPIKYSHIELD,
		:stats => {
		},
	},
},
:VOLCANICTOP => {
	:name => "Volcanic Top",
	:fieldMessage => [
		"The mountain top is super-heated!"
	],
	:graphic => ["Volcanictop"],
	:secretPower => "FLAMEBURST",
	:naturePower => :ERUPTION,
	:mimicry => :FIRE,
	:damageMods => {
		1.5 => [:OMINOUSWIND, :SILVERWIND, :RAZORWIND, :ICYWIND, :GUST, :TWISTER, :SMOG, :CLEARSMOG, :PRECIPICEBLADES, :THUNDER, :SCALD, :STEAMERUPTION, :INFERNALPARADE],
		1.3 => [:ERUPTION, :HEATWAVE, :MAGMASTORM, :LAVAPLUME],
		0.625 => [:SURF, :MUDDYWATER, :WATERPLEDGE, :WATERSPOUT, :HYDROPUMP, :SPARKLINGARIA, :HYDROVORTEX, :OCEANICOPERETTA],
		0 => [:HAIL]
	},
	:accuracyMods => {
		0 => [:THUNDER]
	},
	:moveMessages => {
		"The field super-heated the attack!" => [:SCALD, :STEAMERUPTION,:OMINOUSWIND, :SILVERWIND, :RAZORWIND, :ICYWIND, :GUST, :TWISTER, :SMOG, :CLEARSMOG, :PRECIPICEBLADES],
		"The field powers up the flaming attacks!" => [:ERUPTION, :HEATWAVE, :MAGMASTORM, :LAVAPLUME, :INFERNALPARADE],
		"The field powers up the attack!" => [:THUNDER],
		"The hail melted away." => [:HAIL],
	},
	:typeMods => {
		:FIRE => [:OMINOUSWIND, :SILVERWIND, :RAZORWIND, :ICYWIND, :GUST, :TWISTER, :SMOG, :CLEARSMOG, :PRECIPICEBLADES, :EXPLOSION, :SELFDESTRUCT, :DIG, :DIVE, :SEISMICTOSS, :MAGNETBOMB, :EGGBOMB],
	},
	:typeAddOns => {
		:FIRE => [:ROCK],
	},
	:moveEffects => {
		"@battle.fieldAccuracyDrop" => [:SURF, :MUDDYWATER, :WATERPLEDGE, :WATERSPOUT, :SPARKLINGARIA, :OCEANICOPERETTA, :HYDROVORTEX, :HYDROPUMP, :WATERSPORT],
		"@battle.eruptionChecker" => [:BULLDOZE, :EARTHQUAKE, :MAGNITUDE, :ERUPTION, :PRECIPICEBLADES, :LAVAPLUME, :EARTHPOWER],
	},
	:typeBoosts => {
		0.5 => [:ICE],
		0.9 => [:WATER],
		1.2 => [:FIRE],
		1.3 => [:FLYING],
	},
	:typeMessages => {
		"The extreme heat softened the attack..." => [:ICE, :WATER],
		"The attack was super-heated!" => [:FIRE],
		"The mountain strengthened the attack!!" => [:FLYING],
	},
	:typeCondition => {
		:WATER => "self.move!=:SCALD && self.move!=:STEAMERUPTION",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:SKY => [:FLY, :BOUNCE,],
		:MOUNTAIN => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The battle was taken to the skies!" => [:FLY, :BOUNCE,],
		 "The field cooled off!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:statusMods => [:TAILWIND, :STEALTROCK, :SMOKESCREEN, :POISONGAS],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :ShellTrap,
		:duration => true,
		:message => "{1} primed a trap!",
		:animation => :SHELLTRAP,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:FACTORY => {
	:name => "Factory Field",
	:fieldMessage => [
		"Machines whir in the background."
	],
	:graphic => ["Factory"],
	:secretPower => "MAGNETBOMB",
	:naturePower => :GEARGRIND,
	:mimicry => :STEEL,
	:damageMods => {
		1.5 => [:STEAMROLLER, :TECHNOBLAST, :ULTRAMEGADEATH],
		2.0 => [:FLASHCANNON, :GYROBALL, :MAGNETBOMB, :GEARGRIND, :DOUBLEIRONBASH],
	},
	:accuracyMods => {},
	:moveMessages => {
		"ATTACK SEQUENCE UPDATE." => [:STEAMROLLER, :TECHNOBLAST, :ULTRAMEGADEATH],
		"ATTACK SEQUENCE INITIATE." => [:FLASHCANNON, :GYROBALL, :MAGNETBOMB, :GEARGRIND, :DOUBLEIRONBASH],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.2 => [:ELECTRIC],
	},
	:typeMessages => {
		"The attack took energy from the field!" => [:ELECTRIC],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:SHORTCIRCUIT => "!(self.move==:ULTRAMEGADEATH && self.pbIsSpecial?(@type))",
	},
	:fieldChange => {
		:SHORTCIRCUIT => [:AURAWHEEL, :IONDELUGE, :GIGAVOLTHAVOC, :EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :SELFDESTRUCT, :EXPLOSION, :LIGHTTHATBURNSTHESKY, :ULTRAMEGADEATH],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The field was broken!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :SELFDESTRUCT, :EXPLOSION, :ULTRAMEGADEATH],
		 "All the light was consumed!" => [:LIGHTTHATBURNSTHESKY],
		 "The field shorted out!" => [:AURAWHEEL, :IONDELUGE, :GIGAVOLTHAVOC],
	},
	:statusMods => [:AUTOTOMIZE, :IRONDEFENSE, :METALSOUND, :SHIFTGEAR, :MAGNETRISE, :GEARUP, :MAGNETRISE],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :LaserFocus,
		:duration => 1,
		:message => "{1} is focused!",
		:animation => :LASERFOCUS,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:SHORTCIRCUIT => {
	:name => "Short-Circuit Field",
	:fieldMessage => [
		"Bzzt!"
	],
	:graphic => ["ShortCircuit"],
	:secretPower => "ELECTROBALL",
	:naturePower => :DISCHARGE,
	:mimicry => :ELECTRIC,
	:damageMods => {
		1.667 => [:STEELBEAM],
		1.5 => [:DAZZLINGGLEAM, :SURF, :MUDDYWATER, :MAGNETBOMB, :GYROBALL, :FLASHCANNON, :GEARGRIND, :HYDROVORTEX, :ULTRAMEGADEATH],
		1.3 => [:DARKPULSE, :NIGHTDAZE, :NIGHTSLASH, :SHADOWBALL, :SHADOWPUNCH, :SHADOWCLAW, :SHADOWSNEAK, :SHADOWFORCE, :SHADOWBONE, :PHANTOMFORCE],
		0.5 => [:LIGHTTHATBURNSTHESKY],
	},
	:accuracyMods => {
		80 => [:ZAPCANNON],
	},
	:moveMessages => {
		"CHARGING UP!" => [:ULTRAMEGADEATH],
		"Blinding!" => [:DAZZLINGGLEAM, :FLASHCANNON],
		"The attack picked up electricity!" => [:SURF, :MUDDYWATER, :MAGNETBOMB, :GYROBALL, :GEARGRIND, :HYDROVORTEX],
		"The darkness strengthened the attack!" => [:DARKPULSE, :NIGHTDAZE, :NIGHTSLASH, :SHADOWBALL, :SHADOWPUNCH, :SHADOWCLAW, :SHADOWSNEAK, :SHADOWFORCE, :SHADOWBONE, :PHANTOMFORCE],
		"{1} couldn't consume much light..." => [:LIGHTTHATBURNSTHESKY],
	},
	:typeMods => {
		:ELECTRIC => [:SURF, :MUDDYWATER, :MAGNETBOMB, :GYROBALL, :FLASHCANNON, :GEARGRIND, :STEELBEAM],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:FACTORY => "!(self.move==:ULTRAMEGADEATH && self.pbIsPhysical?(@type))",
	},
	:fieldChange => {
		:FACTORY => [:AURAWHEEL, :PARABOLICCHARGE, :WILDCHARGE, :CHARGEBEAM, :IONDELUGE, :GIGAVOLTHAVOC, :ULTRAMEGADEATH],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "SYSTEM ONLINE." => [:AURAWHEEL, :PARABOLICCHARGE, :WILDCHARGE, :CHARGEBEAM, :IONDELUGE, :GIGAVOLTHAVOC, :ULTRAMEGADEATH],
	},
	:statusMods => [:FLASH, :METALSOUND, :MAGNETRISE],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :MagnetRise,
		:duration => 5,
		:message => "{1} levitated with electromagnetism!",
		:animation => :MAGNETRISE,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:WASTELAND => {
	:name => "Wasteland",
	:fieldMessage => [
		"The waste is watching..."
	],
	:graphic => ["Wasteland"],
	:secretPower => "GUNKSHOT",
	:naturePower => :GUNKSHOT,
	:mimicry => :POISON,
	:damageMods => {
		1.5 => [:VINEWHIP, :POWERWHIP, :MUDSLAP, :MUDBOMB, :MUDSHOT],
		0.25 => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		2.0 => [:SPITUP],
		1.2 => [:OCTAZOOKA, :SLUDGE, :GUNKSHOT, :SLUDGEWAVE, :SLUDGEBOMB],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The waste did it for the vine!" => [:VINEWHIP, :POWERWHIP],
		"The waste was added to the attack!" => [:MUDSLAP, :MUDBOMB, :MUDSHOT],
		"Wibble-wibble wobble-wobb..." => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE],
		"BLEAAARGGGGH!" => [:SPITUP],
		"The waste joined the attack!" => [:OCTAZOOKA, :SLUDGE, :GUNKSHOT, :SLUDGEWAVE, :SLUDGEBOMB, :ACIDDOWNPOUR],
	},
	:typeMods => {
		:POISON => [:MUDBOMB, :MUDSLAP, :MUDSHOT],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:SWALLOW, :STEALTHROCK, :SPIKES, :TOXICSPIKES, :STICKYWEB],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
		},
	},
},
:BEACH => {
	:name => "Beach",
	:fieldMessage => [
		"Focus and relax to the sound of crashing waves..."
	],
	:graphic => ["Beach","BeachEve","BeachNight"],
	:secretPower => "MUDSHOT",
	:naturePower => :MEDITATE,
	:mimicry => :GROUND,
	# Weather duration extension - Sandstorm lasts 8 turns instead of 5
	:weatherDuration => {
		:Sandstorm => 8
	},
	:damageMods => {
		1.5 => [:HIDDENPOWER, :BRINE, :SMELLINGSALTS, :CRABHAMMER, :RAZORSHELL, :SHELLSIDEARM, :SHELLTRAP, :SCORCHINGSANDS, :SANDSEARSTORM, :STRENGTH, :LANDSWRATH, :THOUSANDWAVES, :SURF, :MUDDYWATER, :WAVECRASH, :CLANGOROUSSOULBLAZE, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		2.0 => [:MUDSLAP, :MUDSHOT, :MUDBOMB, :SANDTOMB],
		1.3 => [:STOREDPOWER, :ZENHEADBUTT, :FOCUSBLAST, :AURASPHERE, :FOCUSPUNCH],
		1.2 => [:PSYCHIC],
	},
	:accuracyMods => {
		90 => [:FOCUSBLAST],  # Focus Blast accuracy increased to 90%
	},
	:moveMessages => {
		"...And with pure focus!" => [:HIDDENPOWER, :STRENGTH, :CLANGOROUSSOULBLAZE, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
		"The sand strengthened the atttack!" => [:LANDSWRATH, :THOUSANDWAVES, :SANDTOMB, :SCORCHINGSANDS, :SANDSEARSTORM],
		"Surf's up!" => [:SURF, :MUDDYWATER, :WAVECRASH],
		"A shining shell on the beach!" => [:RAZORSHELL, :SHELLSIDEARM, :SHELLTRAP],
		"The salty sea strengthened the attack!" => [:BRINE, :SMELLINGSALTS],
		"Time for crab!" => [:CRABHAMMER],
		"Sand mixed into the attack!" => [:MUDSLAP, :MUDSHOT, :MUDBOMB],
		"...And with full focus...!" => [:STOREDPOWER, :ZENHEADBUTT, :FOCUSBLAST, :FOCUSPUNCH, :AURASPHERE],
		"...And with focus...!" => [:PSYCHIC],
	},
	:typeMods => {
		:PSYCHIC => [:STRENGTH],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	# Lowers accuracy of all battlers by 1 stage after:
	#   - Specific moves (spin/wind/tornado effects stir up ash)
	#   - Special Flying-type moves (gusts stir up the sand)
	:accuracyDropOnMove => {
		:message => "The attack stirred up the ash on the ground!",
		:moves   => [:FIRESPIN, :LEAFTORNADO, :RAZORWIND, :TWISTER, :WHIRLPOOL],
		:types   => { :FLYING => { special_only: true } },
	},
	# Stat stage changes boosted by the field (uses moveStatStageMods system)
	# stages: 2 = move does twice its normal stages
	# stages: 3 = move does three times its normal stages
	:moveStatStageMods => {
		:CALMMIND   => { stages: 2, message: "The Beach deepened {1}'s focus! Both Special stats rose sharply!" },
		:KINESIS    => { stages: 2, message: "The Beach scattered the sand! {1}'s accuracy fell sharply!" },
		:SANDATTACK => { stages: 2, message: "The Beach scattered the sand! {1}'s accuracy fell sharply!" },
		:MEDITATE   => { stages: 3, message: "The Beach sharpened {1}'s focus! Attack rose drastically!" },
	},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:CALMMIND, :KINESIS, :MEDITATE, :SANDATTACK, :SANDSTORM, :PSYCHUP, :FOCUSENERGY, :SHOREUP],
	:changeEffects => {},
	# Abilities always active or modified on beach field
	:abilityActivate => {
		:SANDFORCE => {},  # Rock/Ground/Steel moves boosted (passive via existing handler)
		:SANDRUSH  => {},  # Speed doubled (passive via existing handler)
		:SANDVEIL  => {},  # Evasion boosted (passive) + ignore acc/eva changes (hardcoded)
	},
	# Form changes triggered by field
	:abilityFormChanges => {
		:DARMANITAN => {
			:ZENMODE => { form: 1, show_ability: true, message: "{1} calmed its mind and entered Zen Mode!" }
		}
	},
	# Abilities that ignore accuracy/evasion changes when attacking on beach field
	# Unless target has As One or Unnerve
	:ignoreAccEvaChanges => [:INNERFOCUS, :OWNTEMPO, :PUREPOWER, :SANDVEIL, :STEADFAST],
	# Status immunity on beach field
	# Fighting-types and Inner Focus cannot be confused
	:statusImmunity => {
		:CONFUSION => {
			types: [:FIGHTING],
			abilities: [:INNERFOCUS],
			message: "The Beach's focus prevents confusion!"
		}
	},
	# Water Compaction: additionally boosts SpDef by 2 stages (hardcoded in section 14)
	# Sand Spit: lowers all foes' accuracy by 1 stage on activation (hardcoded in section 14)
	# Item effect modifications
	# Shell Bell restores 25% of damage dealt instead of 12.5% (1/8)
	:itemEffectMods => {
		:SHELLBELL => { heal_percent: 0.25 }
	},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => :FocusEnergy,
		:duration => 3,
		:message => "{1}'s Telluric Seed is getting it pumped!",
		:animation => :FOCUSENERGY,
		:stats => {
		},
	},
},
:WATERSURFACE => {
	:name => "Water Surface",
	:fieldMessage => [
		"The water's surface is calm."
	],
	:graphic => ["Water"],
	:secretPower => "AQUAJET",
	:naturePower => :WHIRLPOOL,
	:mimicry => :WATER,
	:damageMods => {
		1.2 => [:WHIRLPOOL, :SURF, :MUDDYWATER, :WHIRLPOOL, :DIVE, :SLUDGEWAVE, :OCTAZOOKA, :ORIGINPULSE, :HYDROVORTEX],
		0 => [:SPIKES, :TOXICSPIKES],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The attack rode the current!" => [:WHIRLPOOL, :SURF, :MUDDYWATER, :WHIRLPOOL, :DIVE, :ORIGINPULSE, :HYDROVORTEX],
		"Poison spread through the water!" => [:SLUDGEWAVE],
		"...The spikes sank into the water and vanished!" => [:SPIKES, :TOXICSPIKES],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SLUDGEWAVE],
		"@battle.field_counters.counter = 2" => [:ACIDDOWNPOUR],
	},
	:typeBoosts => {
		1.5 => [:WATER, :ELECTRIC],
		0.5 => [:FIRE],
		0 => [:GROUND],
	},
	:typeMessages => {
		"The water conducted the attack!" => [:ELECTRIC],
		"The water strengthened the attack!" => [:WATER],
		"The water deluged the attack..." => [:FIRE],
		"...But there was no solid ground to attack from!" => [:GROUND],
	},
	:typeCondition => {
		:FIRE => "!opponent.isAirborne?",
		:ELECTRIC => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {
		:MURKWATERSURFACE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:UNDERWATER => [:GRAVITY, :DIVE, :ANCHORSHOT, :GRAVAPPLE],
		:ICY => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
		:MURKWATERSURFACE => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:dontChangeBackup => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	:changeMessage => {
		 "The battle sank into the depths!" => [:GRAVITY, :GRAVAPPLE],
		 "The battle was pulled underwater!" => [:DIVE, :ANCHORSHOT],
		 "The water froze over!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
		 "The water was polluted!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:statusMods => [:SPLASH, :AQUARING, :LIFEDEW, :TAKEHEART],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :AquaRing,
		:duration => true,
		:message => "{1} surrounded itself with a veil of water!",
		:animation => :AQUARING,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:UNDERWATER => {
	:name => "Underwater",
	:fieldMessage => [
		"Blub blub..."
	],
	:graphic => ["Underwater"],
	:secretPower => "AQUATAIL",
	:naturePower => :WATERPULSE,
	:mimicry => :WATER,
	:damageMods => {
		1.5 => [:WATERPULSE],
		2.0 => [:ANCHORSHOT, :DRAGONDARTS, :SLUDGEWAVE, :ACIDDOWNPOUR],
		0 => [:SUNNYDAY, :HAIL, :SANDSTORM, :RAINDANCE, :SHADOWSKY, :TARSHOT],
	},
	:accuracyMods => {},
	:moveMessages => {
		"Jet-streamed!" => [:WATERPULSE],
		"From the depths!" => [:ANCHORSHOT, :DRAGONDARTS],
		"You're too deep to notice the weather!" => [:SUNNYDAY, :HAIL, :SANDSTORM, :RAINDANCE, :SHADOWSKY],
		"The tar washed of instantly!" => [:TARSHOT],
	},
	:typeMods => {
		:WATER => [:DRAGONDARTS, :GRAVAPPLE],
	},
	:typeAddOns => {
		:WATER => [:GROUND],
	},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:SLUDGEWAVE],
		"@battle.field_counters.counter = 2" => [:ACIDDOWNPOUR],
	},
	:typeBoosts => {
		1.5 => [:WATER],
		2.0 => [:ELECTRIC],
		0 => [:FIRE],
	},
	:typeMessages => {
		"The water strengthened the attack!" => [:WATER],
		"The water super-conducted the attack!" => [:ELECTRIC],
		"...But the attack was doused instantly!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:MURKWATERSURFACE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:WATERSURFACE => [:DIVE, :SKYDROP, :FLY, :BOUNCE],
		:MURKWATERSURFACE => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The battle resurfaced!" => [:DIVE, :SKYDROP, :FLY, :BOUNCE, :SHOREUP],
		 "The grime sank beneath the battlers!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:statusMods => [:AQUARING, :TAKEHEART],
	:changeEffects => {
		"@battle.waterPollution" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
	},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} transformed into the Water type!",
		:animation => :SOAK,
		:stats => {
			:SPEED => 1,
		},
	},
},
:CAVE => {
	:name => "Cave",
	:fieldMessage => [
		"The cave echoes dully..."
	],
	:graphic => ["Cave"],
	:secretPower => "ROCKWRECKER",
	:naturePower => :ROCKTOMB,
	:mimicry => :ROCK,
	:abilityMods => {
    :PUNKROCK => { multiplier: 1.5 },
	},
	:damageMods => {
		1.5 => [:ROCKTOMB],
		0 => [:SKYDROP],
	},
    :noCharging => [:BOUNCE, :FLY],  # Skip charging turn - attack immediately
    :noChargingMessages => {
      :FLY => "The cave's low ceiling makes flying high impossible!",
      :BOUNCE => "The cave's low ceiling prevents a high bounce!",
    },
    :soundBoost => {
    multiplier: 1.5,                    # 50% boost to all sound moves
    message: "The cave echoed the sound!"
    },
	:accuracyMods => {},
	:moveMessages => {
		"...Piled on!" => [:ROCKTOMB],
		"The cave's low ceiling makes flying high impossible!" => [:SKYDROP],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.caveCollapse" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :CONTINENTALCRUSH],
		"@battle.field_counters.counter2 += 1" => [:DRAGONPULSE],
		"@battle.field_counters.counter2 = 2" => [:DRACOMETEOR, :DEVASTATINGDRAKE],
		"@battle.field_counters.counter3 += 1" => [:ERUPTION, :LAVAPLUME, :HEATWAVE, :OVERHEAT, :FUSIONFLARE],
		"@battle.field_counters.counter4 += 1" => [:GRAVITY],
	},
	:typeBoosts => {
		1.5 => [:ROCK],
		0.5 => [:FLYING],
	},
	:typeMessages => {
		"The cave choked out the air!" => [:FLYING],
		"The cavern strengthened the attack!" => [:ROCK],
	},
	:typeCondition => {
		:FLYING => "!self.contactMove?",
	},
	:typeEffects => {},
	:changeCondition => {
		:DRAGONSDEN => "@battle.field_counters.counter2 > 1",
		:VOLCANIC => "@battle.field_counters.counter3 > 1",
		:DEEPEARTH => "@battle.field_counters.counter4 > 1",
	},
	:fieldChange => {
		:CRYSTALCAVERN => [:POWERGEM, :DIAMONDSTORM],
		:ICY => [:BLIZZARD, :SUBZEROSLAMMER],
		:CORRUPTED => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		:VOLCANIC => [:ERUPTION, :LAVAPLUME, :HEATWAVE, :OVERHEAT, :FUSIONFLARE],
		:DRAGONSDEN => [:DRAGONPULSE, :DRACOMETEOR, :DEVASTATINGDRAKE],
		:DEEPEARTH => [:GRAVITY],
	},
	:dontChangeBackup => [:BLIZZARD, :SUBZEROSLAMMER],
	:changeMessage => {
		"The cave was littered with crystals!" => [:POWERGEM, :DIAMONDSTORM],
		"The cavern froze over!" => [:BLIZZARD, :SUBZEROSLAMMER],
		"The cave was corrupted!" => [:SLUDGEWAVE, :ACIDDOWNPOUR],
		"The flame ignited the cave!" => [:ERUPTION, :LAVAPLUME, :HEATWAVE, :OVERHEAT, :FUSIONFLARE],
		"The draconic energy mutated the field!" => [:DRAGONPULSE, :DRACOMETEOR, :DEVASTATINGDRAKE],
		"The battle was pulled deeper into the earth!" => [:GRAVITY],
	},
	:statusMods => [:STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} was hurt by Stealth Rocks!",
		:animation => nil,
		:stats => {
			:DEFENSE => 2,
		},
	},
},
:GLITCH => {
	:name => "Glitch Field",
	:fieldMessage => [
		"1n!taliz3 .b//////attl3"
	],
	:graphic => ["Glitch","99"],
	:secretPower => "TECHNOBLAST",
	:naturePower => :METRONOME,
	:mimicry => :QMARKS,
	:damageMods => {
		0 => [:ROAR, :WHIRLWIND],
	},
	:accuracyMods => {
		90 => [:BLIZZARD],
	},
	:moveMessages => {
		"ERROR! MOVE NOT FOUND!" => [:ROAR, :WHIRLWIND],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.2 => [:PSYCHIC],
	},
	:typeMessages => {
		".0P pl$ nerf!-//" => [:PSYCHIC],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:METRONOME],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1}.TYPE = (:QMARKS)",
		:animation => :AMNESIA,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:CRYSTALCAVERN => {
	:name => "Crystal Cavern",
	:fieldMessage => [
		"The cave is littered with crystals."
	],
	:graphic => ["CrystalCavern"],
	:secretPower => "POWERGEM",
	:naturePower => :POWERGEM,
	:mimicry => :DRAGON,
	:damageMods => {
		1.3 => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :DAZZLINGGLEAM, :MIRRORSHOT, :TECHNOBLAST, :DOOMDUMMY, :MOONGEISTBEAM, :PHOTONGEYSER, :MENACINGMOONRAZEMAELSTROM],
		1.5 => [:POWERGEM, :DIAMONDSTORM, :ANCIENTPOWER, :JUDGMENT, :ROCKSMASH, :ROCKTOMB, :STRENGTH, :ROCKCLIMB, :MULTIATTACK, :PRISMATICLASER, :LUSTERPURGE],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The crystals' light strengthened the attack!" => [:AURORABEAM, :SIGNALBEAM, :FLASHCANNON, :LUSTERPURGE, :DAZZLINGGLEAM, :MIRRORSHOT, :TECHNOBLAST, :DOOMDUMMY, :MOONGEISTBEAM, :PHOTONGEYSER, :PRISMATICLASER, :MENACINGMOONRAZEMAELSTROM],
		"The crystals strengthened the attack!" => [:POWERGEM, :DIAMONDSTORM, :ANCIENTPOWER, :JUDGMENT, :ROCKSMASH, :ROCKTOMB, :STRENGTH, :ROCKCLIMB, :MULTIATTACK],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE],
		"@battle.field_counters.counter = 2" => [:TECTONICRAGE],
	},
	:typeBoosts => {
		1.5 => [:ROCK, :DRAGON],
	},
	:typeMessages => {
		"The crystals charged the attack!" => [:ROCK],
		"The crystal energy strengthened the attack!" => [:DRAGON],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CAVE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:CAVE => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		:DARKCRYSTALCAVERN => [:DARKPULSE, :DARKVOID, :NIGHTDAZE, :LIGHTTHATBURNSTHESKY],
	},
	:dontChangeBackup => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE, :DARKPULSE, :DARKVOID, :NIGHTDAZE],
	:changeMessage => {
		 "The crystals were broken up!" => [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE, :FISSURE, :TECTONICRAGE],
		 "The crystals' light was warped by the darkness!" => [:DARKPULSE, :DARKVOID, :NIGHTDAZE],
		 "The crystals' light was consumed!" => [:LIGHTTHATBURNSTHESKY],
	},
	:statusMods => [:ROCKPOLISH, :STEALTHROCK, :AURORAVEIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :MagicCoat,
		:duration => true,
		:message => "{1} shrouded itself with Magic Coat!",
		:animation => :MAGICCOAT,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:MURKWATERSURFACE => {
	:name => "Murkwater Surface",
	:fieldMessage => [
		"The water is tainted..."
	],
	:graphic => ["MurkwaterSurface"],
	:secretPower => "SLUDGEBOMB",
	:naturePower => :SLUDGEWAVE,
	:mimicry => :POISON,
	:damageMods => {
		1.5 => [:MUDBOMB, :MUDSLAP, :MUDSHOT, :SMACKDOWN, :ACID, :ACIDSPRAY, :BRINE, :THOUSANDWAVES, :APPLEACID],
		0 => [:SPIKES, :TOXICSPIKES],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The toxic water strengthened the attack!" => [:MUDBOMB, :MUDSLAP, :MUDSHOT, :SMACKDOWN, :ACID, :ACIDSPRAY, :THOUSANDWAVES, :APPLEACID],
		"Stinging!" => [:BRINE],
		"...The spikes sank into the water and vanished!" => [:SPIKES, :TOXICSPIKES],
	},
	:typeMods => {
		:POISON => [:MUDBOMB, :MUDSLAP, :MUDSHOT, :SMACKDOWN, :THOUSANDWAVES, :APPLEACID],
		:WATER => [:SLUDGEWAVE],
	},
	:typeAddOns => {
		:POISON => [:WATER],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:WATER, :POISON],
		1.3 => [:ELECTRIC],
		0 => [:GROUND],
	},
	:typeMessages => {
		"The toxic water strengthened the attack!" => [:WATER, :POISON],
		"The toxic water conducted the attack!" => [:ELECTRIC],
		"...But there was no solid ground to attack from!" => [:GROUND],
	},
	:typeCondition => {
		:ELECTRIC => "!opponent.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:WATERSURFACE => [:WHIRLPOOL, :PURIFY],
		:ICY => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:dontChangeBackup => [:WHIRLPOOL, :PURIFY, :BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	:changeMessage => {
		"The maelstrom flushed out the poison!" => [:WHIRLPOOL],
		"The attack cleared the waters!" => [:PURIFY],
		"The toxic water froze over!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER],
	},
	:statusMods => [:ACIDARMOR, :TARSHOT, :VENOMDRENCH],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :AquaRing,
		:duration => true,
		:message => "{1} surrounded itself with a veil of water!",
		:animation => :AQUARING,
		:stats => {
			:SPEED => 1,
		},
	},
},
:MOUNTAIN => {
	:name => "Mountain",
	:fieldMessage => [
		"High up!",
	],
	:graphic => ["Mountain"],
	:secretPower => "ROCKBLAST",
	:naturePower => :ROCKSLIDE,
	:mimicry => :ROCK,
	:damageMods => {
		1.5 => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW, :OMINOUSWIND, :ICYWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :THUNDER, :ERUPTION, :AVALANCHE, :HYPERVOICE, :MOUNTAINGALE],
	},
	:accuracyMods => {
		0 => [:THUNDER]
	},
	:moveMessages => {
		"{1} was thrown partway down the mountain!" => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW],
		"The wind strengthened the attack!" => [:OMINOUSWIND, :ICYWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :MOUNTAINGALE],
		"The mountain strengthened the attack!" => [:THUNDER, :ERUPTION, :AVALANCHE],
		"Yodelayheehoo~" => [:HYPERVOICE],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ROCK, :FLYING],
	},
	:typeMessages => {
		"The mountain strengthened the attack!" => [:ROCK],
		"The open air strengthened the attack!" => [:FLYING],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:SNOWYMOUNTAIN => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER, :MOUNTAINGALE],
		:SKY => [:FLY, :BOUNCE],
		:VOLCANICTOP => [:LAVAPLUME, :ERUPTION, :INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The mountain was covered in snow!" => [:BLIZZARD, :GLACIATE, :SUBZEROSLAMMER, :MOUNTAINGALE],
		"The battle was taken to the skies!" => [:FLY, :BOUNCE],
		"The mountain erupted!" => [:LAVAPLUME, :ERUPTION, :INFERNOOVERDRIVE],
	},
	:statusMods => [:TAILWIND, :SUNNYDAY],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 2,
			:ACCURACY => -1,
		},
	},
},
:SNOWYMOUNTAIN => {
	:name => "Snowy Mountain",
	:fieldMessage => [
		"The snow glows white on the mountain..."
	],
	:graphic => ["SnowyMountain"],
	:secretPower => "ICEBALL",
	:naturePower => :AVALANCHE,
	:mimicry => :ICE,
	:damageMods => {
		1.5 => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW, :OMINOUSWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :AVALANCHE, :POWDERSNOW, :HYPERVOICE, :GLACIATE, :MOUNTAINGALE, :BITTERMALICE],
		0.5 => [:SCALD, :STEAMERUPTION],
		2.0 => [:ICYWIND],
	},
	:accuracyMods => {
		0 => [:THUNDER]
	},
	:moveMessages => {
		"{1} was thrown partway down the mountain!" => [:VITALTHROW, :CIRCLETHROW, :STORMTHROW],
		"The wind strengthened the attack!" => [:OMINOUSWIND, :SILVERWIND, :TWISTER, :RAZORWIND, :FAIRYWIND, :MOUNTAINGALE],
		"The snow strengthened the attack!" => [:AVALANCHE, :POWDERSNOW, :BITTERMALICE],
		"The cold softened the attack..." => [:SCALD, :STEAMERUPTION],
		"The frigid wind strengthened the attack!" => [:ICYWIND],
		"Yodelayheehoo~" => [:HYPERVOICE],
	},
	:typeMods => {},
	:typeAddOns => {
		:ICE => [:ROCK],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:ROCK, :ICE, :FLYING],
		0.5 => [:FIRE],
	},
	:typeMessages => {
		"The snowy mountain strengthened the attack!" => [:ROCK, :ICE],
		"The open air strengthened the attack!" => [:FLYING],
		"The cold softened the attack!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:MOUNTAIN => [:HEATWAVE, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		:VOLCANICTOP => [:ERUPTION],
		:SKY => [:FLY, :BOUNCE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The snow melted away!" => [:HEATWAVE, :SEARINGSHOT, :FLAMEBURST, :LAVAPLUME, :FIREPLEDGE, :MINDBLOWN, :INCINERATE, :INFERNOOVERDRIVE, :RAGINGFURY],
		"The mountain erupted!" => [:ERUPTION],
		"The battle was taken to the skies!" => [:FLY, :BOUNCE],
	},
	:statusMods => [:TAILWIND, :SUNNYDAY, :HAIL],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 2,
			:ACCURACY => -1,
		},
	},
},
:HOLY => {
	:name => "Blessed Field",
	:fieldMessage => [
		"The field is blessed!"
	],
	:graphic => ["Ruin","Ruin2","Ruin3"],
	:secretPower => "DAZZLINGGLEAM",
	:naturePower => :JUDGMENT,
	:mimicry => :NORMAL,
	:damageMods => {
		1.3 => [:PSYSTRIKE, :AEROBLAST, :ORIGINPULSE, :DOOMDUMMY, :MISTBALL, :CRUSHGRIP, :LUSTERPURGE, :SECRETSWORD, :PSYCHOBOOST, :RELICSONG, :SPACIALREND, :HYPERSPACEHOLE, :ROAROFTIME, :LANDSWRATH, :PRECIPICEBLADES, :DRAGONASCENT, :MOONGEISTBEAM, :SUNSTEELSTRIKE, :PRISMATICLASER, :FLEURCANNON, :DIAMONDSTORM, :GENESISSUPERNOVA, :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM, :BEHEMOTHBLADE, :BEHEMOTHBASH, :ETERNABEAM, :DYNAMAXCANNON],
		1.5 => [:MYSTICALFIRE, :MAGICALLEAF, :ANCIENTPOWER, :JUDGMENT, :SACREDFIRE, :EXTREMESPEED, :SACREDSWORD, :RETURN],
	},
	:accuracyMods => {},
	:moveMessages => {
		"Legendary power accelerated the attack!" => [:PSYSTRIKE, :AEROBLAST, :SACREDFIRE, :ORIGINPULSE, :DOOMDUMMY, :JUDGMENT, :MISTBALL, :CRUSHGRIP, :LUSTERPURGE, :SECRETSWORD, :PSYCHOBOOST, :RELICSONG, :SPACIALREND, :HYPERSPACEHOLE, :ROAROFTIME, :LANDSWRATH, :PRECIPICEBLADES, :DRAGONASCENT, :MOONGEISTBEAM, :SUNSTEELSTRIKE, :PRISMATICLASER, :FLEURCANNON, :DIAMONDSTORM, :GENESISSUPERNOVA, :SEARINGSUNRAZESMASH, :MENACINGMOONRAZEMAELSTROM, :BEHEMOTHBLADE, :BEHEMOTHBASH, :ETERNABEAM, :DYNAMAXCANNON],
		"The holy energy resonated with the attack!" => [:MYSTICALFIRE, :MAGICALLEAF, :ANCIENTPOWER, :SACREDSWORD, :RETURN],
		"Godspeed!" => [:EXTREMESPEED],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FAIRY, :NORMAL],
		1.2 => [:PSYCHIC, :DRAGON],
		0.5 => [:GHOST, :DARK],
	},
	:typeMessages => {
		"The holy energy resonated with the attack!" => [:FAIRY, :NORMAL],
		"The legendary energy resonated with the attack!" => [:PSYCHIC, :DRAGON],
		"The attack was cleansed..." => [:GHOST, :DARK],
	},
	:typeCondition => {
		:FAIRY => "self.pbIsSpecial?(type)",
		:NORMAL => "self.pbIsSpecial?(type)",
		:DARK => "self.pbIsSpecial?(type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:INDOOR => [:LIGHTTHATBURNSTHESKY],
		:HAUNTED=> [:CURSE, :PHANTOMFORCE, :SHADOWFORCE, :OMINOUSWIND, :TRICKORTREAT],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"Evil spirits gathered!" => [:CURSE, :PHANTOMFORCE, :SHADOWFORCE, :OMINOUSWIND, :TRICKORTREAT],
		"The holy light was consumed!" => [:LIGHTTHATBURNSTHESKY],
	},
	:statusMods => [:LIFEDEW, :WISH, :MIRACLEEYE, :COSMICPOWER, :NATURESMADNESS],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :MagicCoat,
		:duration => true,
		:message => "{1} shrouded itself with Magic Coat!",
		:animation => :MAGICCOAT,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:FAIRYTALE => {
	:name => "Fairy Tale Field",
	:fieldMessage => [
		"Once upon a time..."
	],
	:graphic => ["FairyTale"],
	:secretPower => "SLASH",
	:naturePower => :SECRETSWORD,
	:mimicry => :FAIRY,
	:damageMods => {
		1.5 => [:NIGHTSLASH, :LEAFBLADE, :PSYCHOCUT, :SMARTSTRIKE, :AIRSLASH, :SOLARBLADE, :MAGICALLEAF, :MYSTICALFIRE, :ANCIENTPOWER, :RELICSONG, :SPARKLINGARIA, :MOONGEISTBEAM, :FLEURCANNON, :RAZORSHELL, :BEHEMOTHBLADE, :BEHEMOTHBASH, :OCEANICOPERETTA, :MENACINGMOONRAZEMAELSTROM,:CEASELESSEDGE,:STONEAXE,:AQUACUTTER],
		2.0 => [:DRAININGKISS, :MISTBALL],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The blade cuts true!" => [:NIGHTSLASH, :LEAFBLADE, :PSYCHOCUT, :SMARTSTRIKE, :AIRSLASH, :SOLARBLADE, :RAZORSHELL, :BEHEMOTHBLADE],
		"The magical energy strengthened the attack!" => [:MAGICALLEAF, :MYSTICALFIRE, :ANCIENTPOWER, :RELICSONG, :SPARKLINGARIA, :MOONGEISTBEAM, :FLEURCANNON, :BEHEMOTHBASH, :MISTBALL, :OCEANICOPERETTA, :MENACINGMOONRAZEMAELSTROM],
		"True love never hurt so badly!" => [:DRAININGKISS],
	},
	:typeMods => {},
	:typeAddOns => {
		:DRAGON => [:FIRE],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:STEEL, :FAIRY],
		2.0 => [:DRAGON],
	},
	:typeMessages => {
		"For ever after!" => [:FAIRY],
		"For justice!" => [:STEEL],
		"The foul beast's attack gained strength!" => [:DRAGON],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:KINGSSHIELD, :CRAFTYSHIELD, :FLOWERSHIELD, :ACIDARMOR, :NOBLEROAR, :SWORDSDANCE, :WISH, :HEALINGWISH, :MIRACLEEYE, :FORESTSCURSE, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :Protect,
		:duration => :KingsShield,
		:message => "The Magical Seed shielded {1} against damage!",
		:animation => :KINGSSHIELD,
		:stats => {
		},
	},
},
:DRAGONSDEN => {
	:name => "Dragon's Den",
	:fieldMessage => [
		"If you wish to slay a dragon..."
	],
	:graphic => ["DragonsDen"],
	:secretPower => "DRAGONPULSE",
	:naturePower => :DRAGONPULSE,
	:mimicry => :DRAGON,
	:damageMods => {
		1.5 => [:MEGAKICK, :MAGMASTORM, :LAVAPLUME, :STOMPINGTANTRUM, :EARTHPOWER, :DIAMONDSTORM, :SHELLTRAP, :POWERGEM, :ROCKCLIMB, :STRENGTH],             
		2.0 => [:SMACKDOWN, :THOUSANDARROWS, :DRAGONASCENT, :PAYDAY, :MISTBALL, :LUSTERPURGE,],
		0 => [:GRASSYTERRAIN, :PSYCHICTERRAIN, :MISTYTERRAIN, :ELECTRICTERRAIN, :MIST, :HAIL],
	},
	:accuracyMods => {
		100 => [:DRAGONRUSH],
	},
	:moveMessages => {
		"Trial of the Dragon!!!" => [:MEGAKICK],
		"Wrath of the Dragon!!!" => [:STOMPINGTANTRUM],
		"Unrivaled Power!" => [:STRENGTH, :ROCKCLIMB],
		"The lava strengthened the attack!" => [:MAGMASTORM, :LAVAPLUME, :EARTHPOWER, :SHELLTRAP],
		"{1} was knocked into the lava!" => [:SMACKDOWN, :THOUSANDARROWS],
		"The draconic energy boosted the attack!" => [:DRAGONASCENT, :MISTBALL, :LUSTERPURGE],
		"Sparkling treasure!" => [:PAYDAY, :POWERGEM, :DIAMONDSTORM],
		"The draconic power blocked the terrain..." => [:GRASSYTERRAIN, :PSYCHICTERRAIN, :MISTYTERRAIN, :ELECTRICTERRAIN, :MIST],
		"The hail is melting in the heat..." => [:HAIL],
	},
	:typeMods => {
		:FIRE => [:SMACKDOWN, :THOUSANDARROWS, :STRENGTH, :ROCKCLIMB, :EARTHQUAKE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:DRAGON, :FIRE],
		1.3 => [:ROCK],
		0.5 => [:ICE, :WATER],
	},
	:typeMessages => {
		"The lava's heat boosted the flame!" => [:FIRE],
		"The draconic energy boosted the attack!" => [:DRAGON],
		"The lava's heat softened the attack..." => [:ICE, :WATER],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:CAVE => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:CAVE => [:GLACIATE, :SUBZEROSLAMMER, :OCEANICOPERETTA, :HYDROVORTEX],
		:FAIRYTALE => [:MISTBALL],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The lava was frozen solid!" => [:GLACIATE, :SUBZEROSLAMMER],
		 "The lava solidified!" => [:OCEANICOPERETTA, :HYDROVORTEX],
		 "The mist-ical energy altered the surroundings!" => [:MISTBALL],
	},
	:statusMods => [:DRAGONDANCE, :NOBLEROAR, :COIL, :STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => :FlashFire,
		:duration => true,
		:message => "{1} raised its Fire power!",
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
},
:FLOWERGARDEN1 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden0"],
	:secretPower => "SWEETSCENT",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
	},
	:accuracyMods => {},
	:moveMessages => {
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:FLOWERGARDEN2 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
	},
	:dontChangeBackup => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY, :ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
	:changeMessage => {
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY, :ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN2 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden1"],
	:secretPower => "PETALBLIZZARD",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT],
	},
	:accuracyMods => {},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.1 => [:GRASS],
	},
	:typeMessages => {
		"The garden's power boosted the attack!" => [:GRASS],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:FLOWERGARDEN3 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		:FLOWERGARDEN1 => [:CUT,:XSCISSOR,:ACIDDOWNPOUR],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN3 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden2"],
	:secretPower => "PETALBLIZZARD",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT],
		1.2 => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:accuracyMods => {
		85 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
		"The fresh scent of flowers boosted the attack!" => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE,:BUG],
		1.3 => [:GRASS],
	},
	:typeMessages => {
		"The budding flowers boosted the attack!" => [:GRASS],
		"The attack infested the garden!" => [:BUG],
		"The nearby flowers caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:BURNING => "state.effects[:WaterSport] <= 0 && pbWeather != :RAINDANCE",
	},
	:fieldChange => {
		:FLOWERGARDEN4 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		:FLOWERGARDEN2 => [:CUT,:XSCISSOR],
		:FLOWERGARDEN1 => [:ACIDDOWNPOUR,:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden caught fire!" => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN4 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden3"],
	:secretPower => "PETALBLIZZARD",
	:naturePower => :GROWTH,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT,:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:accuracyMods => {
		85 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
		"The vibrant aroma scent of flowers boosted the attack!" => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		2.0 => [:BUG],
		1.5 => [:FIRE,:GRASS],
	},
	:typeMessages => {
		"The blooming flowers boosted the attack!" => [:GRASS],
		"The attack infested the flowers!" => [:BUG],
		"The nearby flowers caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:BURNING => "state.effects[:WaterSport] <= 0 && pbWeather != :RAINDANCE",
	},
	:fieldChange => {
		:FLOWERGARDEN5 => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		:FLOWERGARDEN3 => [:CUT,:XSCISSOR],
		:FLOWERGARDEN1 => [:ACIDDOWNPOUR],
		:FLOWERGARDEN2 => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden caught fire!" => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The garden grew a little!" => [:GROWTH,:FLOWERSHIELD,:RAINDANCE,:SUNNYDAY,:ROTOTILLER,:INGRAIN,:GRASSYTERRAIN,:WATERSPORT,:BLOOMDOOM],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:FLOWERGARDEN5 => {
	:name => "Flower Garden",
	:fieldMessage => [
		"Seeds line the field."
	],
	:graphic => ["FlowerGarden4"],
	:secretPower => "PETALDANCE",
	:naturePower => :PETALBLIZZARD,
	:mimicry => :GRASS,
	:damageMods => {
		1.5 => [:CUT,:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:accuracyMods => {
		85 => [:SLEEPPOWDER, :STUNSPORE, :POISONPOWDER],
	},
	:moveMessages => {
		"{1} was cut down to size!" => [:CUT],
		"The vibrant aroma scent of flowers boosted the attack!" => [:PETALBLIZZARD,:PETALDANCE,:FLEURCANNON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		2.0 => [:GRASS,:BUG],
		1.5 => [:FIRE],
	},
	:typeMessages => {
		"The thriving flowers boosted the attack!" => [:GRASS],
		"The attack infested the flowers!" => [:BUG],
		"The nearby flowers caught flame!" => [:FIRE],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {
		:BURNING => "state.effects[:WaterSport] <= 0 && pbWeather != :RAINDANCE",
	},
	:fieldChange => {
		:FLOWERGARDEN4 => [:CUT,:XSCISSOR],
		:FLOWERGARDEN1 => [:ACIDDOWNPOUR],
		:FLOWERGARDEN3 => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The garden caught fire!" => [:HEATWAVE,:ERUPTION,:SEARINGSHOT,:FLAMEBURST,:LAVAPLUME,:FIREPLEDGE,:MINDBLOWN,:INFERNOOVERDRIVE],
		"The garden was cut down a bit!" => [:CUT,:XSCISSOR],
		"The acid melted the bloom!" => [:ACIDDOWNPOUR],
	},
	:statusMods => [:GROWTH, :ROTOTILLER, :RAINDANCE, :WATERSPORT, :SUNNYDAY, :FLOWERSHIELD, :SWEETSCENT, :INGRAIN, :FLORALHEALING],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Ingrain,
		:duration => true,
		:message => "{1} planted its roots!",
		:animation => :INGRAIN,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:INVERSE => {
	:name => "Inverse Field",
	:fieldMessage => [
		"!trats elttaB"
	],
	:graphic => ["Inverse"],
	:secretPower => "CONFUSION",
	:naturePower => :TRICKROOM,
	:mimicry => :NORMAL,
	:damageMods => {
	},
	:accuracyMods => {},
	:moveMessages => {
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:statusMods => [],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :HyperBeam,
		:duration => 1,
		:message => "{1} was normalized!",
		:animation => :SHARPEN,
		:stats => {},
	},
},
:PSYTERRAIN => {
	:name => "Psychic Terrain",
	:fieldMessage => [
		"The field became mysterious!"
	],
	:graphic => ["Psychic","Psychic_2"],
	:secretPower => "PSYCHIC",
	:naturePower => :PSYCHIC,
	:mimicry => :PSYCHIC,
	:damageMods => {
		1.5 => [:SECRETPOWER, :HIDDENPOWER, :HEX, :MAGICALLEAF, :MYSTICALFIRE, :MOONBLAST, :AURASPHERE, :FOCUSBLAST, :MINDBLOWN, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
	},
	:accuracyMods => {
		90 => [:HYPNOSIS],
	},
	:moveMessages => {
		"The psychic energy strengthened the attack!" => [:SECRETPOWER, :HIDDENPOWER, :HEX, :MAGICALLEAF, :MYSTICALFIRE, :MOONBLAST, :AURASPHERE, :FOCUSBLAST, :MINDBLOWN, :HIDDENPOWERNOR, :HIDDENPOWERFIR, :HIDDENPOWERFIG, :HIDDENPOWERWAT, :HIDDENPOWERFLY, :HIDDENPOWERGRA, :HIDDENPOWERPOI, :HIDDENPOWERELE, :HIDDENPOWERGRO, :HIDDENPOWERPSY, :HIDDENPOWERROC, :HIDDENPOWERICE, :HIDDENPOWERBUG, :HIDDENPOWERDRA, :HIDDENPOWERGHO, :HIDDENPOWERDAR, :HIDDENPOWERSTE, :HIDDENPOWERFAI],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:PSYCHIC],
	},
	:typeMessages => {
		"The Psychic Terrain strengthened the attack!" => [:PSYCHIC],
	},
	:typeCondition => {
		:PSYCHIC => "!attacker.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:statusMods => [:CALMMIND, :COSMICPOWER, :KINESIS, :MEDITATE, :NASTYPLOT, :HYPNOSIS, :PSYCHUP, :MINDREADER, :MIRACLEEYE, :TELEKINESIS, :GRAVITY, :MAGICROOM, :TRICKROOM, :WONDERROOM],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => 0,
		:duration => 0,
		:message => "{1} became confused!",
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 2,
		},
	},
	:overlay => {
		:damageMods => {
			1.5 => [:SECRETPOWER, :HIDDENPOWER, :MYSTICALFIRE,:MAGICALLEAF,:AURASPHERE,:FOCUSBLAST,:HEX,:MOONBLAST,:MINDBLOWN],
		},
		:typeMods => {
		},
		:moveMessages => {
			"The psychic energy strengthened the attack!" => [:SECRETPOWER, :HIDDENPOWER, :MYSTICALFIRE,:MAGICALLEAF,:AURASPHERE,:HEX,:MOONBLAST,:MINDBLOWN],
		},
		:typeBoosts => {
			1.5 => [:PSYCHIC],
		},
		:typeMessages => {
			"The Psychic Terrain strengthened the attack!" => [:PSYCHIC],
		},
		:typeCondition => {	
			:PSYCHIC => "!attacker.isAirborne?",
		},
		:statusMods => [],
	},
},
:DIMENSIONAL => {
	:name => "Dimensional Field",
	:fieldMessage => [
		"Darkness Radiates."
	],
	:graphic => ["Dimensional"],
	:secretPower => "DARKPULSE",
	:naturePower => :DARKPULSE,
	:mimicry => :DARK,
	:damageMods => {
		1.5 => [:HYPERSPACEFURY, :HYPERSPACEHOLE, :SPACIALREND, :ROAROFTIME, :ETERNABEAM, :DYNAMAXCANNON, :SHADOWFORCE, :OUTRAGE, :THRASH, :STOMPINGTANTRUM, :LASHOUT, :FREEZINGGLARE, :FIREYWRATH, :RAGINGFURY],
		1.2 => [:DARKPULSE, :NIGHTDAZE],
		0 => [:HAIL, :SUNNYDAY, :SANDSTORM, :RAINDANCE, :TEATIME, :LUCKYCHANT],
	},
	:accuracyMods => {
		0 => [:DARKVOID, :DARKPULSE, :NIGHTDAZE],
	},
	:moveMessages => {
		"The attack has been corrupted." => [:HYPERSPACEFURY, :HYPERSPACEHOLE, :SPACIALREND, :ROAROFTIME, :ETERNABEAM, :DYNAMAXCANNON, :SHADOWFORCE, :DARKPULSE, :NIGHTDAZE],
		"The rage continues." => [:OUTRAGE, :THRASH, :STOMPINGTANTRUM, :LASHOUT, :FREEZINGGLARE, :FIREYWRATH, :RAGINGFURY],
		"But it failed." => [:TEATIME, :LUCKYCHANT],
		"The dark dimension swallowed the sand." => [:SANDSTORM],
		"The dark dimension swallowed the rain." => [:RAINDANCE],
		"The dark dimension swallowed the hail." => [:HAIL],
		"The sunlight cannot pierce the darkness." => [:SUNNYDAY],
	},
	:typeMods => {
	},
	:typeAddOns => {
	},
	:moveEffects => {
		"@battle.field_counters.counter += 1" => [:BLIZZARD, :SHEERCOLD],
		"@battle.field_counters.counter = 2" => [:ICEBURN, :FREEZESHOCK, :GLACIATE],
	},
	:typeBoosts => {
		1.5 => [:DARK, :SHADOW],
		1.2 => [:GHOST],
		0.5 => [:FAIRY],
	},
	:typeMessages => {
		"The darkness is here..." => [:DARK],
		"The shadow is strengthened..." => [:SHADOW],
		"The evil aura powered up the attack..." => [:GHOST],
		"The evil aura depleted the attack!" => [:FAIRY],
	},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
		:FROZENDIMENSION => "@battle.field_counters.counter > 1",
	},
	:fieldChange => {
		:FROZENDIMENSION => [:BLIZZARD, :SHEERCOLD, :ICEBURN, :FREEZESHOCK, :GLACIATE],
		:INFERNAL => [:PRECIPICEBLADES],
		:INDOOR => [:PURIFY, :SEEDFLARE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The dimension froze up!" => [:BLIZZARD, :SHEERCOLD, :ICEBURN, :FREEZESHOCK, :GLACIATE],
		 "The field went up in flames!" => [:PRECIPICEBLADES],
		 "The dimension was purified!" => [:PURIFY, :SEEDFLARE],
	},
	:statusMods => [:OBSTRUCT, :QUASH, :EMBARGO, :HEALBLOCK, :DARKVOID],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => nil,
		:duration => nil,
		:message => "",
		:animation => :TRICKROOM,
		:stats => {
			:DEFENSE => 1,
		},
	},
},
:HAUNTED => {
	:name => "Haunted Field",
	:fieldMessage => [
		"The field is haunted!"
	],
	:graphic => ["Haunted"],
	:secretPower => "SHADOWCLAW",
	:naturePower => :PHANTOMFORCE,
	:mimicry => :GHOST,
	:damageMods => {
		1.5 => [:FLAMEBURST, :INFERNO, :FLAMECHARGE, :FIRESPIN, :BONECLUB, :BONERUSH, :BONEMERANG, :ASTONISH],
		1.2 => [:SHADOWBONE],
	},
	:accuracyMods => {
		90 => [:WILLOWISP, :HYPNOSIS],
	},
	:moveMessages => {
		"Will-o'-wisps joined the attack!" => [:FLAMEBURST, :INFERNO, :FLAMECHARGE, :FIRESPIN],
		"Spooky scary skeletons!" => [:BONECLUB, :BONERUSH, :BONEMERANG, :SHADOWBONE],	
		"Boo!" => [:ASTONISH],
	},
	:typeMods => {
		:GHOST => [:FLAMEBURST, :INFERNO, :FLAMECHARGE, :FIRESPIN],
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:GHOST],
	},
	:typeMessages => {
		"The evil aura powered up the attack!" => [:GHOST],
	},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:HOLY => [:JUDGEMENT, :ORIGINPULSE, :SACREDFIRE, :PURIFY],
		:INDOOR => [:FLASH, :DAZZLINGGLEAM],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The evil spirits have been exorcised!" => [:JUDGEMENT, :ORIGINPULSE, :PURIFY, :SACREDFIRE],
		 "The evil spirits have been forced back!" => [:FLASH, :DAZZLINGGLEAM],
	},
	:statusMods => [:NIGHTMARE, :SPITE, :CURSE, :DESTINYBOND, :MEANLOOK, :SCARYFACE, :MAGICPOWDER, :HYPNOSIS, :WILLOWISP],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => :nil,
		:duration => nil,
		:message => "",
		:animation => nil,
		:stats => {
			:SPECIAL_DEFENSE => 1,
			:DEFENSE => 1,
		},
	},
},
:CORRUPTED => {
	:name => "Corrupted Cave",
	:fieldMessage => [
		"Corruption seeps from every crevice!"
	],
	:graphic => ["Corrupted"],
	:secretPower => "POISONJAB",
	:naturePower => :GUNKSHOT,
	:mimicry => :POISON,
	:damageMods => {
		1.5 => [:SEEDFLARE, :APPLEACID],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The move absorbed the filth!" => [:SEEDFLARE],
	},
	:typeMods => {
		:POISON => [:ROCKSLIDE, :SMACKDOWN, :STONEEDGE, :ROCKTOMB, :DIAMONDSTORM],
		:ROCK => [:SLUDGEWAVE, :GUNKSHOT],
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:POISON],
		1.2 => [:ROCK, :GRASS],
		0.5 => [:FAIRY, :FLYING],
	},
	:typeMessages => {
		"The chemicals strengthened the attack." => [:POISON],
		"The corruption morphed the attack!" => [:ROCK, :GRASS],
		"The corruption weakened the attack." => [:FAIRY],
		"The cave choked out the air!" => [:FLYING],
	},
	:typeCondition => {
		:FLYING => "!self.contactMove?",
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:CAVE => [:SOLARBEAM, :SOLARBLADE, :PURIFY, :SEEDFLARE],
		:VOLCANIC => [:HEATWAVE, :ERUPTION, :LAVAPLUME, :BLASTBURN, :INFERNOOVERDRIVE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The cave was purified!" => [:SOLARBEAM, :SOLARBLADE, :PURIFY, :SEEDFLARE],
	},
	:statusMods => [:NIGHTMARE, :SPITE, :CURSE, :DESTINYBOND, :MEANLOOK, :SCARYFACE, :MAGICPOWDER, :HYPNOSIS, :WILLOWISP],
	:changeEffects => {
		"@battle.mistExplosion" => [:HEATWAVE, :ERUPTION, :LAVAPLUME, :BLASTBURN, :INFERNOOVERDRIVE],
	},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => nil,
		:duration => nil,
		:message => "",
		:animation => nil,
		:stats => {
			:DEFENSE => 2,
		},
	},
},
:SKY => {
	:name => "Sky Field",
	:fieldMessage => [
		"The sky is filled with clouds. "
	],
	:graphic => ["GoldenArena"],
	:secretPower => "WINGATTACK",
	:naturePower => :SKYATTACK,
	:mimicry => :FLYING,
	:damageMods => {
		1.5 => [:ICYWIND, :SILVERWIND, :OMINOUSWIND, :FAIRYWIND, :AEROBLAST, :FLYINGPRESS, :SKYUPPERCUT, :THUNDERSHOCK, :THUNDERBOLT, :STEELWING, :DRAGONDARTS, :GRAVAPPLE, :DRAGONASCENT, :THUNDER, :TWISTER, :RAZORWIND, :DIVE, :ESPERWING, :BLEAKWINDSTORM],
		1.3 => [:SPRINGTIDESTORM, :WINDBOLTSTORM, :SANDSEARSTORM],
		0 => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE, :DIG, :ROTOTILLER, :SPIKES, :TOXICSPIKES, :STICKYWEB]
	},
	:accuracyMods => {
		0 => [:THUNDER, :HURRICANE]
	},
	:moveMessages => {
		"The open skies strengthened the attack!" => [:ICYWIND, :SILVERWIND, :OMINOUSWIND, :FAIRYWIND, :AEROBLAST, :FLYINGPRESS, :SKYUPPERCUT, :THUNDERSHOCK, :THUNDERBOLT, :STEELWING, :DRAGONDARTS, :GRAVAPPLE, :DRAGONASCENT, :THUNDER, :TWISTER, :RAZORWIND, :DIVE, :ESPERWING, :SPRINGTIDESTORM, :WINDBOLTSTORM, :SANDSEARSTORM, :BLEAKWINDSTORM],
		"But there is no solid ground!" => [:EARTHQUAKE, :MAGNITUDE, :BULLDOZE, :DIG, :ROTOTILLER, :SPIKES, :TOXICSPIKES, :STICKYWEB]
	},
	:typeMods => {
		:FLYING => [:DIVE, :TWISTER],
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FLYING],
	},
	:typeMessages => {
		"The open air strengthened the attack!" => [:FLYING],
	},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:MOUNTAIN => [:GRAVITY, :INGRAIN, :THOUSANDARROWS, :SMACKDOWN, :GRAVAPPLE],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The battle has been brought down to the mountains!" => [:GRAVITY, :INGRAIN, :THOUSANDARROWS, :SMACKDOWN, :GRAVAPPLE],
	},
	:statusMods => [:MIRRORMOVE, :TAILWIND, :SUNNYDAY, :HAIL, :SANDSTORM, :RAINDANCE],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:DEFENSE => 1,
			:SPECIAL_DEFENSE => 1,
		},
	},
},
:COLOSSEUM => {
	:name => "Colosseum",
	:fieldMessage => [
		"All eyes are on the combatants!"
	],
	:graphic => ["Colosseum"],
	:secretPower => "POWERUPPUNCH",
	:naturePower => :BEATUP,
	:mimicry => :STEEL,
	:damageMods => {
		2.0 => [:BEATUP, :FELLSTINGER, :PAYDAY, :REVERSAL, :PURSUIT],
		1.5 => [:SACREDSWORD, :SECRETSWORD, :SUBMISSION, :METEORASSAULT, :SMARTSTRIKE, :SMACKDOWN, :BRUTALSWING, :ELECTROWEB, :VINEWHIP, :PSYCHOCUT, :NIGHTSLASH, :BONEMERANG, :FIRSTIMPRESSION, :BONERUSH, :BONECLUB, :LEAFBLADE, :PAYBACK, :PUNISHMENT, :METEORMASH, :BULLETPUNCH, :CLANGINGSCALES, :STEAMROLLER],
		1.2 => [:STORMTHROW, :WOODHAMMER, :DRAGONHAMMER, :POWERWHIP, :SPIRITSHACKLE, :DRILLRUN, :DRILLPECK, :ICEHAMMER, :ICICLESPEAR, :ANCHORSHOT, :CRABHAMMER, :SHADOWBONE, :FIRELASH, :SUCKERPUNCH, :THROATCHOP],
		0 => [:BATONPASS, :ENCORE, :WHIRLWIND],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The fighters rallied together!" => [:BEATUP],
		"The coup de grâce!" => [:FELLSTINGER],
		"The audience hurled coins down!" => [:PAYDAY],
		"There is no escape!" => [:PURSUIT],
		"For Honor!" => [:REVERSAL, :SACREDSWORD, :SECRETSWORD, :SUBMISSION, :METEORASSAULT, :SMARTSTRIKE, :SMACKDOWN, :BRUTALSWING, :STORMTHROW],
		"For Glory!" => [:ELECTROWEB, :VINEWHIP, :PSYCHOCUT, :NIGHTSLASH, :BONEMERANG, :FIRSTIMPRESSION, :BONERUSH, :BONECLUB, :LEAFBLADE, :PAYBACK, :PUNISHMENT, :METEORMASH, :BULLETPUNCH, :CLANGINGSCALES, :STEAMROLLER, :WOODHAMMER, :DRAGONHAMMER, :POWERWHIP, :SPIRITSHACKLE, :DRILLRUN, :DRILLPECK, :ICEHAMMER, :ICICLESPEAR, :ANCHORSHOT, :CRABHAMMER, :SHADOWBONE, :FIRELASH, :SUCKERPUNCH, :THROATCHOP],
		"There can be no retreat!" => [:BATONPASS],
		"{1} stands their ground in the arena!!" => [:WHIRLWIND],
		"The audience demands fighting not repetition!" => [:ENCORE],
	},
	:typeMods => {
	},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {},
	:typeMessages => {},
	:typeCondition => {
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:statusMods => [:SWORDSDANCE, :KINGSSHIELD, :HOWL, :NORETREAT, :ROAR, :SWAGGER, :FLATTER],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => :Taunt,
		:duration => 4,
		:message => "{1} feels taunted!",
		:animation => :TAUNT,
		:stats => {
			:ATTACK => 2,
		},
	},
},
:INFERNAL => {
	:name => "Infernal Field",
	:fieldMessage => [
		"The souls of the damned burn on."
	],
	:graphic => ["Infernal"],
	:secretPower => "INFERNO",
	:naturePower => :PUNISHMENT,
	:mimicry => :FIRE,
	:damageMods => {
		2.0 => [:PUNISHMENT, :SMOG, :DREAMEATER],
		1.5 => [:BLASTBURN, :EARTPOWER, :INFERNOOVERDRIVE, :PRECIPICEBLADES, :INFERNO, :RAGINGFURY, :INFERNALPARADE],
		0  => [:RAINDANCE, :HAIL],
	},
	:accuracyMods => {
		0 => [:WILLOWISP, :DARKVOID, :INFERNO],
	},
	:moveMessages => {
		"Hellish Suffering!" => [:PUNISHMENT, :SMOG, :DREAMEATER],
		"Infernal flames strengthened the attack" => [:BLASTBURN, :EARTPOWER, :INFERNOOVERDRIVE, :PRECIPICEBLADES, :INFERNO, :RAGINGFURY, :INFERNALPARADE],
		"The hail melted away." => [:HAIL],
		"The rain evaporated." => [:RAINDANCE],
	},
	:typeMods => {
		:DARK => [:SPIRITBREAK, :AURASPHERE, :FRUSTRATION],
	},
	:typeAddOns => {
		:FIRE => [:GROUND, :STEEL, :ROCK],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FIRE, :DARK],
		0.5 => [:FAIRY, :WATER],
	},
	:typeMessages => {
		"The infernal flames strengthened the attack!" => [:FIRE, :DARK],
		"The hellfire burnt out the attack!" => [:FAIRY, :WATER],
	},
	:typeCondition => {
		:FAIRY => "@move != :SPIRITBREAK",
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
		:DIMENSIONAL => [:GLACIATE],
		:VOLCANICTOP => [:JUDGEMENT, :ORIGINPULSE, :PURIFY],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		 "The hellish landscape was doused of its fire!" => [:GLACIATE],
		 "The hellish landscape was purified!" => [:JUDGEMENT, :ORIGINPULSE, :PURIFY],
	},
	:statusMods => [:WILLOWISP, :DARKVOID, :TORMENT, :NIGHTMARE, :STEALTHROCK],
	:changeEffects => {},
	:seed => {
		:seedtype => :ELEMENTALSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1} can't escape now!",
		:animation => :MEANLOOK,
		:stats => {
			:ATTACK => 1,
			:SPECIAL_ATTACK => 1,
		},
	},
},
:DEEPEARTH => {
	:name => "Deep Earth",
	:fieldMessage => [
		"The core is pulling you in...",
	],
	:graphic => ["DeepEarth","Zeight","Zeight2","Zeight3","Zeight4"],
	:secretPower => "HEAVYSLAM",
	:naturePower => :GRAVITY,
	:mimicry => :GROUND,
	:damageMods => {
		2.0 => [:LANDSWRATH, :PRECIPICEBLADES, :MAGNETBOMB, :TECTONICRAGE, :CRUSHGRIP, :SMACKDOWN, :COREENFORCER],
		1.5 => [:HEAVYSLAM,	:HEATCRASH, :BODYSLAM, :STOMP, :DRAGONRUSH, :STEAMROLLER, :GRAVAPPLE, :ANCIENTPOWER, :FLING, :GRASSKNOT, :LOWKICK, :SPACIALREND, :STORMTHROW, :CIRCLETHROW, :VITALTHROW, :BODYPRESS, :SUBMISSION, :ICEHAMMER, :HAMMERARM, :CRABHAMMER, :ICICLECRASH, :THOUSANDARROWS, :THOUSANDWAVES],
	},
	:accuracyMods => {
	},
	:moveMessages => {
		"The attack came crashing down!" => [:HEAVYSLAM, :HEATCRASH, :BODYSLAM, :STOMP, :DRAGONRUSH, :STEAMROLLER, :GRAVAPPLE, :BODYPRESS, :ICICLECRASH, :FLING],
		"Enjoy the trip!" => [:GRASSKNOT, :LOWKICK],
		"{1} threw their whole weight into it!" => [:ICEHAMMER, :HAMMERARM, :CRABHAMMER],
		"Slammed into the ground!" => [:STORMTHROW, :CIRCLETHROW, :VITALTHROW, :SUBMISSION, :SMACKDOWN],
		"CRUSHED!" => [:CRUSHGRIP],
		"The magnetic field is strengthened!" => [:MAGNETBOMB],
		"The power of the earth is utterly overwhelming!"  => [:THOUSANDARROWS, :THOUSANDWAVES, :LANDSWRATH, :PRECIPICEBLADES, :TECTONICRAGE],
		"The power of ages gone by..." => [:ANCIENTPOWER],
		"The power of the core obliterates all!" => [:COREENFORCER],
		"The intense gravity is ruptured!" => [:SPACIALREND],
	},
	:typeMods => {},
	:typeAddOns => {
	},
	:moveEffects => {},
	:typeBoosts => {
		1.3 => [:ROCK, :PSYCHIC],
		1.5 => [:GROUND],
	},
	:typeMessages => {
		"The core's magical forces are immense!" => [:PSYCHIC],
		"The earth empowered the attack!" => [:ROCK, :GROUND],
	},
	:typeCondition => {
		:GROUND => "!opponent.hasType?(:GROUND)",
	},
	:typeEffects => {},
	:changeCondition => {
	},
	:fieldChange => {
	},
	:dontChangeBackup => [],
	:changeMessage => {
	},
	:statusMods => [:AUTOTOMIZE, :GEOMANCY, :ROTOTILLER, :MAGNETFLUX, :EERIEIMPULSE, :MAGNETRISE, :GRAVITY, :TOPSYTURVY, :SEISMICTOSS, :PSYWAVE],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => nil,
		:duration => nil,
		:message => "{1}'s weight increased!",
		:animation => :QUASH,
		:stats => {
			:DEFENSE => 1,
		}
	},
},
:BACKALLEY => {
	:name => "Backalley",
	:fieldMessage => [
		"Shifty eyes are all around..."
	],
	:graphic => ["Under"],
	:secretPower => "SMOG",
	:naturePower => :BEATUP,
	:mimicry => :STEEL,
	:damageMods => {
		1.5 => [:STEAMROLLER, :SMOG, :BEATUP, :PAYDAY, :INFESTATION, :SPECTRALTHIEF, :FIRSTIMPRESSION, :TECHNOBLAST, :SHADOWSNEAK,
			:XSCISSOR, :FURYCUTTER, :NIGHTSLASH, :SACREDSWORD, :AIRSLASH, :AERIALACE, :AIRCUTTER, :LEAFBLADE, :RAZORLEAF, :SLASH, :CUT, :CROSSPOISON, :PSYCHOCUT, :RAZORSHELL, :SOLARBLADE, :BEHEMOTHBLADE, :CEASELESSEDGE, :STONEAXE, :AQUACUTTER,
			:HORNATTACK, :FURYATTACK, :POISONSTING, :TWINEEDLE, :PINMISSILE, :PECK, :DRILLPECK, :MEGAHORN, :POISONJAB, :NEEDLEARM, :PLUCK, :DRILLRUN, :HORNLEECH, :FELLSTINGER, :SMARTSTRIKE, :BRANCHPOKE, :FALSESURRENDER, :GLACIALLANCE],
	},
	:accuracyMods => {
		0 => [:SMOG, :POISONGAS],
	},
	:moveMessages => {
		"The power of science is amazing!" => [:TECHNOBLAST],
		"A crowd is gathering!" => [:BEATUP],
		"The city smog is suffocating!" => [:SMOG],
		"Careful on the street!" => [:STEAMROLLER],
		"Gotta make ends meet somehow..." => [:PAYDAY, :SPECTRALTHIEF, :SHADOWSNEAK],
		"A frightening first impression!" => [:FIRSTIMPRESSION],
		"A knife glints in the dark!" => [:XSCISSOR, :FURYCUTTER, :NIGHTSLASH, :SACREDSWORD, :AIRSLASH, :AERIALACE, :AIRCUTTER, :LEAFBLADE, :RAZORLEAF, :SLASH, :CUT, :CROSSPOISON, :PSYCHOCUT, :RAZORSHELL, :SOLARBLADE, :BEHEMOTHBLADE, :CEASELESSEDGE, :STONEAXE, :AQUACUTTER],
		"Better watch your back..." => [:HORNATTACK, :FURYATTACK, :POISONSTING, :TWINEEDLE, :PINMISSILE, :PECK, :DRILLPECK, :MEGAHORN, :POISONJAB, :NEEDLEARM, :PLUCK, :DRILLRUN, :HORNLEECH, :FELLSTINGER, :SMARTSTRIKE, :BRANCHPOKE, :FALSESURRENDER, :GLACIALLANCE],
	},
	:typeMods => {
		:DARK => [:FIRSTIMPRESSION],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:DARK],
		1.3 => [:POISON, :BUG, :STEEL],
		0.5 => [:FAIRY],
	},
	:typeMessages => {
		"Street rules!" => [:DARK],
		"The right tool for the job!" => [:STEEL],
		"In the cracks and the walls!" => [:BUG],
		"All kinds of pollution strengthened the attack!" => [:POISON],
		"This is no place for fairytales..." => [:FAIRY],
	},
	:typeCondition => {
		:DARK => "self.pbIsPhysical?(@type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:CITY => [:UPROAR,:HYPERVOICE,:ECHOEDVOICE,:BOOMBURST],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"Cops! Everyone scatter!" => [:UPROAR,:HYPERVOICE,:ECHOEDVOICE,:BOOMBURST],
	},
	:statusMods => [:SMOKESCREEN, :NASTYPLOT, :PARTINGSHOT, :FAKETEARS, :POISONGAS, :SMOG, :TRICK, :SWITCHEROO, :CORROSIVEGAS, :SNATCH],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:ACCURACY => 1,
		},
	},
},
:CITY => {
	:name => "City",
	:fieldMessage => [
		"The streets are busy..."
	],
	:graphic => ["City"],
	:secretPower => "SMOG",
	:naturePower => :SMOG,
	:mimicry => :NORMAL,
	:damageMods => {
		1.5 => [:STEAMROLLER, :SMOG, :BEATUP, :PAYDAY, :FIRSTIMPRESSION, :TECHNOBLAST],
	},
	:accuracyMods => {
		0 => [:SMOG, :POISONGAS],
	},
	:moveMessages => {
		"The power of science is amazing!" => [:TECHNOBLAST],
		"A crowd is gathering!" => [:BEATUP],
		"The city smog is suffocating!" => [:SMOG],
		"Careful on the street!" => [:STEAMROLLER],
		"Working 9 to 5 for this!" => [:PAYDAY],
		"An overwhelming first impression!" => [:FIRSTIMPRESSION],
	},
	:typeMods => {
		:NORMAL => [:FIRSTIMPRESSION],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:NORMAL],
		1.3 => [:POISON, :BUG, :STEEL],
		0.7 => [:FAIRY],
	},
	:typeMessages => {
		"The hustle and bustle of the city!" => [:NORMAL],
		"The power of science is amazing!" => [:STEEL],
		"In the cracks and the walls!" => [:BUG],
		"All kinds of pollution strengthened the attack!" => [:POISON],
		"This is no place for fairytales..." => [:FAIRY],
	},
	:typeCondition => {
		:NORMAL => "self.pbIsPhysical?(@type)",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {
		:BACKALLEY => [:THIEF,:COVET,:PURSUIT],
	},
	:dontChangeBackup => [],
	:changeMessage => {
		"The criminal ran into a backalley!" => [:THIEF,:COVET,:PURSUIT],
	},
	:statusMods => [:SMOKESCREEN, :WORKUP, :AUTOTOMIZE, :SHIFTGEAR, :POISONGAS, :SMOG, :RECYCLE, :CORROSIVEGAS],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => 0,
		:duration => 0,
		:message => "",
		:animation => nil,
		:stats => {
			:ATTACK => 1,
			:ACCURACY => 1,
		},
	},
},
:ENCHANTEDFOREST => {
	:name => "Enchanted Forest",
	:fieldMessage => [
		"Once upon a time!"
	],
	:graphic => ["EnchantedForest"],
	:secretPower => "DAZZLINGGLEAM",
	:naturePower => :DAZZLINGGLEAM,
	:mimicry => :FAIRY,
	:damageMods => {
		1.5 => [:HEX, :MYSTICALFIRE, :SPIRITBREAK, :MAGICALTORQUE, :FLEURCANNON, :RELICSONG,
		        :AIRSLASH, :AQUACUTTER, :BEHEMOTHBLADE, :CEASELESSEDGE, :LEAFBLADE, :NIGHTSLASH, 
		        :PSYCHOCUT, :RAZORSHELL, :SMARTSTRIKE, :SOLARBLADE, :STONEAXE, :TACHYONCUTTER, 
		        :BITTERBLADE, :PSYBLADE],
		1.4 => [:AURORABEAM, :BUBBLEBEAM, :CHARGEBEAM, :HYPERBEAM, :ICEBEAM, 
		        :PSYBEAM, :SIGNALBEAM, :TWINBEAM],
		1.2 => [:DARKPULSE, :MOONBLAST, :NIGHTDAZE, :BLOODMOON],
	},
	:accuracyMods => {
		85 => [:GRASSWHISTLE, :POISONPOWDER, :SLEEPPOWDER, :STUNSPORE],
	},
	:moveMessages => {
		"Magic aura amplified the attack!" => [:HEX, :MYSTICALFIRE, :SPIRITBREAK, :MAGICALTORQUE, :FLEURCANNON, :RELICSONG],
		"The Knight is Justified!" => [:AIRSLASH, :AQUACUTTER, :BEHEMOTHBLADE, :CEASELESSEDGE, :LEAFBLADE, :NIGHTSLASH, 
		                                :PSYCHOCUT, :RAZORSHELL, :SMARTSTRIKE, :SOLARBLADE, :STONEAXE, :TACHYONCUTTER, 
		                                :BITTERBLADE, :PSYBLADE],
		"Magic aura amplified the beams!" => [:AURORABEAM, :BUBBLEBEAM, :CHARGEBEAM, :HYPERBEAM, :ICEBEAM, 
		                                      :PSYBEAM, :SIGNALBEAM, :TWINBEAM],
		"It was a curse!" => [:DARKPULSE, :MOONBLAST, :NIGHTDAZE, :BLOODMOON],
	},
	:typeMods => {},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.5 => [:FAIRY, :GRASS, :POISON],
		1.3 => [:DARK],
		1.2 => [:STEEL],
	},
	:typeMessages => {
		"The enchanted aura boosted the attack!" => [:FAIRY, :STEEL],
		"Flourish!" => [:GRASS],
		"Poison seeps from the darkness!" => [:POISON],
		"Not all fairy tales..." => [:DARK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:FORESTSCURSE, :MAGICPOWDER, :MOONLIGHT, :STRENGTHSAP],
	:changeEffects => {},
	:seed => {
		:seedtype => :MAGICALSEED,
		:effect => nil,
		:duration => nil,
		:message => nil,
		:animation => nil,
		:stats => {
			:SPECIAL_DEFENSE => 1,
		},
	},
	},
:SAHARA => {
	:name => "Sahara",
	:fieldMessage => [
		"The air is dry and humid."
	],
	:graphic => ["Sahara"],
	:secretPower => "NEEDLEARM",
	:naturePower => :NEEDLEARM,
	:mimicry => :GROUND,
	:damageMods => {
		1.5 => [:NEEDLEARM, :OVERHEAT, :PINMISSILE, :ROCKWRECKER, :SANDTOMB, :SCORCHINGSANDS, :ATTACKORDER, :BUGBUZZ],
		0.8 => [:WATER],
	},
	:accuracyMods => {},
	:moveMessages => {
		"The dry earth boosted the attack!" => [:NEEDLEARM, :OVERHEAT, :PINMISSILE, :ROCKWRECKER, :SANDTOMB, :SCORCHINGSANDS],
		"They're coming out of the woodwork!" => [:ATTACKORDER, :BUGBUZZ],
		"The water evaporated!" => [:WATER],
	},
	:typeMods => {
		:WATER => [:ICE],
	},
	:typeAddOns => {},
	:moveEffects => {},
	:typeBoosts => {
		1.3 => [:BUG, :FIRE, :GROUND, :ROCK],
	},
	:typeMessages => {
		"The humid air boosted the attack!" => [:BUG, :FIRE, :GROUND, :ROCK],
	},
	:typeCondition => {},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [:SANDATTACK, :DEFENDORDER, :SILVERWIND],
	:changeEffects => {},
	:seed => {
		:seedtype => :TELLURICSEED,
		:effect => nil,
		:duration => nil,
		:message => nil,
		:animation => nil,
		:stats => {
			:DEFENSE => 1,
		},
	},
	},
:POISONLIBRARY => {
	:name => "Poison Library",
	:fieldMessage => [
		"The library is seeping knowledge."
	],
	:graphic => ["PoisonLibrary"],
	:secretPower => "ACID",
	:naturePower => :ACID,
	:mimicry => :POISON,
	:damageMods => {},
	:accuracyMods => {},
	:moveMessages => {},
	:typeMods => {},
	:typeAddOns => {
		:POISON => [:GRASS],
		:FAIRY => [:PSYCHIC],
	},
	:moveEffects => {},
	:typeBoosts => {
		1.4 => [:POISON],
		1.2 => [:GRASS, :FIRE, :FAIRY],
	},
	:typeMessages => {
		"The Poison permeates through the field!" => [:POISON],
		"The library is overgrown!" => [:GRASS],
		"Alexandria!" => [:FIRE],
		"The power of knowledge!" => [:FAIRY],
	},
	:typeCondition => {
		:POISON => "!attacker.isAirborne?",
	},
	:typeEffects => {},
	:changeCondition => {},
	:fieldChange => {},
	:dontChangeBackup => [],
	:changeMessage => {},
	:statusMods => [],
	:changeEffects => {},
	:seed => {
		:seedtype => :SYNTHETICSEED,
		:effect => nil,
		:duration => nil,
		:message => nil,
		:animation => nil,
		:stats => {
			:SPECIAL_ATTACK => 1,
		},
	},
}
}
