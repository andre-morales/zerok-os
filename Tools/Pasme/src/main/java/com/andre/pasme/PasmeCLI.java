package com.andre.pasme;

import com.andre.pasme.transpiler.Transpiler;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Scanner;

/**
 * CLI interface of Pasme. It must be instantiated and have its run() method
 * called with an order.
 * <br>
 * <br> Last edit: 30/04/2023
 * 
 * @author André Morales
 * @version 1.1.0
 */
public class PasmeCLI {
	public static final String VERSION_STR = "1.2.0";
	private static final String ASSEMBLER_CMD = "YASM";	
	
	/**
	 * Runs Pasme with CLI arguments
	 * 
	 * @param args Arguments.
	 */
	public void run(String[] args) {	
		if (args.length == 0) {
			printHeader();
			System.out.println("Nothing to do here. To view a list of possible commands, run 'pasme help'.");
			return;
		}

		interpretOrder(args);
	}
	
	/**
	 * Interprets an order. An order could be to transpile, to assemble,
	 * to burn an image.
	 * 
	 * @param orderLine An order followed by its switches and arguments.
	 */
	void interpretOrder(String[] orderLine) {
		var order = orderLine[0];
		
		switch(order) {
		case "help" -> helpOrder(orderLine);
		case "transpile" -> transpileOrder(orderLine);
		case "assemble" -> assembleOrder(orderLine);
		case "burn" -> burnOrder(orderLine);
		case "mountdisk" -> mountDiskOrder(orderLine);
		case "unmountdisk" -> unmountDiskOrder(orderLine);
		default -> throw new CLIException("Unknown order type [" + order + "].");
		}
	}
	
	/**
	 * Invokes the Assembler program on an input .asm file and saves
	 * the resulting binary.
	 * <br><br>
	 * Switches: <br>
	 * -to: Specifies where to save the assembled binary.
	 * 
	 * @param orderLine An assemble order and its arguments.
	 */
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

	/**
	 * Invokes the Pasme transpiler on an input file and saves
	 * the resulting assembly on another file.
	 * <br><br>
	 * Switches: <br>
	 * -to: Specifies where to save the .asm file
	 * -I: Specifies an include directory
	 * -D: Defines a preprocessor string 
	 * 
	 * @param orderLine A transpile order followed by its switches and arguments.
	 */
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
	
	/**
	 * Writes a file or part of it into another file. Often used to burn
	 * bootloaders on a disk.
	 * <br><br>
	 * Switches: <br>
	 * -to: Specifies the destination file where the input will be written.
	 * -srcOff: An offset into the input file. By default 0.
	 * -dstOff: An offset into the destination file. By default 0.
	 * -length: How many bytes to record. If not specified, the whole input will
	 * be written.
	 * 
	 * @param orderLine A burn order followed by its switches and arguments.
	 */
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
	
	/**
	 * Mounts a virtual disk file. Requires no switches, only an input argument.
	 */
	void mountDiskOrder(String[] order) {
		String diskPathArg = null;
		
		// Interpret order arguments
		for (int i = 1; i < order.length; i++) {
			var arg = order[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					default -> throw new CLIException("Unknown switch: " + arg);
				}
			} else {
				if (diskPathArg != null) {
					throw new CLIException("Argument " + arg + " specifies a disk but a disk was already provided before.");
				}
				
				diskPathArg = arg;
			}
		}
		
		if (diskPathArg == null) throw new CLIException("No disk was specified!");
		
		try {
			var absDiskPath = new File(diskPathArg).getCanonicalPath();
			
			var script = Files.createTempFile(null, ".dps");
			var writer = new FileWriter(script.toFile());
			
			writer.write("select vdisk file=\"" + absDiskPath + "\"\n");
			writer.write("attach vdisk");
			
			writer.close();
			
			int returnCode = execSilently("diskpart", "/s", script.toString());
			if (returnCode != 0) throw new CLIException("Diskpart failed with code " + returnCode);
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	/**
	 * Unmounts a virtual disk file. Requires no switches, only an input argument.
	 */
	void unmountDiskOrder(String[] order) {
		String diskPathArg = null;
		
		// Interpret order arguments
		for (int i = 1; i < order.length; i++) {
			var arg = order[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					default -> throw new CLIException("Unknown switch: " + arg);
				}
			} else {
				if (diskPathArg != null) {
					throw new CLIException("Argument " + arg + " specifies a disk but a disk was already provided before.");
				}
				
				diskPathArg = arg;
			}
		}
		
		if (diskPathArg == null) throw new CLIException("No disk was specified!");
		
		try {
			var absDiskPath = new File(diskPathArg).getCanonicalPath();
			
			var script = Files.createTempFile(null, ".dps");
			var scriptFile = script.toFile();
			try (var writer = new FileWriter(scriptFile)) {
				writer.write("select vdisk file=\"" + absDiskPath + "\"\n");
				writer.write("detach vdisk");
			}
			
			int returnCode = execSilently("diskpart", "/s", script.toString());
			if (returnCode != 0) throw new CLIException("Diskpart failed with code " + returnCode);
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
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
	
	/**
	 * Runs a program with optional CLI arguments. The program will have all of
	 * its output redirected to stdout. This function only returns when the
	 * process has finished running completely.
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
	
	/**
	 * Runs a program with optional CLI arguments. This function only returns when the
	 * process has finished running completely.
	 * 
	 * @param cmd The program command followed by its arguments.
	 * @return The return code of the program.
	 */
	static int execSilently(String... cmd) {
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
						
			// After the program is done running, drain the rest of the output.
			int returnCode = proc.waitFor();
			return returnCode;
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	/**
	 * Converts a fancy number string into a number.
	 * Examples:
	 * "0x30"        -> 48
	 * "0x30 + 2"    -> 50
	 * "0x30 + 0x30" -> 96
	 * 
	 * @param str The string to convert. Can be in base 10, 16, or a mix of both.
	 * @return Converted number.
	 */
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
