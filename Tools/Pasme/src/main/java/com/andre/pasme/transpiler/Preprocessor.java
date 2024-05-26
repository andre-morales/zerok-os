package com.andre.pasme.transpiler;

import com.andre.pasme.PasmeCLI;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.io.LineNumberReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Stack;

/**
 *
 * @author Andre
 */
public class Preprocessor {
	enum IFBlockState {
		OUTSIDE, FALSE, TRUE
	}
	
	public static List<Line> readAllLines(File input) throws IOException {
		var lines = new ArrayList<Line>();
		
		var r = new LineNumberReader(new FileReader(input));
			
		String str;
		while ((str = r.readLine()) != null) {
			int n = r.getLineNumber();
			lines.add(new Line(str, n));
		}
		
		r.close();

		return lines;
	}
	
	public static List<Line> pass(Transpiler tr, List<Line> lines) {
		var emit = new ArrayList<Line>();
		emit.add(new Line("; -- PASME Version " + PasmeCLI.VERSION_STR, 0));
		
		var ifStackState = true;
		var ifStack = new Stack<Boolean>();
		
		for (int i = 0; i < lines.size(); i++) {
			var line = lines.get(i);
			var str = line.content;
			var strTr = str.trim();
			var lineN = line.number;

			try {
				if (strTr.startsWith("#if ")) {
					ifStack.push(ifStackState);
					if (!ifStackState) continue;
					
					var def = Str.remainingAfter(str, "#if ");
					ifStackState = "1".equals(tr.definedConstants.get(def));
					continue;
				}

				if (strTr.startsWith("#ifdef ")) {
					ifStack.push(ifStackState);
					if (!ifStackState) continue;
					
					var def = Str.remainingAfter(str, "#ifdef ");
					ifStackState = tr.definedConstants.get(def) != null;
					continue;
				}

				if (strTr.startsWith("#ifndef ")) {
					ifStack.push(ifStackState);
					if (!ifStackState) continue;
					
					var def = Str.remainingAfter(str, "#ifndef ");
					ifStackState = tr.definedConstants.get(def) == null;
					continue;
				}
				
				// Check if IF block has ended.
				if (strTr.startsWith("#endif")) {
					ifStackState = ifStack.pop();
					continue;
				}

				// Flip state of IF block if necessary
				if (strTr.startsWith("#else")) {
					if (ifStack.lastElement()) {
						ifStackState = !ifStackState;
					}
					continue;
				}

				// Ignore any lines while inside an IF block that has evaluated to false.
				if (!ifStackState) continue;

				// If its not a preprocessor statement, check if it contains a preprocessor value.
				if (!strTr.startsWith("#")) {
					// The line will be emitted
					emit.add(line);
					
					// Check for starting $# and ending # marker in the statement
					var bs = str.indexOf("$#");
					if (bs == -1) continue;			

					var es = str.indexOf("#", bs + 2);
					if (es == -1) continue;
					
					// Obtain the preprocessor constant between $# and #
					var key = str.substring(bs + 2, es);
					var value = tr.definedConstants.get(key);
					if (value == null) continue;
					
					// Replace it in the statement
					line.content = str.replace(str.substring(bs, es+1), value);
					continue;
				}

				if (strTr.startsWith("#error ")) {
					var description = Str.remainingAfter(str, "#error ");
					throw new TranspilerException("#error says: " + description);
				}

				if (strTr.startsWith("#define ")) {
					var def = Str.remainingAfter(str, "#define ").split(" ", 2);
					tr.definedConstants.put(def[0], def[1]);
					continue;
				}

				if (strTr.startsWith("#include ")) {
					var result = solveInclude(tr, str);
					var includedLines = result.stream()
							.map((String v) -> new Line(v, lineN))
							.toList();

					lines.addAll(i + 1, includedLines);

					line.content = "; -- " + str + "--\n";	
					emit.add(line);
				}
			} catch (Exception ex) {
				throw new TranspilerException("LINE " + lineN + ": Preprocessing fault.", ex);
			}
		}
		return emit;
	}
	
	static List<String> solveInclude(Transpiler tr, String line){
		var str = Str.remainingAfter(line, "#include ").trim();
		
		Path filePath = null;
		if(str.startsWith("<") && str.endsWith(">")){
			var path = Str.untilFirstMatch(str, 1, ">");
			for(String include : tr.includePaths){
				var res = new File(include, path);
				if(res.exists()){
					filePath = res.toPath();
					break;
				}
			}
		} else if(str.startsWith("\"") && str.endsWith("\"")){
			var path = Str.untilFirstMatch(str, 1, "\"");
			filePath = tr.inputFile.resolveSibling(path);
		} else {
			throw new TranspilerException("#include statements shoud be either: '#include <file>' or '#include \"file\"'");
		}

		try {
			return Files.readAllLines(filePath);
		} catch(IOException | NullPointerException ex ){
			throw new TranspilerException("Include file '" + str + "' not found.");
		}
	}
}
