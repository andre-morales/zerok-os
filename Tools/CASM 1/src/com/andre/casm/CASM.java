package com.andre.casm;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * @author André Morales
 * @version 0.9.0
 * @Edit: 27/01/2022
 */
public final class CASM {

	public static final String VERSION = "0.9.0";

	static ArrayList<String> inputs = new ArrayList<>();
	static ArrayList<String> offsets = new ArrayList<>();
	static Map<String, String> defines = new HashMap<>();

	public static void main(String[] args) {
		System.out.println("CASM Version " + VERSION);

		String ctrl = null;
		boolean chainInput = false;
		var length = "";
		for (String token : args) {
			if (ctrl != null) {
				switch (ctrl) {
					/* Input file */
					case "i":
						inputs.add(token);
						break;
					/* Specify offset for something */
					case "off":
						offsets.add(token);
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
							return;
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
						new CASM().burnTo(binary, fileOffset, disk, diskOffset, len);

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
			ctrl = token;
			switch (token) {
				case "-i":
					ctrl = "i";
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
					ctrl = "off";
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
					throw new CASMException("Unknown control token: " + token);
			}
		}
	}

	static String reqInput(int index) {
		try {
			return inputs.get(index);
		} catch (Exception e) {
			throw new CASMException("Not enough inputs specified.");
		}
	}

	static int optionalOffset(int index) {
		try {
			var off = offsets.get(index);
			if (off.startsWith("0x")) {
				return Integer.parseInt(off.substring(2), 16);
			} else {
				return Integer.parseInt(off, 10);
			}

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
		} catch (IOException ex) {
			ex.printStackTrace();
		}
	}

	void transpile(String input, String output) {
		System.out.println("Transpiling '" + input + "' to '" + output + "'");
		var tr = new Transpiler();
		tr.defines = defines;
		tr.transpile(new File(input), new File(output));
	}

	boolean assemble(String input, String output) {
		System.out.println("Assembling '" + input + "' to '" + output + "'");
		return exec("nasm", input, "-o" + output) == 0;
	}

	static int exec(String... cmd) {
		try {
			ProcessBuilder pb = new ProcessBuilder(cmd);
			pb.redirectErrorStream(true);
			Process nasm;
			try {
				nasm = pb.start();
			} catch(IOException ie){
				throw new RuntimeException("Failed to run NASM assembler, is it installed on PATH?", ie);
			}
			InputStream is = nasm.getInputStream();

			while (nasm.isAlive()) {
				int c = is.read();
				if (c > 0) {
					System.out.print((char) c);
				}
			}
			int returnCode = nasm.waitFor();
			int c;
			while ((c = is.read()) > 0) {
				System.out.print((char) c);
			}

			return returnCode;
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
}
