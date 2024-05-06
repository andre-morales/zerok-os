package com.andre.pasme;

import com.andre.pasme.transpiler.Transpiler;
import com.andre.pasme.transpiler.TranspilerException;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Scanner;

/**
 * CLI interface of Pasme. It must be instantiated and have its run() method
 * called with an order.
 * <br>
 * <br> Last edit: 05/05/2024
 * 
 * @author André Morales
 * @version 1.2.2
 */
public class PasmeCLI {
	public static final String VERSION_STR = "1.2.2";
	
	/**
	 * Runs Pasme with CLI arguments
	 * 
	 * @param args Arguments.
	 */
	public boolean run(String[] args) {	
		if (args.length == 0) {
			printHeader();
			System.out.println("Nothing to do here. To view a list of possible commands, run 'pasme help'.");
			return true;
		}

		return interpretOrder(args);
	}
	
	/**
	 * Interprets an order. An order could be to transpile, to assemble,
	 * to burn an image.
	 * 
	 * @param orderLine An order followed by its switches and arguments.
	 */
	boolean interpretOrder(String[] orderLine) {
		var order = orderLine[0];
		
		switch(order) {
			case "help" -> helpOrder(orderLine);
			case "transpile" -> { return transpileOrder(orderLine); }
			default -> throw new CLIException("Unknown order type [" + order + "].");
		}
		return true;
	}
	
	/** Invokes the Pasme transpiler on an input file and saves
	 * the resulting assembly on another file.
	 * <br><br>
	 * Switches: <br>
	 * -to: Specifies where to save the .asm file
	 * -I: Specifies an include directory
	 * -D: Defines a preprocessor string 
	 * 
	 * @param orderLine A transpile order followed by its switches and arguments.
	 **/
	boolean transpileOrder(String[] orderLine) {
		String input = null;
		String output = null;
		List<String> includes = new ArrayList<>();
		Map<String, String> defines = new HashMap<>();
		
		// Interpret order arguments
		for (int i = 1; i < orderLine.length; i++) {
			var arg = orderLine[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					case "-to" -> output = orderLine[++i];
					case "-I" -> includes.add(orderLine[++i]);
					case "-D" -> {
						// Get define string from the order 
						var defineExpr = orderLine[++i];
						
						// If defining a constant to a value or just the existance of the constant
						if (defineExpr.contains("=")) {
							var sp = defineExpr.split("=", 2);
							var name = sp[0].trim();
							var value = sp[1].trim();
							defines.put(name, value);
						} else {
							defines.put(defineExpr, "");
						}
						
					}
				}
			} else {
				if (input != null) {
					throw new CLIException("Argument " + arg + " specifies an input but an input was already provided before.");
				}
				
				input = arg;
			}
		}
		
		if (input == null) throw new CLIException("No input was specified!");
		if (output == null) throw new CLIException("No output was specified! Use the -to switch do so.");
		
		System.out.println("Transpiling '" + input + "' to '" + output + "'");
		
		var tr = new Transpiler();
		tr.setIncludePaths(includes);
		tr.setDefines(defines);
		
		try {
			tr.transpile(new File(input), new File(output));
		} catch(TranspilerException te) {
			System.err.println("-- Transpilation of '" + input + "' failed! --");
			Throwable cause = te;
			while (cause != null) {
				System.err.println(": " + cause.getMessage());
				cause = cause.getCause();
			}
			return false;
		}
		return true;
	}
		
	/**
	 * Prints the CLI help text on the console.
	 * 
	 * @param orderLine Ignored as of this version.
	 */
	void helpOrder(String[] orderLine) {
		printHeader();
		
		var stream = getClass().getResourceAsStream("/res/help.txt");
		
		try (var scan = new Scanner(stream)) {
			while (scan.hasNextLine()) {
				System.out.println(scan.nextLine());
			}
		}
	}
		
	/** Prints the Pasme header with version. */
	void printHeader() {
		System.out.println("-- Pasme Version " + VERSION_STR);
	}
}
