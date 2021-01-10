package com.andre.casm;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * @author André Morales
 * @version 0.7.1
 *
 * @Edit: 31/12/2020
 * @Edit: 03/01/2021
 * @Edit: 04/01/2021
 * @Edit: 05/01/2021
 * @Edit: 09/01/2021
 * @Edit: 10/01/2021
 */
public final class CASM {

	static final Map<String, Integer> VARIABLES_TYPES_SIZES = new HashMap<>();
	static final List<String> ARRAYS_TYPES = new ArrayList<>();

	static ArrayList<String> inputs = new ArrayList<>();
	static ArrayList<String> offsets = new ArrayList<>();

	// Transpiler variables
	Map<String, Integer> variables;
	List<String> constants;

	public static void main(String[] args) {
		VARIABLES_TYPES_SIZES.put("byte ", -1);
		VARIABLES_TYPES_SIZES.put("bool ", -1);
		VARIABLES_TYPES_SIZES.put("char ", -1);
		VARIABLES_TYPES_SIZES.put("short ", -2);
		VARIABLES_TYPES_SIZES.put("int ", -4);
		VARIABLES_TYPES_SIZES.put("long ", -8);

		VARIABLES_TYPES_SIZES.put("char* ", -2);
		ARRAYS_TYPES.add("byte[");
		ARRAYS_TYPES.add("char[");

		if (args.length < 2) {
			System.err.println("This command requires 2 or more arguments.");
			return;
		}

		String ctrl = null;
		boolean chainInput = false;
		var length = "";
		for (String token : args) {
			if (ctrl != null) {
				switch (ctrl) {
					case "i":
						inputs.add(token);
						break;
					case "off":
						offsets.add(token);
						break;
					case "len":
						length = token;
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
					case "wto": {
						var binary = inputs.get(0);
						var disk = token;
						int fileOffset = optionalOffset(0);
						int diskOffset = optionalOffset(1);
						int len;
						if (emptyStr(length)) {
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
					/*case "wts": {
						var binary = inputs.get(0);
						var disk = inputs.get(1);
						int offset = Integer.parseInt(token, 16) * 512;
						int len;
						if (emptyStr(length)) {
							len = Integer.MAX_VALUE;
						} else {
							len = Integer.parseInt(length);
						}
						new CASM().burnTo(binary, disk, offset, len);

						offsets.clear();
						inputs.clear();
						length = "";
					}
					break;*/
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
				case "-wto":
					ctrl = "wto";
					break;
				//case "-wts":
				//	ctrl = "wts";
				//	break;
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
				while (disk.write(bb) == 0) {}
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
		constants = new ArrayList<>();
		variables = new LinkedHashMap<>();

		try {
			var csmPath = new File(input).toPath();
			var lineBuffer = new ArrayList<>(Files.readAllLines(csmPath));

			try (var fw = new FileWriter(output)) {

				for (int li = 0; li < lineBuffer.size(); li++) {
					String line = lineBuffer.get(li);
					String tline = line.trim();

					if (tline.startsWith("#include ")) {
						fw.write("; -- " + line + "\n");
						var fileName = remainingAfter(line, "#include").trim();
						var filePath = new File(fileName).toPath();
						var includedLines = Files.readAllLines(filePath);
						lineBuffer.addAll(li + 1, includedLines);
					} else if (tline.startsWith("Constants:")) {
						fw.write(line);
						fw.write('\n');

						for (int i = 0; i < constants.size();) {
							var string = constants.get(i++);

							fw.write("\t.string" + i + ": db " + getConstantString(string) + "\n");
						}
					} else if (tline.startsWith("Variables:")) {
						fw.write(line);
						fw.write('\n');

						for (var variable : variables.keySet()) {
							int size = variables.get(variable);
							fw.write("\t" + variable + ": ");

							switch (size) {
								case -1:
									fw.write("db");
									break;
								case -2:
									fw.write("dw");
									break;
								case -4:
									fw.write("dd");
									break;
								case -8:
									fw.write("dq");
									break;
								default:
									fw.write("times " + size + " db");
							}
							fw.write(" 0\n");
						}
					} else {
						if (tline.startsWith("var ")) {
							var field = remainingAfter(tline, "var ");

							for (var type : VARIABLES_TYPES_SIZES.keySet()) {
								if (field.startsWith(type)) {
									variables.put(remainingAfter(field, type), VARIABLES_TYPES_SIZES.get(type));
								}
							}
							for (var type : ARRAYS_TYPES) {
								if (field.startsWith(type)) {
									var rest = remainingAfter(field, type);
									int ind = rest.indexOf("]");
									int size = Integer.parseInt(rest.substring(0, ind));
									variables.put(rest.substring(ind + 2), size);
								}
							}
						} else {
							var statements = splitStatements(line);

							for (String stat : statements) {
								if (!stat.trim().startsWith(";")) {
									stat = processStatement(stat);
								}

								fw.write(stat);
								fw.write('\n');
							}
						}
					}
				}
			}
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

	boolean assemble(String input, String output) {
		System.out.println("Assembling '" + input + "' to '" + output + "'");
		return exec("nasm", input, "-o" + output) == 0;
	}

	String processStatement(String stat) {
		var sb = new StringBuilder();
		var constantBuffer = new StringBuilder();
		char[] chars = stat.toCharArray();

		char strBeginChar = '\0';
		boolean strBegin = false;
		boolean onConstant = false;

		for (int i = 0; i < chars.length; i++) {
			char c = chars[i];
			char nc = ((i + 1 < chars.length) ? chars[i + 1] : '\0');
			if (strBeginChar != '\0') {
				if (onConstant) {
					constantBuffer.append(c);

					if (c == strBeginChar && !strBegin) {
						onConstant = false;
						constants.add(constantBuffer.toString());
						sb.append("Constants.string").append(constants.size());
					}
				} else {
					sb.append(c);
				}

				if (c == strBeginChar && !strBegin) {
					strBeginChar = '\0';
				}
				strBegin = false;
			} else {
				if (c == '.') {
					if (isQuote(nc)) {
						strBeginChar = nc;
						strBegin = true;
						onConstant = true;
						constantBuffer = new StringBuilder();
						continue;
					}
				}
				if (isQuote(nc)) {
					strBeginChar = nc;
					strBegin = true;
				}
				sb.append(c);
			}
		}
		return sb.toString();
	}

	static List<String> splitStatements(String str) {
		ArrayList<String> statements = new ArrayList<>();
		char[] chars = str.toCharArray();
		boolean onDoubleQuotes = false;
		boolean onQuotes = false;
		boolean onComment = false;
		StringBuilder statementBuffer = new StringBuilder();
		for (char c : chars) {
			if (onComment) {
				statementBuffer.append(c);
			} else if (onQuotes) {
				if (c == '\'') {
					onQuotes = false;
				}

				statementBuffer.append(c);
			} else if (onDoubleQuotes) {
				if (c == '"') {
					onDoubleQuotes = false;
				}

				statementBuffer.append(c);
			} else {
				switch (c) {
					case '"':
						onDoubleQuotes = true;

						statementBuffer.append(c);
						break;
					case '\'':
						onQuotes = true;

						statementBuffer.append(c);
						break;
					case '|':
						statements.add(statementBuffer.toString());

						statementBuffer = new StringBuilder();
						onDoubleQuotes = false;
						onQuotes = false;
						onComment = false;
						break;
					case ';':
						onComment = true;
						statementBuffer.append(c);
						break;
					default:
						statementBuffer.append(c);
						break;
					case '{':
					case '}':

				}
			}
		}
		statements.add(statementBuffer.toString());
		return statements;
	}

	static String getConstantString(String str) {
		if (str.startsWith("\"")) {
			str = str
				.replace("\\r", "\", 0Dh, \"")
				.replace("\\n", "\", 0Ah, \"")
				.replace("\\N", "\", 0Dh, 0Ah, \"");
		}
		return str + ", 0";
	}

	static int exec(String... cmd) {
		try {
			ProcessBuilder pb = new ProcessBuilder(cmd);
			pb.redirectErrorStream(true);
			Process proc = pb.start();
			InputStream is = proc.getInputStream();

			while (proc.isAlive()) {
				int c = is.read();
				if (c > 0) {
					System.out.print((char) c);
				}
			}
			int returnCode = proc.waitFor();
			int c;
			while ((c = is.read()) > 0) {
				System.out.print((char) c);
			}

			return returnCode;
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}

	static String remainingAfter(String str, String search) {
		int i = str.indexOf(search);
		if (i == -1) {
			return null;
		}

		return str.substring(i + search.length());
	}

	static boolean isQuote(char c) {
		return c == '"' || c == '\'';
	}

	static boolean emptyStr(String str) {
		return str != null && str.length() == 0;
	}
}
