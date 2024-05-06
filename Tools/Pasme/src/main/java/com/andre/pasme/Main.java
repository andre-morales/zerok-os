package com.andre.pasme;

/**
 * Main class when running Pasme CLI
 * <br>
 * <br>Last edit: 30/04/2023
 * @author André Morales
 */
public class Main {
	public static void main(String[] args) {
		boolean success = new PasmeCLI().run(args);
		if (!success) {
			System.exit(-1);
		}
	}
}
