;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                              ;;;
;;;             Fluent USER DEFINED MATERIAL DATABASE            ;;;
;;;                                                              ;;;
;;; (name type[fluid/solid] (chemical-formula . formula)         ;;;
;;;             (prop1 (method1a . data1a) (method1b . data1b))  ;;;
;;;            (prop2 (method2a . data2a) (method2b . data2b)))  ;;;
;;;                                                              ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(
	(cu-solid fluid
		(chemical-formula . cu-solid)
		(density (polynomial piecewise-linear (273.15 . 8930.) (400. . 8884.) (600. . 8787.) (800. . 8642.) (1000. . 8568.) (1200. . 8458.) (1300. . 8022.) (1500. . 7850.) (1700. . 7709.) (1900. . 7562.) (2100. . 7405.) (2300. . 7238.) (2500. . 7082.) (2700. . 6923.) (2900. . 6763.)) (constant . 2719.))
		(specific-heat (polynomial piecewise-linear (273.15 . 386.) (400. . 396.) (600. . 431.) (800. . 448.) (1000. . 466.) (1200. . 480.) (1300. . 481.) (1500. . 482.) (1700. . 483.) (1900. . 485.) (2100. . 485.) (2300. . 486.) (2500. . 487.) (2700. . 487.) (2900. . 489.)) (polynomial piecewise-polynomial (300. 600. 843.35167 -0.1821896 -0.00012430563 7.156291800000001e-07 -5.2557973e-10) (600. 5000. 788.73643 -0.032763207 2.2195489e-05 -6.5361777e-09 7.0548676e-13)))
		(molecular-weight (constant . 63.546))
		(formation-enthalpy (constant . -13590000.))
		(reference-temperature (constant . 298.15))
		(formation-entropy (constant . 164451.4))
		(species-phase (constant . 1))
		(boiling-point (constant . 2792))
		(critical-pressure (constant . 91230000.))
		(critical-temperature (constant . 6299.))
		(critical-volume (constant . 0.00141))
		(thermal-conductivity (polynomial piecewise-linear (273.15 . 401.) (400. . 393.) (600. . 379.) (800. . 366.) (1000. . 352.) (1200. . 339.) (1300. . 147.) (1500. . 147.) (1700. . 147.) (1900. . 148.) (2100. . 148.) (2300. . 149.) (2500. . 149.) (2700. . 150.) (2900. . 150.)) (constant . 0.0454))
		(viscosity (polynomial piecewise-linear (1300. . 0.0042) (1380. . 0.0039) (1460. . 0.0034) (1543. . 0.0031) (1643. . 0.0027) (1743. . 0.0024) (1793. . 0.0023) (2400. . 0.0021) (2900. . 0.0019)) (constant . 0.0042))
		(therm-exp-coeff (constant . 0))
		(melting-heat (constant . 2052000.))
		(tsolidus (constant . 1293.))
		(tliqidus (constant . 1293.))
		(speed-of-sound (none . #f))
	)

)
