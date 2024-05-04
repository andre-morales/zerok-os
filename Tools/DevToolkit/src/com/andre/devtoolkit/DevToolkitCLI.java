package com.andre.devtoolkit;

import java.io.File;
import java.util.Scanner;

/**
 * CLI interface of DevToolkit. It must be instantiated and have its run() method
 * called with an order.
 * <br>
 * <br> Last edit: 30/04/2023
 * 
 * @author André Morales
 * @version 1.1.0
 */
public class DevToolkitCLI {
	public static final String VERSION_STR = "0.1.2";
	/**
	 * Runs DevToolkit with CLI arguments
	 * 
	 * @param args Arguments.
	 */
	public void run(String[] args) {	
		if (args.length == 0) {
			printHeader();
			System.out.println("Nothing to do here. To view a list of possible commands, run 'devtk help'.");
			return;
		}

		interpretOrder(args);
	}
	
	/**
	 * Interprets an order.
	 * 
	 * @param orderLine An order followed by its switches and arguments.
	 */
	void interpretOrder(String[] orderLine) {
		var order = orderLine[0];
		
		switch(order) {
		case "help" -> helpOrder(orderLine);
		case "burn" -> burnOrder(orderLine);
		case "burn-vbr" -> burnVBROrder(orderLine);
		case "burn-reserved-sectors" -> burnReservedSectorsOrder(orderLine);
		case "mount" -> mountOrder(orderLine);
		case "unmount" -> unmountOrder(orderLine);
		case "syncdisk" -> syncDiskOrder(orderLine);
		case "partitions" -> partitionsOrder(orderLine);
		default -> throw new CLIException("Unknown order type [" + order + "].");
		}
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
					case "-srcOff" -> inputOffset = parseNumberExpression(orderLine[++i]);
					case "-dstOff" -> outputOffset = parseNumberExpression(orderLine[++i]);
					case "-length" -> fileLength = parseNumberExpression(orderLine[++i]);
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
		
		// Open output disk file
		var diskPath = new File(output);

		// Open input file
		var inputFile = new File(input);

		var written = Burner.transfer(inputFile, inputOffset, diskPath, outputOffset, fileLength);

		System.out.println("Written " + written + " bytes.");
	}
	
