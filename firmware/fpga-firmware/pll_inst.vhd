pll_inst : pll PORT MAP (
		areset	 => areset_sig,
		clkswitch	 => clkswitch_sig,
		inclk0	 => inclk0_sig,
		inclk1	 => inclk1_sig,
		c0	 => c0_sig,
		locked	 => locked_sig
	);
