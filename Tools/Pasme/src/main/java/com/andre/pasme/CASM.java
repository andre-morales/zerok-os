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
 * @author André Morales
 * @version 0.9.4
 * 
 * Last edit: 27/01/2022
 */
public final class CASM {

	public static final String VERSION = "0.9.4";
	private static final String ASSEMBLER_CMD = "yasm";
	
	static List<String> inputs = new ArrayList<>();
	static List<Integer> offsets = new ArrayList<>();
	static Map<String, String> defines = new HashMap<>();
	static List<String> includeFolders = new ArrayList<>();
	
	public static void main_(String[] args) {
		System.out.println("CASM Version " + VERSION);

		String ctrl = null;
		boolean chainInput = false;
		var length = "";
		for (int i = 0; i < args.length; i++) {
			String token = args[i];
			if (ctrl != null) {
				switch (ctrl) {
					/* Input file */
					case "i":
						inputs.add(token);
						break;
					case "If":
						includeFolders.add(token);
						break;
					case "len":
						length = token;
						break;
					case "+d":
						defines.put(token, "1");
						break;
					case "-d":
						defines.remove(token);
						break;
					case "tt": {
						var input = inputs.get(0);
						new CASM().transpile(input, token);

						inputs.clear();
						if (chainInput) {
							inputs.add(token);
						}
					}
					break;
					case "at": {
						var input = inputs.get(0);
						var res = new CASM().assemble(input, token);

						inputs.clear();
						if (chainInput) {
							inputs.add(token);
						}
						if (!res) {
							System.out.println("Assembling failed.");
							System.exit(1);
						}
					}
					break;
					case "wt": {
						var binary = inputs.get(0);
						var disk = token;
						int fileOffset = optionalOffset(0);
						int diskOffset = optionalOffset(1);
						int len;
						if (Str.isNullOrEmpty(length)) {
							len = Integer.MAX_VALUE;
						} else {
							len = Integer.parseInt(length);
						}
						
						if (!disk.equals("")) {
							new CASM().burnTo(binary, fileOffset, disk, diskOffset, len);
						}

						offsets.clear();
						inputs.clear();
						length = "";
					}
					break;
				}
				ctrl = null;
				continue;
			}

			chainInput = false;
			switch (token) {
				case "-i":
					ctrl = "i";
					break;
				case "-If":
					ctrl = "If";
					break;
				case "-tt":
					ctrl = "tt";
					break;
				case "-tti":
					ctrl = "tt";
					chainInput = true;
					break;
				case "-at":
					ctrl = "at";
					break;
				case "-ati":
					ctrl = "at";
					chainInput = true;
					break;
				case "-len":
					ctrl = "len";
					break;
				case "-off":
					int n = parseHexNum(args[++i]);
					offsets.add(n);
					
					break;
				case "-wt":
					ctrl = "wt";
					break;
				case "-+d":
					ctrl = "+d";
					break;
				case "--d":
					ctrl = "-d";
					break;
				default:
					throw new TranspilerException("Unknown control token: " + token);
			}
		}
	}

	static int parseHexNum(String str){
		str = str.trim();
		
		int p = str.indexOf("+");
		if(p != -1){
			return parseHexNum(str.substring(0, p)) + parseHexNum(str.substring(p + 1));
		} else if (str.startsWith("0x")) {
			return Integer.parseInt(str.substring(2), 16);
		} else {
			return Integer.parseInt(str, 10);
		}
	}
	
	static String reqInput(int index) {
		try {
			return inputs.get(index);
		} catch (Exception e) {
			throw new TranspilerException("Not enough inputs specified.");
		}
	}

	static int optionalOffset(int index) {
		try {
			return offsets.get(index);
		} catch (ArrayIndexOutOfBoundsException e) {
			return 0;
		}
	}

	void burnTo(String fileStr, int fileOffset, String diskStr, int diskOffset, int length) {
		System.out.print("Burning '" + fileStr + "'[0x" + Integer.toHexString(fileOffset).toUpperCase());
		System.out.print("] to '" + diskStr + "'[0x" + Integer.toHexString(diskOffset).toUpperCase() + "] ");
		if (length == Integer.MAX_VALUE) {
			System.out.println("fully");
		} else {
			System.out.println("with " + length + " bytes");
		}

		try {
			var diskPath = new File(diskStr).toPath();
			var disk = FileChannel.open(diskPath, StandardOpenOption.WRITE);
			var fileFile = new File(fileStr);
			var filePath = fileFile.toPath();
			var file = FileChannel.open(filePath, StandardOpenOption.READ);
			disk.position(diskOffset);
			file.position(fileOffset);
			long len = Math.min(fileFile.length() - fileOffset, length);
			var bb = ByteBuffer.allocate(1);
			int b;
			for (long i = 0; i < len; i++) {
				while ((b = file.read(bb)) == 0) {
					if (b == -1) {
						throw new IOException("-1.");
					}
				}
				bb.flip();
				while (disk.write(bb) == 0) {
				}
				bb.flip();
			}
			disk.close();
			file.close();
			System.out.println("Written " + len + " bytes.");
		} catch (IOException ex) {
			ex.printStackTrace();
		}
	}

	/**
	 * Invokes the CASM transpiler on an input file and generates a native
	 * assembly file.
	 */
	void transpile(String inputFile, String outputFile) {
		System.out.println("Transpiling '" + inputFile + "' to '" + outputFile + "'");
		
		var tr = new Transpiler();
		tr.defines = defines;
		tr.includePaths = includeFolders;
		tr.transpile(new File(inputFile), new File(outputFile));
	}
	
	/**
	 * Calls the configured assembler program on the input file and generates
	 * an output file.
	 * 
	 * @param inputFile The path of the input file.
	 * @param outputFile The path to an output file.
	 * @return true wether the file was assembled successfully, false otherwise.
	 */
	boolean assemble(String inputFile, String outputFile) {
		System.out.println("Assembling '" + inputFile + "' to '" + outputFile + "'");
		try {
			var r = exec(ASSEMBLER_CMD, inputFile, "-o" + outputFile);
			return r == 0;
		} catch (ProgramNotFoundException e){
			throw new RuntimeException("Failed to run NASM assembler, is it installed on PATH?", e);
		}
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
}