	void burnVBROrder(String[] orderLine) {
		String input = null;
		String output = null;
		int inputOffset = 0;
		int partitionNumber = -1;
		long fileLength = -1;
		
		// Interpret order arguments
		for (int i = 1; i < orderLine.length; i++) {
			var arg = orderLine[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					case "-srcOff" -> inputOffset = parseNumberExpression(orderLine[++i]);
					case "-partition" -> partitionNumber = parseNumberExpression(orderLine[++i]);
					case "-length" -> fileLength = parseNumberExpression(orderLine[++i]);
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
		
		if (input == null) throw new CLIException("No input file was specified!");
		if (output == null) throw new CLIException("No output disk was specified! Use the -to switch do so.");
		if (partitionNumber == -1) throw new CLIException("No partition specified. Use -partition to specify one.");
		
		var inputFile = new File(input);
		if (!inputFile.exists()) throw new CLIException("The input file '" + input + "' was specified!");
		
		// Open disk (output file) and obtain the partition indexed
		var disk = new Disk(new File(output));		
		var partition = disk.listPartitions().get(partitionNumber);
		var fat16 = new FAT16(partition);
		
		long firstByte = (partition.getFirstSector()) * 0x200L;
		
		System.out.printf("Burning '%s'[0x%X] to '%s'[0x%X -- VBR PART %d]\n", input, inputOffset, output, firstByte, partitionNumber);
		
		fat16.burnVBR(inputFile, inputOffset, fileLength);	
		
		System.out.println("Finished.");
	}
	
	void burnReservedSectorsOrder(String[] orderLine) {
		String input = null;
		String output = null;
		int inputOffset = 0;
		int partitionNumber = -1;
		long fileLength = -1;
		
		// Interpret order arguments
		for (int i = 1; i < orderLine.length; i++) {
			var arg = orderLine[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					case "-srcOff" -> inputOffset = parseNumberExpression(orderLine[++i]);
					case "-partition" -> partitionNumber = parseNumberExpression(orderLine[++i]);
					case "-length" -> fileLength = parseNumberExpression(orderLine[++i]);
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
		
		if (input == null) throw new CLIException("No input file was specified!");
		if (output == null) throw new CLIException("No output disk was specified! Use the -to switch do so.");
		if (partitionNumber == -1) throw new CLIException("No partition specified. Use -partition to specify one.");
		
		var inputFile = new File(input);
		if (!inputFile.exists()) throw new CLIException("The input file '" + input + "' was specified!");
		
		// Open disk (output file) and obtain the partition indexed
		var disk = new Disk(new File(output));		
		var partition = disk.listPartitions().get(partitionNumber);
		var fat16 = new FAT16(partition);
		
		long firstByte = (partition.getFirstSector() + 1) * 0x200L;
		System.out.printf("Burning '%s'[0x%X] to '%s'[0x%X -- PART %d]\n", input, inputOffset, output, firstByte, partitionNumber);

		fat16.burnReservedSectors(inputFile, inputOffset, fileLength);
		
		System.out.println("Finished.");
	}
	
	/**
	 * Mounts a virtual disk file. Requires no switches, only an input argument.
	 */
	void mountOrder(String[] order) {
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
		
		new Disk(new File(diskPathArg)).mount();
	}
	
	/**
	 * Unmounts a virtual disk file. Requires no switches, only an input argument.
	 */
	void unmountOrder(String[] order) {
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
		
		new Disk(new File(diskPathArg)).unmount();
	}
	
	/**
	 * Instantiates a disk syncing service. Requires administrative privileges.
	 */
	void syncDiskOrder(String[] order) {
		String diskFile = null;
		String diskPath = null;
		String srcPath = null;
		
		// Interpret order arguments
		for (int i = 1; i < order.length; i++) {
			var arg = order[i];
			
			if (arg.startsWith("-")) {
				switch (arg) {
					case "-with" -> srcPath = order[++i];
					case "-at" -> diskPath = order[++i];
					default -> throw new CLIException("Unknown switch: " + arg);
				}
			} else {
				if (diskFile != null) {
					throw new CLIException("Argument " + arg + " specifies a disk but a disk was already provided before.");
				}
				
				diskFile = arg;
			}
		}
		
		if (diskFile == null) throw new CLIException("No disk was specified!");
		if (srcPath == null) throw new CLIException("No folder to sync was specified! Use the -with switch to do so.");
		if (diskPath == null) throw new CLIException("No disk destination path was specified! Use the -at switch to do so.");
		
		var disk = new Disk(new File(diskFile));
		var service = disk.createSyncService(srcPath, diskPath);
		service.run();
	}	
	
	void partitionsOrder(String[] order) {
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
		
		var partitions = new Disk(new File(diskPathArg)).listPartitions();
		for (var p : partitions) {
			System.out.println(p);
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
		
	/** Prints the app header with version. */
	void printHeader() {
		System.out.println("-- DevToolkit Version " + VERSION_STR);
	}	
	
	/**
	 * Converts a hex number expression string into a number.
	 * Examples:
	 * "0x30"        -> 48
	 * "0x30 + 2"    -> 50
	 * "0x30 + 0x30" -> 96
	 * 
	 * @param expr The string to convert. Can be in base 10, 16, or a mix of both.
	 * @return Converted number.
	 */
	static int parseNumberExpression(String expr){
		expr = expr.trim();
		
		int p = expr.indexOf("+");
		if(p != -1){
			var a = parseNumberExpression(expr.substring(0, p));
			var b = parseNumberExpression(expr.substring(p + 1));
			return a + b;
		}
		
		if (expr.startsWith("0x")) {
			return Integer.parseInt(expr.substring(2), 16);
		}
		
		// Treat number as base 10 by default
		return Integer.parseInt(expr, 10);
	}	
}
