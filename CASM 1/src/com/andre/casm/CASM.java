package com.andre.casm;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * @author André Morales
 * @version 0.1.3
 * # Last edit: 27/10/2020
 */

public class CASM {
	public static void main(String[] args) {
		try {
			String csm = args[0];
			String asm = "build.asm/" + csm + ".asm";
			String out = args[1];
			new File("build.asm").mkdir();

			FileReader fr = new FileReader(csm);
			BufferedReader br = new BufferedReader(fr);

			FileWriter fw = new FileWriter(asm);

			ArrayList<String> inlineStrings = new ArrayList<>();

			String _line;
			while ((_line = br.readLine()) != null) {
				String line = _line;

				if (line.equals("Constants:")) {
					fw.write(line);
					fw.write('\n');

					for (int i = 0; i < inlineStrings.size();) {
						String string = inlineStrings.get(i++);

						fw.write("\t.string" + i + ": db " + string + "\n");
					}
				} else {
					List<String> statements = splitStatements(line);

					for (String stat : statements) {
						int beginQuotes = stat.indexOf(".\"");
						if (beginQuotes > 0) {
							int endQuotes = stat.indexOf("\"", beginQuotes + 2);
							inlineStrings.add(getConstantString(stat.substring(beginQuotes, endQuotes + 1)));

							stat = stat.substring(0, beginQuotes) + "Constants.string" + inlineStrings.size() + stat.substring(endQuotes + 1);
						}

						fw.write(stat);
						fw.write('\n');
					}
				}
			}

			br.close();
			fw.close();

			exec("nasm", asm, "-o" + out);
		} catch (Exception ex) {
			ex.printStackTrace();
		}
	}

	public static List<String> splitStatements(String str) {
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
				if (c == '\'')
					onQuotes = false;

				statementBuffer.append(c);
			} else if (onDoubleQuotes) {
				if (c == '"')
					onDoubleQuotes = false;

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

	public static String getConstantString(String str) {
		String str1 = str.substring(1, str.length());
		String str2 = str1
				.replace("\\r", "\", 0Dh, \"")
				.replace("\\n", "\", 0Ah, \"")
				.replace("\\N", "\", 0Dh, 0Ah, \"");
		return str2 + ", 0";
	}

	public static void exec(String... cmd) {
		try {
			ProcessBuilder pb = new ProcessBuilder(cmd);
			pb.redirectErrorStream(true);
			Process proc = pb.start();
			new Thread(() -> {
				InputStream is = proc.getInputStream();
				try {
					while (proc.isAlive()) {
						int c = is.read();
						if (c > 0) {
							System.out.print((char) c);
						}
					}
					int c;
					while ((c = is.read()) > 0) {
						System.out.print((char) c);
					}
				} catch (IOException ex) {
					ex.printStackTrace();
				}
			}).start();
			proc.waitFor();
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
}
