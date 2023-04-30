package com.andre.pasme;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 *
 * @author Andre
 */
public class PasmeCLI {
	private static final String ASSEMBLER_CMD = "YASM";	
	
	public void run(String[] args) {
		if (args.length == 0) {
			System.out.println("-- Pasme Version 1.0 SNAP 1");
			return;
		}
		
		interpretOrder(args);
	}
	
	void interpretOrder(String[] orderLine) {
		var order = orderLine[0];
		
		switch(order) {
		case "help" -> helpOrder(orderLine);
		case "transpile" -> transpileOrder(orderLine);
		case "assemble" -> assembleOrder(orderLine);
		case "burn" -> burnOrder(orderLine);
		default -> throw new CLIException("Unknown order type [" + order + "].");
		}
	}
	
	void assembleOrder(String[] orderLine) {
		String input = null;
		String output = null;
		
		// Interpret order arguments
		for (int i = 1; i < orderLine.length; i++) {
			var arg = orderLine[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					case "-to" -> output = orderLine[++i];
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
		
		System.out.println("Assembling '" + input + "' to '" + output + "'");
		try {
			int result = exec(ASSEMBLER_CMD, input, "-o" + output);
			if (result != 0) {
				throw new AssemblerException("Assembling failed! Assembler returned [" + result + "]");
			}
		} catch (ProgramNotFoundException e){
			throw new RuntimeException("Failed to run the assembler program [" + ASSEMBLER_CMD + "]. Is it installed on PATH?", e);
		}
	}

	void transpileOrder(String[] orderLine) {
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
					case "-D" -> defines.put(orderLine[++i], "1");
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
		tr.includePaths = includes;
		tr.defines = defines;
		tr.transpile(new File(input), new File(output));
	}
	
	void burnOrder(String[] orderLine) {
		String input = null;
		String output = null;
		int inputOffset = 0;
		int outputOffset = 0;
		int fileLength = Integer.MAX_VALUE;
		
		// Interpret order arguments
		for (int i = 1; i < orderLine.length; i++) {
			var arg = orderLine[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					case "-srcOff" -> inputOffset = parseNumber(orderLine[++i]);
					case "-dstOff" -> outputOffset = parseNumber(orderLine[++i]);
					case "-length" -> fileLength = parseNumber(orderLine[++i]);
					case "-to" -> output = orderLine[++i];
					default -> throw new CLIException("Unknown switch: " + arg);
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
		
		System.out.print("Burning '" + input + "'[0x" + Integer.toHexString(inputOffset).toUpperCase());
		System.out.print("] to '" + output + "'[0x" + Integer.toHexString(outputOffset).toUpperCase() + "] ");
		if (fileLength == Integer.MAX_VALUE) {
			System.out.println("fully");
		} else {
			System.out.println("with " + fileLength + " bytes");
		}
		
		try {
			// Open output disk file
			var diskPath = new File(output).toPath();
			var diskStream = FileChannel.open(diskPath, StandardOpenOption.WRITE);
			diskStream.position(outputOffset);
			
			// Open input file
			var inputFile = new File(input);
			var inputSize = inputFile.length();
			var inputStream = FileChannel.open(inputFile.toPath(), StandardOpenOption.READ);
			inputStream.position(inputOffset);			
			
			// Prevent an overflow if the specified input offset and length would do so.
			long len = Math.min(inputSize - inputOffset, fileLength);
			
			// Byte writing loop
			var bb = ByteBuffer.allocate(1);
			int b;
			for (long i = 0; i < len; i++) {
				while ((b = inputStream.read(bb)) == 0) {
					if (b == -1) {
						throw new IOException("-1.");
					}
				}
				bb.flip();
				while (diskStream.write(bb) == 0) {
				}
				bb.flip();
			}
			
			// Release resources
			diskStream.close();
			inputStream.close();
			
			System.out.println("Written " + len + " bytes.");
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	void helpOrder(String[] orderLine) {
			
	}
	
	/**
	 * Runs a program with optional CLI arguments. This method always waits for
	 * the program to finish completely and dumps all of its output into stdout.
	 * 
	 * @param cmd The program command followed by its arguments.
	 * @return The return code of the program.
	 */
	static int exec(String... cmd) {
		try {
			Process proc;
			
			// Build the process and start it. If the program command couldn't be found, throw a dedicated exception.
			try {
				var procBuilder = new ProcessBuilder(cmd);
				procBuilder.redirectErrorStream(true);
				proc = procBuilder.start();
			} catch(IOException e){
				throw new ProgramNotFoundException(e);
			}
			
			// While the program is running, print all its output.
			var input = proc.getInputStream();
			while (proc.isAlive()) {
				int c = input.read();
				if (c > 0) {
					System.out.print((char) c);
				}
			}
			
			// After the program is done running, drain the rest of the output.
			int returnCode = proc.waitFor();
			int c;
			while ((c = input.read()) > 0) {
				System.out.print((char) c);
			}

			return returnCode;
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	static int parseNumber(String str){
		str = str.trim();
		
		int p = str.indexOf("+");
		if(p != -1){
			var a = parseNumber(str.substring(0, p));
			var b = parseNumber(str.substring(p + 1));
			return a + b;
		}
		
		if (str.startsWith("0x")) {
			return Integer.parseInt(str.substring(2), 16);
		}
		
		// Treat number as base 10 by default
		return Integer.parseInt(str, 10);
	}	
}
