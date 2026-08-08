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
	(cu-vapor fluid
		(chemical-formula . #f)
		(specific-heat (polynomial piecewise-linear (2895. . 1082.) (3000. . 2468.) (4000. . 4077.) (5000. . 2525.) (6000. . 362.) (7000. . 1320.) (8000. . 1559.) (9000. . 1890.) (10000. . 2122.) (11000. . 2342.) (12000. . 2597.) (13000. . 2712.) (14000. . 2878.) (15000. . 3639.) (16000. . 5191.) (17000. . 7231.) (18000. . 9166.) (19000. . 10577.) (19500. . 10600.) (20000. . 10963.) (21000. . 9600.) (22000. . 9137.) (24000. . 6884.) (26000. . 5407.) (28000. . 5599.) (30000. . 5302.)) (constant . 1006.43) (polynomial piecewise-polynomial (100 1000 1161.48214452351 -2.36881890191577 0.0148551108358867 -5.03490927522584e-05 9.9285695564579e-08 -1.11109658897742e-10 6.54019600406048e-14 -1.57358768447275e-17) (1000 3000 -7069.81410143802 33.7060506468204 -0.0581275953375815 5.42161532229608e-05 -2.936678858119e-08 9.237533169567681e-12 -1.56555339604519e-15 1.11233485020759e-19)) (polynomial nasa-9-piecewise-polynomial (200. 1000. 2898903. -56496.26 1437.799 -1.653609 0.003062254 -2.279138e-06 6.272365e-10) (1000. 6000. 69324940. -361053.2 1476.665 -0.06138349 2.027963e-05 -3.075525e-09 1.888054e-13)))
		(thermal-conductivity (polynomial piecewise-linear (2895. . 1.72) (4000. . 0.43) (5000. . 0.3) (6000. . 0.34) (7000. . 0.42) (8000. . 0.55) (9000. . 0.76) (10000. . 1.03) (11000. . 1.33) (12000. . 1.61) (13000. . 1.81) (14000. . 2.13) (15000. . 2.19) (16000. . 2.79) (17000. . 3.31) (18000. . 3.77) (19000. . 4.22) (20000. . 4.53) (21000. . 4.7) (22000. . 4.81) (23000. . 4.93) (24000. . 5.1) (25000. . 5.3) (26000. . 5.59) (27000. . 5.9) (28000. . 6.25) (29000. . 6.62) (30000. . 7.01)) (constant . 0.0242))
		(viscosity (polynomial piecewise-linear (2895. . 0.0001026) (3000. . 0.000147) (4000. . 0.00016) (5000. . 0.000178) (6000. . 0.000200984) (7000. . 0.000223039) (10000. . 0.000274564) (13600. . 0.0003) (14000. . 0.000308546) (15000. . 0.000298823) (16000. . 0.00026779) (17000. . 0.000219522) (18000. . 0.000167512) (19000. . 0.000122003) (20000. . 9.09e-05) (23000. . 4.2e-05) (26000. . 2.98e-05) (30000. . 2.66e-05)) (constant . 1.7894e-05) (sutherland 1.716e-05 273.11 110.56) (power-law 1.716e-05 273.11 0.666) (blottner-curve-fit 0.0307 0.23 -10.8))
		(density (ideal-gas . #f) (constant . 1))
		(molecular-weight (constant . 63.546))
		(formation-enthalpy (constant . -337200000.))
		(reference-temperature (constant . 298.15))
		(therm-exp-coeff (constant . 0))
		(melting-heat (constant . 2052000.))
		(tsolidus (constant . 0.))
		(tliqidus (constant . 0.))
		(uds-diffusivity (defined-per-uds (uds-1 (constant . 1)) (uds-2 (constant . 1)) (uds-3 (constant . 1)) (uds-4 (constant . 1)) (uds-5 (constant . 1)) (uds-6 (constant . 1)) (uds-7 (constant . 1)) (uds-8 (constant . 1)) (uds-9 (constant . 1)) (uds-10 (constant . 1)) (uds-11 (constant . 1)) (uds-12 (constant . 1)) (uds-13 (constant . 1)) (uds-14 (constant . 1)) (uds-15 (constant . 1)) (uds-16 (constant . 1)) (uds-17 (constant . 1)) (uds-18 (constant . 1)) (uds-19 (constant . 1)) (uds-20 (constant . 1)) (uds-21 (constant . 1)) (uds-22 (constant . 1)) (uds-23 (constant . 1)) (uds-24 (constant . 1)) (uds-25 (constant . 1)) (uds-26 (constant . 1)) (uds-27 (constant . 1)) (uds-28 (constant . 1)) (uds-29 (constant . 1)) (uds-30 (constant . 1)) (uds-31 (constant . 1)) (uds-32 (constant . 1)) (uds-33 (constant . 1)) (uds-34 (constant . 1)) (uds-35 (constant . 1)) (uds-36 (constant . 1)) (uds-37 (constant . 1)) (uds-38 (constant . 1)) (uds-39 (constant . 1)) (uds-40 (constant . 1)) (uds-41 (constant . 1)) (uds-42 (constant . 1)) (uds-43 (constant . 1)) (uds-44 (constant . 1)) (uds-45 (constant . 1)) (uds-46 (constant . 1)) (uds-47 (constant . 1)) (uds-48 (constant . 1)) (uds-49 (constant . 1)) (uds-0 (constant . 59530000.) (user-defined "uds0_diff::libudf"))))
		(speed-of-sound (none . #f))
	)

)
